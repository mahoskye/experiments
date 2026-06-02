#!/usr/bin/env bash
set -euo pipefail

lease_ms="${LEASE_MS:-3000}"
lease_wait_seconds="${LEASE_WAIT_SECONDS:-4}"
finish_wait_seconds="${FINISH_WAIT_SECONDS:-20}"
worker_a_output="$(mktemp)"
worker_b_output="$(mktemp)"
worker_a_pid=""
worker_b_pid=""

cleanup() {
	if [ -n "$worker_a_pid" ] && kill -0 "$worker_a_pid" 2>/dev/null; then
		kill "$worker_a_pid" 2>/dev/null || true
		wait "$worker_a_pid" 2>/dev/null || true
	fi

	if [ -n "$worker_b_pid" ] && kill -0 "$worker_b_pid" 2>/dev/null; then
		kill "$worker_b_pid" 2>/dev/null || true
		wait "$worker_b_pid" 2>/dev/null || true
	fi

	rm -f "$worker_a_output" "$worker_b_output"
}
trap cleanup EXIT

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing one slow report job"
bun run enqueue-report.ts

echo "Starting worker A without heartbeats and with a ${lease_ms}ms lease"
env LEASE_MS="$lease_ms" HEARTBEAT_ENABLED=0 bun run worker.ts A > "$worker_a_output" 2>&1 &
worker_a_pid=$!

echo "Waiting ${lease_wait_seconds}s for worker A's lease to expire while it keeps running"
sleep "$lease_wait_seconds"

echo "Running reaper"
bun run reaper.ts

bun --eval '
import { db } from "./db";

const job = db.query(`
	SELECT status, locked_by, lock_version, attempts
	FROM jobs
	WHERE type = "build-report"
	LIMIT 1
`).get() as {
	status: string;
	locked_by: string | null;
	lock_version: number;
	attempts: number;
} | null;

if (!job || job.status !== "queued" || job.locked_by !== null || job.lock_version !== 1 || job.attempts !== 1) {
	console.error("Expected reaper to queue worker A expired claim before worker B starts.");
	process.exit(1);
}
'

echo "Starting worker B to claim the recovered job"
env LEASE_MS=30000 bun run worker.ts B > "$worker_b_output" 2>&1 &
worker_b_pid=$!

echo "Waiting for worker B to finish"
deadline=$((SECONDS + finish_wait_seconds))
while [ "$SECONDS" -lt "$deadline" ]; do
	if bun --eval '
		import { db } from "./db";

		const job = db.query(`
			SELECT status, attempts, lock_version
			FROM jobs
			WHERE type = "build-report"
			LIMIT 1
		`).get() as { status: string; attempts: number; lock_version: number } | null;

		process.exit(job?.status === "succeeded" && job.attempts === 2 && job.lock_version === 2 ? 0 : 1);
	'; then
		break
	fi

	sleep 1
done

if [ "$SECONDS" -ge "$deadline" ]; then
	echo "Worker B did not finish within ${finish_wait_seconds}s."
	exit 1
fi

kill "$worker_a_pid" 2>/dev/null || true
wait "$worker_a_pid" 2>/dev/null || true
worker_a_pid=""

kill "$worker_b_pid" 2>/dev/null || true
wait "$worker_b_pid" 2>/dev/null || true
worker_b_pid=""

echo
echo "Worker A output"
cat "$worker_a_output"

echo
echo "Worker B output"
cat "$worker_b_output"

if ! grep -q "A stale success for job 1 discarded" "$worker_a_output"; then
	echo "Expected worker A's stale success settlement to be discarded."
	exit 1
fi

echo
echo "Final queue state"
bun run inspect.ts

bun --eval '
import { db } from "./db";

const job = db.query(`
	SELECT status, locked_by, lease_expires_at, attempts, lock_version
	FROM jobs
	WHERE type = "build-report"
	LIMIT 1
`).get() as {
	status: string;
	locked_by: string | null;
	lease_expires_at: number | null;
	attempts: number;
	lock_version: number;
} | null;

if (!job || job.status !== "succeeded" || job.locked_by !== null || job.lease_expires_at !== null || job.attempts !== 2 || job.lock_version !== 2) {
	console.error("Expected worker B newer claim to be the final settled state.");
	process.exit(1);
}
'
