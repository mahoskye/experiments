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

The root is currently phase 6: idempotent side effects.

This builds on leases, retries, reaping, and fencing. Those recovery mechanisms
make at-least-once execution visible: the same logical work may run more than
once. The `charge-account` handler records its side effect using a stable
`dedupKey`, and the database prevents duplicate side-effect rows.

```text
job 1 charges account a1 with dedupKey charge-123
job 2 repeats the same logical charge with dedupKey charge-123
both jobs succeed
only one side-effect row is inserted
```

SQLite enforces the idempotency key with `ON CONFLICT(dedup_key) DO NOTHING`.
Different databases use different SQL syntax, but the concept is the same:
choose a stable logical key, enforce uniqueness, and treat duplicate writes as
"already done."

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `enqueue-report.ts`: producer that inserts a slow `build-report` job
- `enqueue-charge-account.ts`: producer that inserts duplicate logical charge jobs
- `worker.ts`: worker loop with atomic claim, configurable leases, heartbeat renewal, retry backoff, and fenced settlement
- `reaper.ts`: returns expired running jobs to `queued`
- `dead-letter.ts`: operator tool that requeues a dead job by id
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files
- `run-idempotency.sh`: runs duplicate logical charge jobs and verifies one side effect

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

Run the idempotency exercise:

```bash
./run-idempotency.sh
```

The script resets the database, enqueues two `charge-account` jobs with the same
logical `dedupKey`, runs workers, and verifies that both jobs succeeded but only
one `side_effects` row was written.

You can override the job count, dedup key, and observation window:

```bash
./run-idempotency.sh 2 charge-123 3s
```

Reset the local database manually:

```bash
bun run reset.ts
```

Enqueue jobs manually:

```bash
bun run enqueue.ts 10
```

Enqueue duplicate logical charge jobs manually:

```bash
bun run enqueue-charge-account.ts 2 charge-123 a1 42
```

Inspect state:

```bash
bun run inspect.ts
```

## Runtime

- Runtime: Bun
- Language: TypeScript
- Scope: Local experiment, not a packaged library
