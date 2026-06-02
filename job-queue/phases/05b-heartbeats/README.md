# Phase 5b: Heartbeats

This snapshot adds heartbeat lease renewal for healthy long-running workers.

The lesson is that a long job can outlive its original lease even when the worker
is healthy. Without heartbeats, a reaper can mistake that healthy worker for a
dead one and return its job to `queued`. A heartbeat lets the worker periodically
extend `lease_expires_at` while the handler is still running.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table
- `handlers.ts`: dispatch registry, including a configurable-duration `build-report` handler
- `enqueue-report.ts`: producer that inserts one slow `build-report` job
- `worker.ts`: atomic claim, configurable `LEASE_MS`, heartbeat renewal, and settlement
- `reaper.ts`: returns expired `running` jobs to `queued`
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-heartbeat.sh`: exercise script that proves the reaper ignores healthy heartbeated work
- `run-crash-recovery.sh`: previous crash-recovery exercise preserved for comparison

## Commands

Install dependencies:

```bash
bun install
```

Run the heartbeat exercise:

```bash
./run-heartbeat.sh
```

The script:

1. Resets the database.
2. Enqueues one slow `build-report` job.
3. Starts worker `A` with a short lease.
4. Waits long enough that the original lease would expire without heartbeats.
5. Runs `reaper.ts` while worker `A` is still healthy.
6. Verifies the job is still `running`, still locked by `A`, and still leased in
   the future.
7. Waits for worker `A` to finish the job.
8. Verifies the job succeeded on attempt `1`.

You can tune the timing:

```bash
LEASE_MS=3000 REAPER_WAIT_SECONDS=4 FINISH_WAIT_SECONDS=20 ./run-heartbeat.sh
```

## What To Observe

- Claiming a job sets the first `lease_expires_at`.
- While the handler runs, the worker heartbeat extends `lease_expires_at`.
- Running the reaper after the original lease would have expired reaps `0` jobs.
- The job finishes on attempt `1`, showing it was not reclaimed and rerun.
- The heartbeat update checks `id`, `locked_by`, `status = running`, and
  `lock_version`, so stale workers cannot renew jobs they no longer own.

## Intentionally Broken Or Missing

- stale workers are logged when heartbeat ownership is lost, but there is no
  richer operator alerting
- handlers are not idempotent yet
- there is no automatic background reaper loop
- there is no lease extension policy per job type
