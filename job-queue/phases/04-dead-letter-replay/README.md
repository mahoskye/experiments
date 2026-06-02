# Phase 4: Dead Letter And Manual Replay

This snapshot adds dead-letter handling and a manual replay tool.

The lesson is that a retry limit is not the same thing as fixing a failed job.
When a job exhausts `max_attempts`, the worker moves it to `dead`. That status is
a quarantine: the job stops cycling through the queue until an operator reviews
it and decides what should happen next.

## What This Phase Contains

- `db.ts`: SQLite connection and `jobs` table with `max_attempts` defaulting to `2`
- `handlers.ts`: dispatch registry keyed by job `type`
- `enqueue.ts`: producer that inserts `send-email` jobs
- `worker.ts`: atomic claim, retry backoff, and dead-letter settlement
- `dead-letter.ts`: operator tool that requeues one dead job by id
- `inspect.ts`: prints job state
- `reset.ts`: removes local database files
- `run-dead-letter.sh`: exercise script for dead-letter inspection and one-job replay

## Commands

Install dependencies:

```bash
bun install
```

Run the dead-letter exercise:

```bash
./run-dead-letter.sh
```

The script resets the database, enqueues normal jobs, inserts one poison job with
a missing handler, and runs two workers. The workers eventually move some jobs to
`dead`, including the poison job.

The script then prints the dead-letter set and requeues one reviewed dead job by
id:

```bash
bun run dead-letter.ts <job-id>
```

You can override the job count and observation window:

```bash
./run-dead-letter.sh 50 10s
```

Inspect state manually:

```bash
bun run inspect.ts
```

## What To Observe

- New jobs default to `max_attempts = 2`, so dead-letter behavior appears quickly.
- A job that fails while attempts remain returns to `queued` with a later
  `available_at`.
- A job that fails on its final attempt moves to `dead`.
- `dead-letter.ts` requeues one selected dead job by id, resets `attempts` to
  `0`, clears `last_error`, and leaves other dead jobs untouched.
- The poison job uses type `missing-handler`, so replaying it without fixing the
  missing handler will send it back to `dead` again.

## Manual Repair Workflow

Dead-letter replay is intentionally not automatic. Before requeueing a job,
review the job and decide what changed:

- inspect `payload`, `type`, `attempts`, and `last_error`
- check whether the handler is valid and complete for that payload
- fix the payload if the job data is wrong
- fix external data, credentials, configuration, or handler code if the payload
  is already correct
- requeue the job by id only after the job now represents work that should run
  again

The payload update can be done with a direct SQL update or a small operator
script. Sometimes no payload change is needed because the repair happened in the
underlying process.

## Intentionally Broken Or Missing

- expired leases are not reclaimed
- handlers are not protected against duplicate side effects from replay
- there is no structured operator UI for reviewing or editing dead jobs
- there is no audit trail explaining who requeued a job or why
