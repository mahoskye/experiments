# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 6 - idempotency

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: at-least-once execution means the same logical work may run more than once

leases and retries recover work, but they also make duplicate execution possible. Example: a worker charges an account, then crashes before marking the job succeeded. the reaper requeues the job. another worker runs it again. without idempotency, the account is charged twice

to test this we'll expand the db to have a side effects table with dedup_key, info, and created_at

we'll also add a handler for charge-account that inserts into the table
