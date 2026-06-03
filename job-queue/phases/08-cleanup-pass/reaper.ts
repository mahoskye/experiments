import { db, now } from "./db";

// Crash recovery: expired leases are returned to queued so another worker can
// claim the job. Attempts are not incremented here; claiming increments them.
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
