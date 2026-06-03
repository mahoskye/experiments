import { db } from "./db";

// Debug view for the durable queue rows. This keeps timing, lease, and error
// state visible while experimenting with workers.
const rows = db.query(`
	SELECT id,
		   type,
		   status,
		   attempts,
		   max_attempts,
		   priority,
		   available_at,
		   lease_expires_at,
		   locked_by,
		   lock_version,
		   last_error
	FROM jobs
	ORDER BY id
`).all();

console.table(rows);
