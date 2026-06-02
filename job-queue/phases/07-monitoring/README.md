# Phase 7: Monitoring Queue Shape

This snapshot adds a small stats surface for observing queue health.

The lesson is that operating a queue means watching the shape of durable work,
not just checking whether worker processes are alive. A worker can be running
while queued work grows, old work waits too long, or dead-lettered jobs need
manual attention.

## What This Phase Contains

- `db.ts`: SQLite connection and queue tables
- `enqueue.ts`: producer that inserts many `send-email` jobs
- `worker.ts`: worker with claim, retry, leases, heartbeat, fencing, and settlement
- `stats.ts`: prints count by status and oldest queued job age
- `inspect.ts`: prints full job rows for debugging
- `reset.ts`: removes local database files
- `run-monitoring.sh`: exercise script for queue depth and oldest queued age

## Commands

Install dependencies:

```bash
bun install
```

Run the monitoring exercise:

```bash
./run-monitoring.sh
```

The script:

1. Resets the database.
2. Enqueues many jobs.
3. Prints stats before workers run.
4. Runs two workers briefly.
5. Prints stats after a partial drain.
6. Stops workers while queued jobs remain.
7. Waits and prints stats again.
8. Verifies queued work remains, some work succeeded, and oldest queued age grew.

You can override the job count, worker window, and stopped-worker wait:

```bash
./run-monitoring.sh 80 2s 3
```

Run stats once:

```bash
bun run stats.ts --once
```

Watch stats continuously:

```bash
bun run stats.ts
```

## What To Observe

- Count by status shows queue depth and lifecycle shape.
- `queued` count tells you how much work is waiting.
- `running` count tells you how much work workers currently own.
- `dead` count tells you how much work needs human inspection.
- Oldest queued age keeps climbing when workers are stopped and queued work
  remains.
- A worker can be alive while the queue is still unhealthy if queued depth or
  oldest queued age keeps growing.

## Intentionally Broken Or Missing

- stats print to the terminal rather than exporting real metrics
- there are no thresholds or alerts
- there is no dashboard
- dead-letter review is still manual
- worker throughput is not measured yet
