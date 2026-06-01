# Phase 1: Naive Worker

This snapshot adds the first producer and worker.

The lesson is the basic non-concurrent lifecycle:

```text
queued -> running -> succeeded
queued -> running -> failed
```

`enqueue.ts` inserts durable job rows. `worker.ts` loops forever, selects one
queued job, marks it `running`, dispatches to the matching handler, then marks
the row `succeeded` or `failed`.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry keyed by job `type`
- `enqueue.ts`: producer that inserts `send-email` jobs
- `worker.ts`: naive single-worker loop
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files

## Commands

Install dependencies:

```bash
bun install
```

Reset state:

```bash
bun run reset.ts
```

Enqueue five jobs:

```bash
bun run enqueue.ts 5
```

Run one worker:

```bash
bun run worker.ts worker-1
```

In another terminal, inspect state:

```bash
bun run inspect.ts
```

## What To Observe

- Jobs begin as `queued`.
- The worker marks one job `running` before invoking the handler.
- Successful handler execution becomes `succeeded`.
- Handler errors become `failed` and store `last_error`.
- Failed jobs do not retry yet.

## Intentionally Broken Or Missing

- claiming is not atomic
- multiple workers can race
- attempts are not incremented
- failed jobs are not retried
- jobs never move to `dead`
- leases are not used
- handlers are not protected against duplicate execution
