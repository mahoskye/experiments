#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-2}"
dedup_key="${2:-charge-123}"
duration="${3:-3s}"

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} charge-account jobs with logical dedup key ${dedup_key}"
bun run enqueue-charge-account.ts "$job_count" "$dedup_key" a1 42

echo "Running workers A and B for ${duration}"
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
echo "Side effects"
bun --eval '
import { db } from "./db";

const rows = db.query(`
	SELECT dedup_key, info, created_at
	FROM side_effects
	ORDER BY dedup_key
`).all();

console.table(rows);
'

DEDUP_KEY="$dedup_key" EXPECTED_JOBS="$job_count" bun --eval '
import { db } from "./db";

const expectedJobs = Number(Bun.env.EXPECTED_JOBS);
const dedupKey = Bun.env.DEDUP_KEY!;

const [summary] = db.query(`
	SELECT
		(SELECT COUNT(*) FROM jobs WHERE type = "charge-account" AND status = "succeeded") AS succeeded_jobs,
		(SELECT COUNT(*) FROM side_effects WHERE dedup_key = $dedupKey) AS matching_side_effects,
		(SELECT COUNT(*) FROM side_effects) AS total_side_effects
`).all({ $dedupKey: dedupKey }) as Array<{
	succeeded_jobs: number;
	matching_side_effects: number;
	total_side_effects: number;
}>;

console.table([summary]);

if (summary.succeeded_jobs !== expectedJobs) {
	console.error(`Expected ${expectedJobs} succeeded charge-account jobs.`);
	process.exit(1);
}

if (summary.matching_side_effects !== 1 || summary.total_side_effects !== 1) {
	console.error("Expected exactly one side-effect row for the logical charge.");
	process.exit(1);
}
'
