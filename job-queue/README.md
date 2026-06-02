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

The root is currently phase 5: leases, reaping, and crash recovery.

This builds on earlier worker claiming and retry behavior. When a worker claims a
job, it records `locked_by` and sets `lease_expires_at`. If the worker completes
the job, it clears the lease. If the worker dies while the job is still running,
the row remains durable in SQLite and the expired lease gives the reaper a way to
make the job claimable again.

```text
worker A claims job 1 with a short lease
worker A dies while job 1 is running
reaper sees the expired lease and returns job 1 to queued
worker B claims job 1 and finishes it
```

This phase makes crash recovery explicit. It also introduces the at-least-once
execution problem: the killed worker may have already performed an external side
effect before the job is reaped and run again.

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `enqueue-report.ts`: producer that inserts a slow `build-report` job
- `worker.ts`: worker loop with atomic claim, configurable leases, retry backoff, and settlement
- `reaper.ts`: returns expired running jobs to `queued`
- `dead-letter.ts`: operator tool that requeues a dead job by id
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files
- `run-dead-letter.sh`: resets, enqueues, creates a poison job, and exercises dead-letter replay
- `run-crash-recovery.sh`: kills a worker mid-job, runs the reaper, and verifies another worker finishes the job

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

Run the crash-recovery exercise:

```bash
./run-crash-recovery.sh
```

The script resets the database, enqueues one slow report job, starts worker `A`
with a short lease, kills it mid-job, waits for the lease to expire, runs
`reaper.ts`, then starts worker `B` to reclaim and finish the job.

You can tune the timing:

```bash
LEASE_MS=3000 CRASH_AFTER=2s LEASE_WAIT_SECONDS=4 FINISH_WINDOW=12s ./run-crash-recovery.sh
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
