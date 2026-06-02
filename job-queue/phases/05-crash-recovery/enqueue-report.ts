import { db, now } from "./db";

const result = db.query(`
	INSERT INTO jobs (type, payload, available_at, created_at, updated_at)
	VALUES ('build-report', $payload, $now, $now, $now)
`).run({ $payload: JSON.stringify({ id: "R-100", durationMs: 10_000 }), $now: now() });

console.log(`enqueued ${result.changes} report job(s)`);
