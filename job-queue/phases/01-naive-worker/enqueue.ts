import { db, now } from "./db";

const count = Number(process.argv[2] ?? 1);

const insert = db.query(`
	INSERT INTO jobs (type, payload, available_at, created_at, updated_at)
	VALUES ($type, $payload, $availableAt, $createdAt, $updatedAt)
`);

for(let i = 0; i < count; i++){
	const t = now();
	insert.run({
		$type: "send-email",
		$payload: JSON.stringify({ to: `user-${i}@example.com` }),
		$availableAt: t,
		$createdAt: t,
		$updatedAt: t
	});
}

console.log(`enqueued ${count} jobs(s)`);