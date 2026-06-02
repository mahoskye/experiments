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

The root is currently phase 4: dead-letter handling and manual replay.

This builds on phase 3's retry behavior. The worker retries transient failures
until `attempts` reaches `max_attempts`. New jobs now default to `max_attempts =
2`, so dead-letter behavior is easy to observe during the exercise.

```text
job 5 attempt 1: unknown job type
job 5 attempt 2: unknown job type
job 5 status: dead
```

The `dead-letter.ts` operator tool moves one dead job back to `queued` after an
operator has investigated or fixed the underlying problem. Replay is deliberately
manual: each dead job is reviewed, repaired if needed, and resumed by id. Crash
recovery and idempotent handlers are still later lessons.

## Files

- `db.ts`: opens SQLite, applies queue-related pragmas, and creates the `jobs` table
- `handlers.ts`: dispatch registry for business logic keyed by job `type`
- `enqueue.ts`: producer that inserts queued jobs
- `worker.ts`: worker loop with atomic claim, retry backoff, and dead-letter settlement
- `dead-letter.ts`: operator tool that requeues a dead job by id
- `inspect.ts`: prints current jobs for debugging
- `reset.ts`: removes local SQLite database files
- `run-dead-letter.sh`: resets, enqueues, creates a poison job, and exercises dead-letter replay

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

Run the dead-letter exercise:

```bash
./run-dead-letter.sh
```

The script resets the database, enqueues normal jobs, adds one poison job with a
missing handler, starts workers `A` and `B`, and stops them after 8 seconds. It
prints the dead jobs, requeues one reviewed dead job with `dead-letter.ts`, and
prints the queue again. Other dead jobs stay dead until an operator reviews and
requeues them individually.

You can override the job count and observation window:

```bash
./run-dead-letter.sh 50 10s
```

Requeue a dead job manually:

```bash
bun run dead-letter.ts 5
```

Before requeueing, inspect the job payload and the relevant handler or
underlying process. Sometimes the payload should be corrected first, for example
with a direct SQL update or a small operator script. Sometimes the payload is
already correct and the fix happened elsewhere, such as external data,
credentials, or handler code. In that case, requeue the existing job as-is.

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
