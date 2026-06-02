import { db, now } from "./db";

const rawId = [...process.argv.slice(2), Bun.env.JOB_ID]
	.find((value) => value && /^\d+$/.test(value.trim()));
const id = Number(rawId);

if(!id){
	throw new Error("usage: bun run dead-letter.ts <job-id>");
}

const result = db.query(`
	UPDATE jobs SET
		status = 'queued',
		attempts = 0,
		available_at = $now,
		lease_expires_at = NULL,
		locked_by = NULL,
		last_error = NULL,
		updated_at = $now
	WHERE status = 'dead'
	  AND id = $id
`).run({ $id: id, $now: now() });

console.log(`requeued ${result.changes} job(s)`);
