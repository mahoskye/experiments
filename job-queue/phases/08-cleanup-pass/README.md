# Phase 8: Cleanup Pass For Future Experiments

This snapshot does not introduce a new queue reliability mechanism.

The lesson is that a learning repo needs occasional cleanup so the next
experiments are easier to run, inspect, and trust. The queue behavior from the
previous phases remains intact, but the root scripts and worker code are easier
to read and reuse.

## What This Phase Contains

- `db.ts`: SQLite connection, queue table, claim index, and idempotency table
- `enqueue.ts`: producer that inserts `send-email` jobs
- `enqueue-report.ts`: producer that inserts a slow `build-report` job
- `enqueue-charge-account.ts`: producer that inserts duplicate logical charge jobs
- `worker.ts`: decomposed worker lifecycle with claim, heartbeat, handler run,
  success settlement, retry, dead-letter settlement, and stale-settlement guards
- `reaper.ts`: returns expired running jobs to `queued`
- `dead-letter.ts`: operator tool that requeues one dead job by id
- `inspect.ts`: prints full job rows for debugging
- `stats.ts`: prints count by status and oldest queued job age
- `scripts/`: behavior exercises copied forward from earlier phases and revised
  for the current root behavior
- `run-monitoring.sh`: wrapper for `scripts/run-monitoring.sh`

## Commands

Install dependencies:

```bash
bun install
```

Run focused behavior exercises:

```bash
scripts/run-atomic-claim.sh
scripts/run-dead-letter.sh
scripts/run-crash-recovery.sh
scripts/run-heartbeat.sh
scripts/run-fencing.sh
scripts/run-idempotency.sh
scripts/run-monitoring.sh
```

The scripts reset the local SQLite database, create a specific scenario, run the
worker or operator tools, print the resulting queue state, and assert the
behavior they are meant to demonstrate.

Run the older monitoring entrypoint:

```bash
./run-monitoring.sh
```

## What To Observe

- The worker loop is now easy to read from top to bottom:
  `claimNextJob`, `processJob`, then repeat.
- The worker still keeps the full lifecycle visible in one file rather than
  hiding the lesson behind a package-style abstraction.
- The script folder gives future phases a stable place for behavior checks.
- The behavior scripts are not a full test suite. They are executable lesson
  scenarios.

## Intentionally Broken Or Missing

- This is still a local learning experiment, not a reusable queue module.
- Payloads are still loosely typed so the examples stay small.
- The behavior scripts use shell and `bun --eval` rather than a formal test
  runner.
- Monitoring is still a terminal stats view, not metrics, alerts, or a dashboard.
