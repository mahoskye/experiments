#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-20}"
duration="${2:-5s}"

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} jobs"
bun run enqueue.ts "$job_count"

echo "Running workers A and B for ${duration}"
echo "Failures should return to queued with another attempt instead of becoming failed."

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
echo "Retry summary"
bun --eval '
import { db } from "./db";

const [summary] = db.query(`
	SELECT
		COUNT(*) AS total,
		SUM(CASE WHEN attempts > 1 THEN 1 ELSE 0 END) AS retried,
		SUM(CASE WHEN status = "failed" THEN 1 ELSE 0 END) AS failed,
		SUM(CASE WHEN status = "dead" THEN 1 ELSE 0 END) AS dead
	FROM jobs
`).all() as Array<{ total: number; retried: number; failed: number; dead: number }>;

console.table([summary]);

if (summary.failed > 0) {
	console.error("Expected transient failures to retry or become dead, not remain failed.");
	process.exit(1);
}

if (summary.retried === 0) {
	console.error("No retries observed. Re-run the script or increase the job count.");
	process.exit(1);
}
'
