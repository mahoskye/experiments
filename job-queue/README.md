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

See `ROADMAP.md` for future phase ideas derived from
`batch-queue-architecture.md`.

## Current Phase

The root is currently phase 8: cleanup pass for future experiments.

This phase does not add a new queue reliability mechanism. It cleans up the
current root so future experiments are easier to run and reason about:

- `worker.ts` is decomposed into smaller lifecycle functions while staying in
  one file
- root TypeScript files have clearer comments around the queue concepts they
  demonstrate
- reusable shell exercises live in `scripts/`

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
- `stats.ts`: prints count by status and oldest queued job age
- `reset.ts`: removes local SQLite database files
- `scripts/`: runnable behavior exercises copied forward from the phase history

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

Run the behavior exercises:

```bash
scripts/run-atomic-claim.sh
scripts/run-dead-letter.sh
scripts/run-crash-recovery.sh
scripts/run-heartbeat.sh
scripts/run-fencing.sh
scripts/run-idempotency.sh
scripts/run-monitoring.sh
```

Each script resets the database, sets up a focused scenario, runs workers or
operator tools, prints the queue state, and performs a small assertion about the
behavior being demonstrated.

You can override the job count, worker window, and stopped-worker wait:

```bash
scripts/run-monitoring.sh 80 2s 3
```

Run stats once:

```bash
bun run stats.ts --once
```

Watch stats continuously:

```bash
bun run stats.ts
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
