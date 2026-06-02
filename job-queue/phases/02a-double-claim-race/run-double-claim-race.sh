#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-10}"
duration="${2:-3s}"

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} jobs"
bun run enqueue.ts "$job_count"

echo "Running workers A and B for ${duration}"
echo "Look for both workers running the same job id."

set +e
timeout "$duration" bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
status=$?
set -e

if [ "$status" -eq 124 ]; then
	echo "Stopped workers after ${duration}."
	exit 0
fi

exit "$status"
