# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 2a, reproducable double-claim race

## Snapshot Notes

When snapshotting the next phase, use this file as source material. Keep the
phase README polished and concise; do not copy rough notes verbatim.

---

reset the state:
```
bun run reset.ts
bun run enqueue.ts 100
```

Using two separate terminals:
```
bun run worker.ts A
```

```
bun run worker.ts B
```

watch the output of the terminals, look for any entries where worker A and worker B both perform the same task