# Experiments

This repository is a workspace for small, self-contained experiments.

Each experiment lives in its own subdirectory and should include enough local documentation to explain what it is, how to run it, and any important assumptions or tradeoffs. Experiments can use different runtimes, libraries, and project structures as needed.

## Experiments

- [job-queue](./job-queue) - A small TypeScript/Bun project for exploring job queue patterns.

## Structure

```text
experiments/
  README.md
  job-queue/
    README.md
    package.json
    ...
```

## Conventions

- Keep experiments isolated from each other.
- Prefer local setup instructions in each experiment README.
- Avoid shared dependencies or global setup unless an experiment explicitly needs them.
- Treat each subdirectory as disposable enough to change freely, but documented enough to revisit later.

