# Future Phase Roadmap

This roadmap translates `batch-queue-architecture.md` into future learning
phases for this Bun/SQLite experiment.

The architecture document is a broad STARLIMS design reference. This roadmap is
smaller on purpose: each phase should make one reliability or operations concept
visible in the local queue before the next concept is added.

## Roadmap Principles

- Keep the root project as the active workspace.
- Snapshot each phase when the lesson is runnable and documented.
- Prefer behavior scripts over a formal test framework while this remains a
  learning project.
- Keep SQL and worker protocol details visible.
- Do not turn this into a reusable queue library.

## Already Covered

- `00-starting-point`: durable row model and helper scripts
- `01-naive-worker`: producer plus a single worker lifecycle
- `02a-double-claim-race`: why select-then-update is unsafe
- `02b-atomic-claim`: atomic claim with `UPDATE ... RETURNING`
- `04-dead-letter-replay`: retry exhaustion, dead-letter state, manual replay
- `05-crash-recovery`: leases and manual reaping
- `05b-heartbeats`: lease renewal for healthy long-running jobs
- `05c-fencing`: stale settlement protection with `lock_version`
- `06-idempotency`: at-least-once execution and idempotent side effects
- `07-monitoring`: queue shape and oldest queued age
- `08-cleanup-pass`: worker decomposition and reusable behavior scripts

## Phase 9: Staged Jobs And Durable Progress

Concept: a durable job row is not always enough; some handlers also need durable
progress inside the job.

Testing process:

- add a staged handler such as `build-report-pipeline`
- give it visible stages like `prepare`, `write-output`, and `mark-ready`
- store per-stage progress in a small table keyed by job id and stage name
- add a failure knob so the handler can fail after one stage completes
- run the worker, confirm the job fails partway, then run the worker again
- verify the retry skips completed stages and resumes from the next incomplete
  stage

Lessons to learn:

- retrying the whole handler is only safe when completed stages are idempotent
- durable checkpoints let a handler resume without repeating every step
- a checkpoint is a promise: once it says `done`, later attempts must trust it
- partial progress and partial side effects are different things and need to be
  reasoned about separately

## Phase 10: Dead-Letter Review And Scripted Resume

Concept: dead letters are not cleanup by themselves; they are a controlled
manual intervention point.

Testing process:

- extend the staged job scenario so one stage fails permanently and reaches
  `dead`
- inspect the dead job, stage progress, and last error
- add an operator script that can mark a failed stage ready to retry, reset the
  job to `queued`, and optionally skip or repair a stage
- run the worker again and verify the job resumes from the reviewed point
- add a second scenario where the right operator action is cancellation rather
  than resume

Lessons to learn:

- dead-letter state preserves visibility and stops blind retry loops
- manual review decides whether to retry, repair, skip, cancel, or leave the job
  dead
- scripted resume makes intervention repeatable without hiding the operator
  decision
- cleanup is its own policy; dead letters can trigger cleanup, but they do not
  automatically undo partial work

## Phase 11: Enqueue API And Options

Concept: producers should use one clear enqueue path instead of hand-building
rows in every script.

Testing process:

- build a small local enqueue helper that validates required fields
- support options already present in the schema: priority, max attempts, delay,
  and idempotency key
- update producer scripts to call the helper
- add a script that enqueues delayed, prioritized, and idempotent jobs
- inspect the rows before and after workers run

Lessons to learn:

- producers need a sanctioned durable entry point
- validation belongs at enqueue time when possible
- delayed jobs are ordinary queued rows with a future `available_at`
- enqueue-time idempotency prevents duplicate active jobs, but handler
  idempotency is still required

## Phase 12: Retry Policy As A First-Class Lesson

Concept: retries are policy, not just "put it back in queued."

Testing process:

- make retry settings easy to inspect for experiments: base delay, cap, jitter,
  and max attempts
- add a transient handler that fails several times before succeeding
- add a permanent handler that goes directly to dead
- run scripts that show `available_at` moving forward after each transient
  failure

Lessons to learn:

- `attempts` increments at claim time
- `available_at` moves forward after transient failure
- retry delay grows but caps
- permanent errors skip retry and land in `dead`

## Phase 13: Reaper Policy And Exhausted Leases

Concept: a crashed running job has already spent an attempt.

Testing process:

- update the reaper so it checks `attempts >= max_attempts`
- create a running job with an expired lease and attempts remaining
- create another expired running job with attempts exhausted
- run the reaper and inspect both rows

Lessons to learn:

- killed workers leave `running` rows behind
- reaper returns recoverable rows to `queued`
- poison jobs that crash workers eventually dead-letter without manual cleanup
- `last_error` records that recovery happened because a lease expired

## Phase 14: Done State And History

Concept: success disposition is an operations choice.

Testing process:

- add a clearer terminal model for successful jobs
- optionally add a `job_history` table that archives terminal outcomes
- run successful, failed, retried, and dead-lettered jobs
- run an archive or purge script and compare active queue state to history

Lessons to learn:

- success rows are useful for debugging but can clutter active queue views
- old terminal jobs can be archived or purged by an operator script
- monitoring can distinguish active queue shape from historical outcomes
- audit/debug history is a policy choice, not a worker correctness requirement

