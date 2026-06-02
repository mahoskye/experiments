# Phase 6: Idempotent Side Effects

This snapshot adds an idempotent `charge-account` handler.

The lesson is that at-least-once execution means the same logical work can run
more than once. Retries, reaping, and crash recovery are useful because they
recover work, but they also make duplicate execution possible. A handler that
performs an external side effect needs a stable logical key so repeated attempts
can be recognized as already done.

## What This Phase Contains

- `db.ts`: SQLite connection, `jobs` table, and `side_effects` table
- `handlers.ts`: dispatch registry with an idempotent `charge-account` handler
- `enqueue-charge-account.ts`: producer for duplicate logical charge jobs
- `worker.ts`: worker with atomic claim, leases, heartbeat, fencing, retry, and settlement
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-idempotency.sh`: exercise script for duplicate logical charge jobs

## Commands

Install dependencies:

```bash
bun install
```

Run the idempotency exercise:

```bash
./run-idempotency.sh
```

The script resets the database, enqueues two `charge-account` jobs with the same
logical `dedupKey`, runs workers, and prints the resulting jobs and side effects.
Both jobs should succeed, but only one row should exist in `side_effects`.

You can override the job count, dedup key, and worker window:

```bash
./run-idempotency.sh 2 charge-123 3s
```

Enqueue duplicate logical work manually:

```bash
bun run enqueue-charge-account.ts 2 charge-123 a1 42
```

Inspect state manually:

```bash
bun run inspect.ts
```

## What To Observe

- Two jobs can represent the same logical charge.
- Both jobs can reach `succeeded`.
- The handler writes to `side_effects` with `dedup_key` as the primary key.
- SQLite's `ON CONFLICT(dedup_key) DO NOTHING` makes the second logical write a
  no-op.
- The final `side_effects` table has one row for `charge-123`, not two.

## SQL Flavor

This snapshot uses SQLite syntax:

```sql
ON CONFLICT(dedup_key) DO NOTHING
```

PostgreSQL has similar syntax. Other databases use different forms, such as
`INSERT IGNORE`, `ON DUPLICATE KEY UPDATE`, duplicate-key error handling, or a
transactional `IF NOT EXISTS` pattern. The portable concept is the same:

1. choose a stable idempotency key for the logical side effect
2. enforce uniqueness on that key
3. treat duplicate writes as already done

## Intentionally Broken Or Missing

- `side_effects` is a local teaching table, not a real payment system
- there is no operator view for side effects
- the handler does not validate charge payloads
- there is no broader idempotency strategy across multiple external systems
