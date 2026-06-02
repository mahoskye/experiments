# Phase 2a: Double-Claim Race

This snapshot deliberately makes the naive claim race easy to reproduce.

The lesson is that selecting a queued job and later updating it to `running` is
not a claim. With two workers, both can read the same queued row before either
worker updates it. If both continue, the same job can execute twice.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry keyed by job `type`
- `enqueue.ts`: producer that inserts `send-email` jobs
- `worker.ts`: naive worker with an intentional delay between select and update
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-double-claim-race.sh`: resets, enqueues, and runs two workers together

## Commands

Install dependencies:

```bash
bun install
```

Run the bundled race exercise:

```bash
./run-double-claim-race.sh
```

The script resets the database, enqueues 10 jobs, starts workers `A` and `B`,
and stops them after 3 seconds. Watch the worker output for the same job id
being run by both workers.

You can override the job count and observation window:

```bash
./run-double-claim-race.sh 25 5s
```

Manual reset and enqueue:

```bash
bun run reset.ts
bun run enqueue.ts 10
```

Manual two-worker command:

```bash
timeout 3s bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
```

Inspect state from another terminal:

```bash
bun run inspect.ts
```

## What To Observe

- Both workers select with `status = 'queued'`.
- `worker.ts` waits briefly after selecting and before updating the row.
- During that delay, another worker can select the same job.
- Terminal output can show worker `A` and worker `B` running the same job id.
- The final row state does not fully reveal that duplicate execution happened;
  the important evidence is in the worker output.

## Intentionally Broken Or Missing

- claiming is not atomic
- the update does not verify that the row is still queued
- two workers can execute the same job
- attempts are not incremented
- failed jobs are not retried
- jobs never move to `dead`
- leases are not used
- handlers are not protected against duplicate execution
