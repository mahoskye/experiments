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

The root is currently phase 3: transient failures retry with backoff and jitter
instead of immediately becoming final failures.

This builds on phase 2b's atomic claim. The worker still claims one queued job
with `UPDATE ... RETURNING`, then increments `attempts` when the job starts. If
the handler throws a transient error and attempts remain, the worker returns the
job to `queued` with a later `available_at` time.

```text
job 5 attempt 1: SMTP timeout
job 5 status: queued, available_at: future retry time
job 5 attempt 2: succeeds or retries again
```

If the worker sees a permanent error, or if a job has exhausted its configured
attempts, the job moves to `dead`. Crash recovery and idempotent handlers are
still later lessons.

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `worker.ts`: worker loop with atomic claim, retry backoff, and dead-letter settlement
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files
- `run-atomic-claim.sh`: resets, enqueues, runs two workers, and checks for duplicate claims
- `run-retry-backoff.sh`: resets, enqueues, runs two workers, and summarizes retry behavior

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

Run the retry/backoff exercise:

```bash
./run-retry-backoff.sh
```

The script resets the database, enqueues 20 jobs, starts workers `A` and `B`,
and stops them after 5 seconds. It prints the queue state and verifies that
transient failures did not remain in `failed`.

You can override the job count and observation window:

```bash
./run-retry-backoff.sh 30 8s
```

Run the older atomic-claim exercise from phase 2b:

```bash
./run-atomic-claim.sh
```

In the root phase, this older script can report duplicate job ids because
retries intentionally run the same job again. Use the phase 2b snapshot when the
goal is to test only atomic claiming.

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
