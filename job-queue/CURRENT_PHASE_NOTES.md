# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 7 - monitoring

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: you operate a queue by watching its shape, not just checking whether workers are alive

we'll create a stats script that will monitor things like count by status and oldest queued job

we'll enqueue many jobs, run stats, start the workers and watch the queue drain, we'll stop workers while jobs remain queued, then watch oldest queued age climb

this should demonstrate
- queue depth tells you how much work exists
- oldest queued age tells you whether the system is keeping up
- dead letter count tells you whether work is failing in a way people must inspect
- a worker can be alive while the queue is still unhealthy
