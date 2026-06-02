# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 4 dead letter and manual replay

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

concept: poison jobs must not block the queue forever

a poison job is work that will never succeed without human intervention: invalid sample data, bad destination address, missing authorization, malformed payload, and similar cases

we'll build a requeue-dead operator tool to move a dead job back to queued after we fix the underlying problem

we'll lower the max_attempts for new jobs
run the workers until some land in a dead status
inspect then requeue

dead letter is not handling in and of itself, it's a quarantine
manual replay is part of operating a queue
a permanently broken job should not prevent unrelated jobs from flowing

requeue should be manual and one job at a time
review the payload, handler, and any underlying external data or process before replay
the repair might be a payload update, a handler/process fix, or no payload change at all
once the job represents the work we want to retry, requeue it by id
