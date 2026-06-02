# Phase 5: Crash Recovery With Leases

This snapshot adds manual crash recovery for jobs left `running` after a worker
dies.

The lesson is that `running` is not enough state by itself. A worker can crash
after claiming a job but before settling it. Because the job is a durable row,
the queue can recover that work if the claim has a lease and a reaper checks for
expired leases.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry, including a configurable-duration `build-report` handler
- `enqueue-report.ts`: producer that inserts one slow `build-report` job
- `worker.ts`: atomic claim with configurable `LEASE_MS`
- `reaper.ts`: returns expired `running` jobs to `queued`
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-crash-recovery.sh`: exercise script that kills a worker mid-job and verifies recovery
- `dead-letter.ts` and `run-dead-letter.sh`: previous phase tools preserved for context

## Commands

Install dependencies:

```bash
bun install
```

Run the crash-recovery exercise:

```bash
./run-crash-recovery.sh
```

The script:

1. Resets the database.
2. Enqueues one slow `build-report` job.
3. Starts worker `A` with a short lease.
4. Kills worker `A` while the job is running.
5. Verifies the job is stuck in `running` with `locked_by = A`.
6. Waits for the lease to expire.
7. Runs `reaper.ts`.
8. Verifies the job is back in `queued`.
9. Starts worker `B`.
10. Verifies worker `B` finishes the job.

You can tune the timing:

```bash
LEASE_MS=3000 CRASH_AFTER=2s LEASE_WAIT_SECONDS=4 FINISH_WINDOW=12s ./run-crash-recovery.sh
```

Run the pieces manually:

```bash
bun run reset.ts
bun run enqueue-report.ts
LEASE_MS=3000 bun run worker.ts A
bun run inspect.ts
bun run reaper.ts
bun run worker.ts B
```

## What To Observe

- Claiming a job sets `status = running`, `locked_by`, `lease_expires_at`, and
  increments `attempts`.
- Killing the worker does not delete the job. It remains a row in SQLite.
- Before the lease expires, the job is still owned by the crashed worker.
- After the lease expires, `reaper.ts` moves the job back to `queued` and clears
  `locked_by` and `lease_expires_at`.
- A second worker can claim and finish the recovered job.
- The final job has `attempts = 2`, showing that the recovered execution is a
  second attempt.

## Why This Matters

Crash recovery is an explicit mechanism. It does not happen just because a
worker process exits. The queue needs enough durable state to identify abandoned
work and make it claimable again.

This is also where at-least-once execution becomes visible. The killed worker
might have completed an external side effect before crashing. When the reaper
returns the job to `queued`, another worker may run that side effect again.

## Intentionally Broken Or Missing

- the reaper is manual, not part of a background loop
- leases are not extended for long-running jobs
- stale workers are not fenced when they wake up after lease expiry
- handlers are not idempotent yet
- there is no audit trail for reaped jobs
