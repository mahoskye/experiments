#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-80}"
worker_window="${2:-2s}"
age_wait_seconds="${3:-3}"

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} jobs"
bun run enqueue.ts "$job_count"

echo
echo "Stats before workers"
bun run stats.ts --once

echo
echo "Running workers A and B for ${worker_window}"
set +e
timeout "$worker_window" bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
status=$?
set -e

if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
	exit "$status"
fi

echo
echo "Stats after a short worker window"
bun run stats.ts --once

echo
echo "Waiting ${age_wait_seconds}s with workers stopped"
sleep "$age_wait_seconds"

echo
echo "Stats after workers are stopped"
bun run stats.ts --once

EXPECTED_TOTAL="$job_count" EXPECTED_MIN_AGE="$age_wait_seconds" bun --eval '
import { db, now } from "./db";

const expectedTotal = Number(Bun.env.EXPECTED_TOTAL);
const expectedMinAge = Number(Bun.env.EXPECTED_MIN_AGE);

const [summary] = db.query(`
	SELECT
		COUNT(*) AS total,
		SUM(CASE WHEN status = "queued" THEN 1 ELSE 0 END) AS queued,
		SUM(CASE WHEN status = "succeeded" THEN 1 ELSE 0 END) AS succeeded,
		SUM(CASE WHEN status = "dead" THEN 1 ELSE 0 END) AS dead,
		MIN(CASE WHEN status = "queued" THEN available_at ELSE NULL END) AS oldestQueuedAt
	FROM jobs
`).all() as Array<{
	total: number;
	queued: number;
	succeeded: number;
	dead: number;
	oldestQueuedAt: number | null;
}>;

console.table([summary]);

if (summary.total !== expectedTotal) {
	console.error(`Expected ${expectedTotal} total jobs.`);
	process.exit(1);
}

if (summary.queued <= 0) {
	console.error("Expected some queued work to remain after stopping workers.");
	process.exit(1);
}

if (summary.succeeded <= 0) {
	console.error("Expected workers to complete at least one job.");
	process.exit(1);
}

const oldestQueuedAgeSec = summary.oldestQueuedAt
	? (now() - summary.oldestQueuedAt) / 1000
	: 0;

if (oldestQueuedAgeSec < expectedMinAge) {
	console.error(`Expected oldest queued age to be at least ${expectedMinAge}s.`);
	process.exit(1);
}
'
