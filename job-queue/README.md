# job-queue

An experiment for learning how durable job queues work by building one in small,
deliberately incomplete phases.

The goal is not to ship a reusable queue library. The goal is to make each
reliability concept concrete by first seeing the simple version, then seeing how
and why it breaks, then repairing it.

## Learning Path

The queue starts from a small SQLite table and grows feature by feature:

- a job is a durable row in a table
- a producer inserts work
- a worker claims one row, runs the matching handler, then settles the work
- multiple workers create races unless claiming is atomic
- failed work needs retry policy, dead-letter handling, and visibility into what is stuck
- crash recovery needs leases
- at-least-once execution means handlers must be idempotent

The `phases/` directory keeps runnable snapshots of the project at specific
points in the learning path. Each snapshot is meant to stand on its own, so you
can enter that directory and see the project as it existed for that lesson.

The root directory remains the active workspace for continuing the experiment.
When a phase reaches a useful stopping point, copy the relevant files into a new
snapshot directory and document what that phase is meant to teach.

## Current Phase

The root is currently phase 5b: heartbeats for healthy long-running workers.

This builds on phase 5's lease and reaper behavior. A worker can be healthy while
a long job runs past the original lease. The worker now sends heartbeats while
the handler is running, extending `lease_expires_at` so the reaper does not
mistake healthy work for abandoned work.

```text
worker A claims job 1 with a short lease
worker A keeps extending the lease while the handler runs
reaper sees the lease is still current and leaves job 1 alone
worker A finishes job 1 on the first attempt
```

The heartbeat update checks `id`, `locked_by`, `status`, and `lock_version`, so a
stale worker cannot keep renewing a job it no longer owns.

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `enqueue-report.ts`: producer that inserts a slow `build-report` job
- `worker.ts`: worker loop with atomic claim, configurable leases, heartbeat renewal, retry backoff, and settlement
- `reaper.ts`: returns expired running jobs to `queued`
- `dead-letter.ts`: operator tool that requeues a dead job by id
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files
- `run-dead-letter.sh`: resets, enqueues, creates a poison job, and exercises dead-letter replay
- `run-crash-recovery.sh`: kills a worker mid-job, runs the reaper, and verifies another worker finishes the job
- `run-heartbeat.sh`: proves a healthy long-running worker keeps its lease fresh

## Jobs Table

The columns are intentionally named after queue concepts that will become useful
over later phases:

- `type`: tells the worker which handler to run
- `payload`: JSON input for the handler
- `status`: lifecycle state: `queued`, `running`, `succeeded`, `failed`, `dead`
- `priority`: lets urgent work run first
- `attempts` / `max_attempts`: retry control
- `available_at`: delayed jobs and retry backoff
- `lease_expires_at`: crashed worker recovery
- `locked_by`: records which worker currently owns the job
- `lock_version`: fencing token for stale worker protection
- `dedup_key`: idempotency key
- `last_error`: diagnosis and dead-letter review

## Setup

From the root project, or from any phase snapshot:

```bash
bun install
```

## Useful Commands

Run the heartbeat exercise:

```bash
./run-heartbeat.sh
```

The script resets the database, enqueues one slow report job, starts worker `A`
with a short lease, waits long enough that the original lease would have expired,
runs `reaper.ts`, and verifies the job remains leased by worker `A`. It then
waits for the job to succeed on the first attempt.

You can tune the timing:

```bash
LEASE_MS=3000 REAPER_WAIT_SECONDS=4 FINISH_WAIT_SECONDS=20 ./run-heartbeat.sh
```

Run the previous crash-recovery exercise from the root:

```bash
./run-crash-recovery.sh
```

Run the manual reaper:

```bash
bun run reaper.ts
```

Run the previous dead-letter exercise from the root:

```bash
./run-dead-letter.sh
```

Reset the local database manually:

```bash
bun run reset.ts
```

Enqueue jobs manually:

```bash
bun run enqueue.ts 10
```

Inspect state:

```bash
bun run inspect.ts
```

## Runtime

- Runtime: Bun
- Language: TypeScript
- Scope: Local experiment, not a packaged library
