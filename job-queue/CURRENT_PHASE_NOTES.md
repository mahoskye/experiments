# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 3 retried with backoff and jitter

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: transient failures should retry later instead of becoming final failures immediately

in phase 1, every thrown error becomes failed. that loses recoverable work. in most systems (smtp timeout, network timeout, sql deadlock or temporary outages) should be retried

we'll add a random delay to prevent jobs from retrying at the exact same time

we'll enqueue 20 send-email jobs and run 2 workers
we should see failed email attempts return to queued with a future available_at

should show that a failure is not automatically final
available_at is the shared mechanism for delayed jobs and retry delays
permanent failures and transient failures need different handling
retrying immediately can make outages worse; backoff and jitter reduces pressure