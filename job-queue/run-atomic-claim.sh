#!/usr/bin/env bash
set -euo pipefail

job_count="${1:-10}"
duration="${2:-3s}"
output_file="$(mktemp)"

cleanup() {
	rm -f "$output_file"
}
trap cleanup EXIT

echo "Resetting queue database"
bun run reset.ts

echo "Enqueueing ${job_count} jobs"
bun run enqueue.ts "$job_count"

echo "Running workers A and B for ${duration}"
echo "Each job id should be claimed by only one worker."

set +e
timeout "$duration" bash -c 'bun run worker.ts A & bun run worker.ts B & wait' | tee "$output_file"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
	exit "$status"
fi

duplicates="$(awk '/running job/ { count[$4]++ } END { for (id in count) if (count[id] > 1) print id }' "$output_file")"

if [ -n "$duplicates" ]; then
	echo "Duplicate claims found for job id(s):"
	echo "$duplicates"
	exit 1
fi

echo "No duplicate job claims observed."
