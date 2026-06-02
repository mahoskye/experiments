import { db, now } from "./db";

const result = db.query(`
	UPDATE jobs SET
		status = 'queued',
		lease_expires_at = NULL,
		locked_by = NULL,
		updated_at = $now
	WHERE status = 'running'
	  AND lease_expires_at < $now
`).run({ $now: now() });

console.log(`reaped ${result.changes} orphaned job(s)`);
