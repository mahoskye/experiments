import { db, now } from "./db";

const once = process.argv.includes("--once");

// Lightweight operations view: status counts show queue shape, and oldest age
// shows whether queued work is waiting too long.
async function printStats() {
	const byStatus = db.query(`
		SELECT status, count(*) as count
		FROM jobs
		GROUP BY status
		ORDER BY status
	`).all();

	const oldest = db.query(`
		SELECT MIN(available_at) AS available_at
		FROM jobs
		WHERE status = 'queued'
	`).get() as { available_at: number | null };

	const oldestAgeSec = oldest.available_at
		? Math.max(0, (now() - oldest.available_at) / 1000)
		: 0;

	console.clear();
	console.table(byStatus);
	console.log(`oldest queued job age: ${oldestAgeSec.toFixed(1)}s`);
}

while (true) {
	await printStats();

	if (once) {
		break;
	}

	await Bun.sleep(1000);
}
