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
bun run enqueue.ts 10
```

Bundled exercise script:
```
./run-double-claim-race.sh
```

Override job count and duration:
```
./run-double-claim-race.sh 25 5s
```

Manual worker command:
```
timeout 3s bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
```

`timeout` exits with 124 because the workers loop forever. That is expected.

watch the output, look for any entries where worker A and worker B both perform the same task
