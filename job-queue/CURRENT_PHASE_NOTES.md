# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 5 leases, reaper, and crash recovery

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: if a worker dies mid-job, the job must become claimable again

this is a centerpiece. it is an attempt to create an analogue to a process dying while work is in flight

phase 2 started setting lease_expires_at during claim. a lease means
- the worker owns the job only until a specific timestamp
- if the worker finishes, it clears the lease
- if a worker dies, a reaper can notice the expired lease and put the job back in queued

we'll build a reaper that will be run manually at first and then wrapped into the loop

we'll also build a report producer. we want to enqueue a slow job. so we'll create an enqueue-report that uses a short lease in the worker claim, maybe 5s

for the experiment we'll
1. enqueue one build-report job
2. run a worker and wait until it prints building report
3. kill the worker with ctrl+c
4. inspect the row. it should be stuck in running
5. wait for lease to expire
6. run the reaper
7. inspect the row again, it should be queued
8. start a new worker. it should claim and finish the job

this should teach:
- a queue cannot rely on process memory for correctness
- running alone is not enough; it needs a lease
- crash recovery is an explicit mechanism, not a side effect
- at least once starts here; the killed worker might have completed an external side effect
