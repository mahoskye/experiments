# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 5 stretch - fencing

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: a stale worker can wake up after its lease expired and after another worker already claimed the job. guard settlement with lock_version. this should prevent an old worker from overwriting the state created by a newer valid claim