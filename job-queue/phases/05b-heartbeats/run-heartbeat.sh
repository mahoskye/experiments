#!/usr/bin/env bash
set -euo pipefail

lease_ms="${LEASE_MS:-3000}"
reaper_wait_seconds="${REAPER_WAIT_SECONDS:-4}"
finish_wait_seconds="${FINISH_WAIT_SECONDS:-20}"
output_file="$(mktemp)"
worker_pid=""

cleanup() {
	if [ -n "$worker_pid" ] && kill -0 "$worker_pid" 2>/dev/null; then
		kill "$worker_pid" 2>/dev/null || true
		wait "$worker_pid" 2>/dev/null || true
	fi
	rm -f "$output_file"
}
trap cleanup EXIT

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing one slow report job"
bun run enqueue-report.ts

echo "Starting worker A with a ${lease_ms}ms lease"
env LEASE_MS="$lease_ms" bun run worker.ts A > "$output_file" 2>&1 &
worker_pid=$!

echo "Waiting ${reaper_wait_seconds}s so the original lease would expire without heartbeats"
sleep "$reaper_wait_seconds"

echo "Running reaper while worker A is still healthy"
bun run reaper.ts

echo
echo "State after reaper"
bun run inspect.ts

bun --eval '
import { db, now } from "./db";

const job = db.query(`
	SELECT status, locked_by, lease_expires_at, attempts
	FROM jobs
	WHERE type = "build-report"
	LIMIT 1
`).get() as {
	status: string;
	locked_by: string | null;
	lease_expires_at: number | null;
	attempts: number;
} | null;

if (!job || job.status !== "running" || job.locked_by !== "A" || job.lease_expires_at === null || job.lease_expires_at <= now()) {
	console.error("Expected heartbeat to keep the running report job leased by worker A.");
	process.exit(1);
}

if (job.attempts !== 1) {
	console.error("Expected the healthy worker to still be on the first attempt.");
	process.exit(1);
}
'

echo
echo "Waiting for worker A to finish"
deadline=$((SECONDS + finish_wait_seconds))
while [ "$SECONDS" -lt "$deadline" ]; do
	if bun --eval '
		import { db } from "./db";

		const job = db.query(`
			SELECT status
			FROM jobs
			WHERE type = "build-report"
			LIMIT 1
		`).get() as { status: string } | null;

		process.exit(job?.status === "succeeded" ? 0 : 1);
	'; then
		break
	fi

	sleep 1
done

if [ "$SECONDS" -ge "$deadline" ]; then
	echo "Worker A did not finish within ${finish_wait_seconds}s."
	exit 1
fi

kill "$worker_pid" 2>/dev/null || true
wait "$worker_pid" 2>/dev/null || true
worker_pid=""

echo
echo "Worker output"
cat "$output_file"

echo
echo "Final queue state"
bun run inspect.ts

bun --eval '
import { db } from "./db";

const job = db.query(`
	SELECT status, locked_by, lease_expires_at, attempts
	FROM jobs
	WHERE type = "build-report"
	LIMIT 1
`).get() as {
	status: string;
	locked_by: string | null;
	lease_expires_at: number | null;
	attempts: number;
} | null;

if (!job || job.status !== "succeeded" || job.locked_by !== null || job.lease_expires_at !== null || job.attempts !== 1) {
	console.error("Expected worker A to finish the heartbeated report job on the first attempt.");
	process.exit(1);
}
'
