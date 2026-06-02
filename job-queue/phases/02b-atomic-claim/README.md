# Phase 2b: Atomic Claim

This snapshot fixes the double-claim race from phase 2a.

The lesson is that a worker should claim work with one database statement. The
worker updates one queued row to `running` and uses `RETURNING` to get the job it
actually claimed. If two workers run at the same time, SQLite serializes the
updates, so each returned job belongs to only one worker.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry keyed by job `type`
- `enqueue.ts`: producer that inserts `send-email` jobs
- `worker.ts`: worker with an atomic `UPDATE ... RETURNING` claim
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-atomic-claim.sh`: resets, enqueues, runs two workers, and checks for duplicate claims

## Commands

Install dependencies:

```bash
bun install
```

Run the atomic-claim exercise:

```bash
./run-atomic-claim.sh
```

The script resets the database, enqueues 10 jobs, starts workers `A` and `B`,
and stops them after 3 seconds. It checks the worker output for duplicate job
claims. The expected result is:

```text
No duplicate job claims observed.
```

You can override the job count and observation window:

```bash
./run-atomic-claim.sh 25 5s
```

Inspect state afterward:

```bash
bun run inspect.ts
```

## What To Observe

- Each job id should appear in a `running job` line at most once.
- Some jobs may be `succeeded` and some may be `failed` because the email handler
  still randomly throws.
- `attempts` increments when a job is claimed.
- `locked_by` records which worker claimed the job while it is running.
- `lock_version` increments during the claim.
- `lease_expires_at` is populated during claim and cleared on success, but crash
  recovery is not the lesson in this phase.

## Intentionally Broken Or Missing

- failed jobs are not retried
- jobs never move to `dead`
- expired leases are not reclaimed
- handlers are not protected against duplicate side effects from future retries
