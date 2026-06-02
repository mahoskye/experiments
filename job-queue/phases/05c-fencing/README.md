# Phase 5c: Fencing Stale Workers

This snapshot adds settlement fencing with `lock_version`.

The lesson is that a stale worker can wake up after its lease expired and after
another worker already claimed the same job. If the stale worker is allowed to
settle the job, it can overwrite the newer valid claim. Fencing prevents that by
requiring every settlement update to prove it still owns the exact claim it is
settling.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry, including a slow `build-report` handler
- `enqueue-report.ts`: producer that inserts one slow `build-report` job
- `worker.ts`: atomic claim, heartbeat renewal, and fenced settlement updates
- `reaper.ts`: returns expired `running` jobs to `queued`
- `run-fencing.sh`: exercise script that proves stale settlement is discarded
- earlier phase scripts such as `run-heartbeat.sh` and `run-crash-recovery.sh`
  preserved for comparison

## Commands

Install dependencies:

```bash
bun install
```

Run the fencing exercise:

```bash
./run-fencing.sh
```

The script:

1. Resets the database.
2. Enqueues one slow `build-report` job.
3. Starts worker `A` with heartbeat disabled and a short lease.
4. Waits until worker `A`'s lease expires while its handler is still running.
5. Runs `reaper.ts`, returning the expired job to `queued`.
6. Starts worker `B`, which claims the same job with a newer `lock_version`.
7. Lets both workers finish.
8. Verifies worker `A`'s stale success update is discarded.
9. Verifies worker `B`'s newer claim owns the final `succeeded` state.

## What To Observe

- Claiming a job increments `lock_version`.
- Worker `A` originally owns `lock_version = 1`.
- After reaping and reclaiming, worker `B` owns `lock_version = 2`.
- Worker `A` can still finish its handler, but its settlement update affects
  zero rows because the row no longer matches its `lock_version`.
- The final state comes from worker `B`.

## Fenced Settlement Rule

Every worker settlement path checks ownership:

```sql
WHERE id = $id
  AND locked_by = $worker
  AND lock_version = $lockVersion
  AND status = 'running'
```

That guard is used for success, retry, and dead-letter settlement. It is the
durable proof that the worker still owns the claim it is trying to settle.

## Intentionally Broken Or Missing

- handlers are not idempotent yet
- stale settlement is logged, but there is no operator alerting
- there is no audit trail for reaped or fenced jobs
- the reaper is still manually invoked
