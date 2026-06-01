# Phase 0: Starting Point

This snapshot introduces the queue as a durable row in a SQLite table.

There is no producer and no worker yet. The point is to understand the data
model and the dispatch boundary before adding behavior.

## What This Phase Contains

- `db.ts`: opens `queue.db`, configures SQLite, and creates the `jobs` table
- `handlers.ts`: maps job `type` values to async handler functions
- `inspect.ts`: prints the current jobs table
- `reset.ts`: removes local database files

The worker will eventually read `job.type`, parse `job.payload`, and call
`handlers[job.type](payload)`. Business logic belongs in handlers, not in the
worker loop itself.

## Jobs Table Concepts

- `type`: handler dispatch key
- `payload`: JSON handler input
- `status`: lifecycle state
- `priority`: ordering signal for urgent work
- `attempts` / `max_attempts`: retry budget
- `available_at`: delayed availability and retry backoff
- `lease_expires_at`: future crash recovery signal
- `locked_by`: current worker ownership
- `lock_version`: future fencing token
- `dedup_key`: future idempotency key
- `last_error`: diagnosis and dead-letter review

## Commands

Install dependencies:

```bash
bun install
```

Initialize the database by importing `db.ts` through the inspector:

```bash
bun run inspect.ts
```

Reset the local database:

```bash
bun run reset.ts
```

## Intentionally Missing

- no enqueue script
- no worker
- no claiming
- no retries
- no leases
- no idempotency behavior
