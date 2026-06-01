# Agent Instructions

This project is a learning experiment, not a library intended for release.

The goal is to build a durable job queue in phases so each reliability concept
is learned concretely. Prefer small, inspectable changes that make one concept
visible at a time.

## Agent Role

The agent's default role is repo management for the learning project:

- organize files
- create phase snapshots
- write and update README files
- maintain working phase notes when asked
- preserve the root-vs-snapshot workflow
- run lightweight verification when useful

Do not offer bug fixes, implementation suggestions, refactors, or design
improvements unless the user specifically asks for that kind of help.

During snapshotting, it is acceptable to point out bugs or inconsistencies that
affect the snapshot's ability to run or accurately represent the phase. Suggest
those separately from the snapshot work, and do not apply code fixes unless the
user asks for them.

## Project Model

- The root `job-queue/` directory is the active working copy.
- `phases/` contains frozen runnable snapshots.
- Do not continue feature work inside a phase directory.
- Only edit a phase directory to correct that phase's files or documentation.

Normal workflow:

1. Implement and test the next lesson in the root directory.
2. Capture observations, commands, and rough lesson notes in
   `CURRENT_PHASE_NOTES.md`.
3. When asked to snapshot a phase, copy the runnable root project into a new
   `phases/NN-short-name/` directory.
4. Use `CURRENT_PHASE_NOTES.md` as source material for the phase README.
5. Add or update phase documentation so the snapshot explains what the phase
   teaches, how to run it, what to observe, and what is intentionally broken or
   missing.
6. Update the root `README.md` so it describes the current state.
7. Update `phases/README.md` with the new phase entry.
8. After snapshotting, leave `CURRENT_PHASE_NOTES.md` ready for the next phase
   or update it only if the user asks.

## Snapshot Rules

A phase snapshot should be usable after `cd phases/NN-short-name`.

Include the files needed to run that phase independently, usually:

- `package.json`
- `bun.lock`
- `tsconfig.json`
- `.gitignore`
- source files for that phase
- `README.md`

Do not copy generated or local state:

- `node_modules/`
- `queue.db`
- `queue.db-*`
- logs
- coverage
- build output

## Documentation Style

`CURRENT_PHASE_NOTES.md` is a working document, not polished documentation. It
can contain rough observations, command transcripts, hypotheses, and reminders.
When creating a snapshot README, summarize and organize those notes instead of
copying them verbatim.

Phase READMEs should answer:

- What concept does this phase teach?
- Which files matter?
- Which commands should be run?
- What should the learner observe?
- What is intentionally broken or missing?

Keep the language focused on the learning sequence. It is acceptable, and often
preferred, to call out broken behavior directly before the later phase repairs
it.

## Queue Concepts

The intended learning path is:

- a job is a durable row in a table
- a producer inserts work
- a worker claims one row, runs the matching handler, then settles the work
- multiple workers create races unless claiming is atomic
- failed work needs retry policy, dead-letter handling, and visibility into what is stuck
- crash recovery needs leases
- at-least-once execution means handlers must be idempotent

## Current Conventions

- Runtime: Bun
- Language: TypeScript
- Database: local SQLite through `bun:sqlite`
- Helper scripts such as `inspect.ts` and `reset.ts` are part of the learning
  surface and should be preserved in snapshots when useful.
