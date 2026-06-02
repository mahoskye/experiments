import { Database } from "bun:sqlite";

export const db = new Database("queue.db", {create: true});

// WAL lets readers continue while a writer is active
// busy_timeout makes SQLite wait briefly instead of immediately throwing
// SQLITE_BUSY when multiple workers try to write

db.run("PRAGMA busy_timeout = 5000;");
db.run("PRAGMA journal_mode = WAL;");
db.run("PRAGMA synchronous = NORMAL;");

db.run(`
	CREATE TABLE IF NOT EXISTS jobs(
		id					INTEGER	PRIMARY KEY AUTOINCREMENT,
		type				TEXT	NOT NULL,
		payload				TEXT	NOT NULL	DEFAULT '{}',
		status				TEXT	NOT NULL	DEFAULT 'queued',
		priority			INTEGER	NOT NULL	DEFAULT 0,
		attempts			INTEGER	NOT NULL	DEFAULT 0,
		max_attempts		INTEGER	NOT NULL	DEFAULT 5,
		available_at		INTEGER	NOT NULL,
		lease_expires_at	INTEGER,
		locked_by			TEXT,
		lock_version		INTEGER	NOT NULL	DEFAULT 0,
		dedup_key			TEXT	UNIQUE,
		last_error			TEXT,
		created_at			INTEGER	NOT NULL,
		updated_at			INTEGER	NOT NULL
	);
`);

db.run(`
	CREATE INDEX IF NOT EXISTS idx_jobs_claim
	  ON jobs (status, priority DESC, available_at);
`);

db.run(`
	CREATE TABLE IF NOT EXISTS side_effects (
		dedup_key	TEXT PRIMARY KEY,
		info		TEXT NOT NULL,
		created_at	INTEGER NOT NULL
	);
`);

export const now = () => Date.now();
