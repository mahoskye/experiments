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

The root currently matches phase 2a: a deliberately reproducible double-claim
race.

Phase 2a teaches why select-then-update is not a safe claim when more than one
worker is running. The worker intentionally waits after selecting a queued job
and before marking it `running`, giving another worker time to select the same
row.

```text
worker A: SELECT queued job 1
worker B: SELECT queued job 1
worker A: UPDATE job 1 to running
worker B: UPDATE job 1 to running
```

This version intentionally demonstrates duplicate execution. It does not solve
atomic claiming, retries, leases, dead-letter handling, or idempotency yet.

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `worker.ts`: naive worker loop with an intentional select/update race window
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files

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

Reset the local database:

```bash
bun run reset.ts
```

Enqueue jobs:

```bash
bun run enqueue.ts 100
```

Run two workers in separate terminals:

```bash
bun run worker.ts A
```

```bash
bun run worker.ts B
```

Inspect state:

```bash
bun run inspect.ts
```

## Runtime

- Runtime: Bun
- Language: TypeScript
- Scope: Local experiment, not a packaged library
