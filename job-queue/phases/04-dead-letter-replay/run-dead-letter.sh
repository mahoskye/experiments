#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-30}"
duration="${2:-8s}"
poison_id_file="$(mktemp)"

cleanup() {
	rm -f "$poison_id_file"
}
trap cleanup EXIT

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} normal jobs"
bun run enqueue.ts "$job_count"

echo "Adding one poison job with an unknown type"
bun --eval '
import { db, now } from "./db";

const t = now();
db.query(`
	INSERT INTO jobs (type, payload, available_at, created_at, updated_at)
	VALUES ($type, $payload, $availableAt, $createdAt, $updatedAt)
`).run({
	$type: "missing-handler",
	$payload: JSON.stringify({ reason: "phase 4 poison job" }),
	$availableAt: t,
	$createdAt: t,
	$updatedAt: t,
});
'

echo "Running workers A and B for ${duration}"
echo "Jobs that exhaust max_attempts should move to dead."

set +e
timeout "$duration" bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
status=$?
set -e

if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
	exit "$status"
fi

echo
echo "Final queue state"
bun run inspect.ts

echo
echo "Dead-letter summary"
POISON_ID_FILE="$poison_id_file" bun --eval '
import { db } from "./db";

const poison = db.query(`
	SELECT id
	FROM jobs
	WHERE status = "dead"
	  AND type = "missing-handler"
	ORDER BY id
	LIMIT 1
`).get() as { id: number } | null;

if (!poison) process.exit(1);
await Bun.write(Bun.env.POISON_ID_FILE!, String(poison.id));
'
poison_id="$(tr -d '[:space:]' < "$poison_id_file")"

if ! [[ "$poison_id" =~ ^[0-9]+$ ]]; then
	echo "Could not find a dead missing-handler job to requeue."
	exit 1
fi

bun --eval '
import { db } from "./db";

const deadJobs = db.query(`
	SELECT id, type, attempts, max_attempts, last_error
	FROM jobs
	WHERE status = "dead"
	ORDER BY id
`).all() as Array<{
	id: number;
	type: string;
	attempts: number;
	max_attempts: number;
	last_error: string | null;
}>;

console.table(deadJobs);

if (deadJobs.length === 0) {
	console.error("Expected at least one dead job.");
	process.exit(1);
}

const poison = deadJobs.find((job) => job.type === "missing-handler");
if (!poison) {
	console.error("Expected the missing-handler poison job to reach dead.");
	process.exit(1);
}
'

echo "Requeueing one reviewed dead job: ${poison_id}"
JOB_ID="$poison_id" bun run dead-letter.ts "$poison_id"

JOB_ID="$poison_id" bun --eval '
import { db } from "./db";

const job = db.query(`
	SELECT status, attempts, last_error
	FROM jobs
	WHERE id = $id
`).get({ $id: Number(Bun.env.JOB_ID) }) as {
	status: string;
	attempts: number;
	last_error: string | null;
} | null;

if (!job || job.status !== "queued" || job.attempts !== 0 || job.last_error !== null) {
	console.error("Expected the reviewed dead job to be queued with attempts reset.");
	process.exit(1);
}
'

echo
echo "Queue state after manual requeue of one job"
bun run inspect.ts
