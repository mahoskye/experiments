#!/usr/bin/env bash
set -euo pipefail

lease_ms="${LEASE_MS:-3000}"
crash_after="${CRASH_AFTER:-2s}"
lease_wait_seconds="${LEASE_WAIT_SECONDS:-4}"
finish_window="${FINISH_WINDOW:-12s}"

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing one slow report job"
bun run enqueue-report.ts

echo "Starting worker A with a ${lease_ms}ms lease, then killing it after ${crash_after}"
set +e
timeout -s KILL "$crash_after" env LEASE_MS="$lease_ms" bun run worker.ts A
status=$?
set -e

if [ "$status" -ne 137 ]; then
	echo "Expected worker A to be killed by timeout, got exit status ${status}."
	exit 1
fi

echo
echo "State after worker crash"
bun run inspect.ts

bun --eval '
import { db } from "./db";

const job = db.query(`
	SELECT status, locked_by, lease_expires_at
	FROM jobs
	WHERE type = "build-report"
	LIMIT 1
`).get() as { status: string; locked_by: string | null; lease_expires_at: number | null } | null;

if (!job || job.status !== "running" || job.locked_by !== "A" || job.lease_expires_at === null) {
	console.error("Expected crashed worker to leave the report job running under worker A lease.");
	process.exit(1);
}
'

echo
echo "Waiting ${lease_wait_seconds}s for the lease to expire"
sleep "$lease_wait_seconds"

echo "Running reaper"
bun run reaper.ts

echo
echo "State after reaper"
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

if (!job || job.status !== "queued" || job.locked_by !== null || job.lease_expires_at !== null || job.attempts !== 1) {
	console.error("Expected reaper to return the expired running job to queued with attempts preserved.");
	process.exit(1);
}
'

echo
echo "Starting worker B to reclaim and finish the job"
set +e
timeout "$finish_window" env LEASE_MS=30000 bun run worker.ts B
status=$?
set -e

if [ "$status" -ne 124 ]; then
	echo "Expected worker B to be stopped by timeout after finishing the job, got exit status ${status}."
	exit 1
fi

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

if (!job || job.status !== "succeeded" || job.locked_by !== null || job.lease_expires_at !== null || job.attempts !== 2) {
	console.error("Expected worker B to finish the reaped report job on its second attempt.");
	process.exit(1);
}
'