## Phase 15: Worker Run Budget

Concept: workers can be scheduled units of work instead of infinite daemons.

Testing process:

- add a run mode where the worker starts, reaps, drains within limits, then exits
- support limits such as max jobs, max runtime, and empty-queue exit
- run repeated worker ticks from a shell script
- start overlapping ticks and verify atomic claims still protect jobs

Lessons to learn:

- a worker can be a scheduled run, not only an infinite daemon
- rerunning the worker resumes from durable rows
- overlapping scheduled workers are still safe because claims are atomic
- behavior scripts can model "scheduler tick" instead of long-running daemons

## Phase 16: Queue Names And Routing

Concept: one table can hold multiple logical queues if the worker protocol is
still the same.

Testing process:

- add `queue_name` to jobs
- teach producers and workers to target a queue
- enqueue work into at least two queues
- run a worker for one queue and verify it does not claim from the other
- add stats grouped by queue

Lessons to learn:

- multiple logical queues can share one worker protocol
- queue-specific backlog and oldest queued age are visible
- separate queues can have different run scripts or settings
- one table with one protocol is different from two protocols fighting over one
  table

## Phase 17: Pause, Drain, Cancel

Concept: operations tools are part of the queue design.

Testing process:

- add operator scripts for pause, resume, cancel queued job, and drain
- pause a queue and show workers stop claiming new work
- cancel a queued job and show running jobs are left alone
- run a drain scenario where existing work clears before the queue is paused

Lessons to learn:

- operator tools need explicit rules about which statuses they may touch
- cancelling queued work is different from interrupting running work
- drain mode is a controlled shutdown pattern
- scripts print enough state for a learner to trust what happened

## Phase 18: Structured Logging

Concept: terminal state in the database is not the whole operational story.

Testing process:

- write simple structured logs for claim, heartbeat, retry, success, dead-letter,
  stale settlement, and reaper actions
- run existing behavior scripts
- compare logs to database state after each scenario

Lessons to learn:

- database state answers "what is true now"
- logs answer "how did it get that way"
- stale settlements are visible
- retries and dead-letter transitions are traceable
- logs and durable rows should tell a consistent story

## Phase 19: Monitoring Queries And Reports

Concept: monitoring is a set of questions before it is a dashboard.

Testing process:

- extend `stats.ts` or add focused scripts for specific operational questions
- report backlog, in-flight work, expired leases, dead-letter depth, retry rate,
  and throughput
- run scenarios that intentionally make each metric interesting

Lessons to learn:

- monitoring starts with questions, not charts
- backlog and oldest pending age show whether workers are keeping up
- expired leases show recovery risk
- dead-letter depth shows manual review load

## Phase 20: Configuration

Concept: queue policy should be visible and adjustable without editing worker
logic every time.

Testing process:

- add a small configuration surface for lease length, retry backoff, max
  attempts, worker run budget, and queue enabled/disabled state
- change config between script runs and inspect behavior changes
- include one invalid config case that fails clearly

Lessons to learn:

- configuration is executable policy
- defaults matter because scripts and future phases inherit them
- behavior scripts can set scenario-specific policy
- invalid policy should fail before it creates confusing queue state

## Phase 21: Clock Source And Time Semantics

Concept: leases and availability depend on a shared idea of time.

Testing process:

- centralize time reads instead of calling `Date.now()` directly everywhere
- compare app-clock time to SQLite-derived time
- simulate app clock skew in a worker or reaper path
- inspect delayed jobs and lease expiry behavior under skew

Lessons to learn:

- time source is part of the worker protocol
- app-clock skew can produce surprising availability or reaper behavior
- a single clock source makes worker decisions easier to reason about
- the architecture document's DB-time preference is about multi-host safety

## Phase 22: Payload Shape And Handler Contract

Concept: durable jobs need durable, understandable payloads.

Testing process:

- add light payload validation for each handler
- document handler idempotency requirements near the handler
- enqueue malformed payloads and observe failure behavior
- compare invalid payload handling to permanent business failures

Lessons to learn:

- a job row outlives the producer process
- handler-specific payload expectations are documented near the handler
- failure behavior for invalid payloads is visible in `last_error`
- idempotency keys and payload business keys line up

## Phase 23: Optional Fan-Out And Heartbeat Ownership

Concept: parallelism changes who owns settlement.

Testing process:

- build this only if the learning path needs a contrast with inline execution
- spawn detached job runners for claimed jobs
- make the detached runner heartbeat and settle the row it owns
- compare throughput and failure modes against the inline worker

Lessons to learn:

- detached execution complicates ownership and settlement
- heartbeat moves from the parent worker to the job runner
- stale settlement protection becomes even more important
- throughput improves only if the extra protocol is correct

## Parking Lot

These ideas are useful but should wait until a phase genuinely needs them:

- compatibility wrapper shaped like `SubmitToBatch`
- per-job credentials or impersonation
- encrypted payloads
- cross-database SQL dialect support
- dashboards or alerting
- migration from a real vendor queue

## Suggested Next Phase

Start with phase 9: staged jobs and durable progress.

Reason: the current queue can retry whole jobs, but it does not yet teach how a
multi-stage handler resumes after partial progress. That is the next useful
distinction before adding more producer polish or operational features.
