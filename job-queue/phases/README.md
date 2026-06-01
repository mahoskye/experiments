# Queue Phases

This directory contains runnable snapshots of the job queue experiment.

The snapshots are intentionally copied projects rather than shared modules. That
makes each phase easy to inspect on its own and preserves the exact code shape
that belonged to that lesson.

## Phase Index

- `00-starting-point`: the durable row model, handler registry, and helper scripts
- `01-naive-worker`: producer plus a single naive worker lifecycle
- `02a-double-claim-race`: deliberate race showing why select-then-update is not an atomic claim

## Working Style

Use the root project as the active workspace. When a phase reaches a useful
stopping point:

1. Create a new directory under `phases/`.
2. Copy the files needed to run that phase by itself.
3. Add a phase README explaining the concept, what is intentionally missing, and
   the commands to observe it.

This is a little more repetitive than sharing code, but the repetition is useful
for a tutorial-style repo. Each phase becomes a stable learning artifact instead
of a moving target.
