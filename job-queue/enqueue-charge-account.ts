import { db, now } from "./db";

const count = Number(process.argv[2] ?? 2);
const dedupKey = process.argv[3] ?? "charge-123";
const account = process.argv[4] ?? "a1";
const amount = Number(process.argv[5] ?? 42);

const insert = db.query(`
	INSERT INTO jobs (type, payload, available_at, created_at, updated_at)
	VALUES ($type, $payload, $availableAt, $createdAt, $updatedAt)
`);

for (let i = 0; i < count; i++) {
	const t = now();
	insert.run({
		$type: "charge-account",
		$payload: JSON.stringify({ dedupKey, account, amount }),
		$availableAt: t,
		$createdAt: t,
		$updatedAt: t,
	});
}

console.log(`enqueued ${count} charge-account job(s) with dedupKey ${dedupKey}`);
