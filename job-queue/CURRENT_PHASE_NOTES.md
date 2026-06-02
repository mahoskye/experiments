# Current Phase Notes

This is the working notebook for the active phase in the root project.

Use this file for rough observations while building and exercising the current
phase. It is source material for the next phase snapshot README, not the final
polished explanation.

## Phase

Current root state: phase 2b, atomic claim prevents double-claim race

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
./run-atomic-claim.sh
```

Override job count and duration:
```
./run-atomic-claim.sh 25 5s
```

Manual worker command:
```
timeout 3s bash -c 'bun run worker.ts A & bun run worker.ts B & wait'
```

`timeout` exits with 124 because the workers loop forever. That is expected.

watch the output; the same job id should not be claimed by both workers

phase 2b changed the claim from select-then-update to one update statement:

```
UPDATE jobs SET ... WHERE id = (SELECT ... LIMIT 1) RETURNING ...
```

`RETURNING` gives the worker the row it actually claimed. The `ClaimedJob` type is
just the TypeScript shape for that returned row.

expect a mix of succeeded and failed rows because the handler still randomly
throws. The claim lesson is about avoiding duplicate job ids in worker output.
