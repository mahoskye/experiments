import {db, now} from "./db";
import {handlers} from "./handlers"

const workerId = process.argv[2] ?? "worker-1";

type Job = {
	id: number;
	type: string;
	payload: string;
};

async function sleepWhenEmpty() {
	await Bun.sleep(500);
}

while(true){
	const job = db.query(`
		SELECT id, type, payload
		FROM jobs
		WHERE status = 'queued'
		 AND available_at <= $now
		ORDER BY priority DESC, id
		LIMIT 1
	`).get({$now: now()}) as Job | null;

	if(!job) {
		await sleepWhenEmpty();
		continue;
	}

	const t = now();
	db.query(`
		UPDATE jobs SET 
			status = 'running',
			locked_by = $worker,
			updated_at = $now
		WHERE id = $id
	`).run({ $worker: workerId, $now: t, $id: job.id });

	console.log(`${workerId} running job ${job.id} (${job.type})`);

	try {
		const handler = handlers[job.type];
		if(!handler) throw new Error(`unknown job type: ${job.type}`);

		await handler(JSON.parse(job.payload));

		db.query(`
			UPDATE jobs SET 
				status = 'succeeded',
				locked_by = NULL,
				updated_at = $now 
			WHERE id = $id
		`).run({ $now: now(), $id: job.id });
	}
	catch (error) {
		db.query(`
			UPDATE jobs SET 
				status = 'failed',
				locked_by = NULL,
				last_error = $error,
				updated_at = $now 
			WHERE id = $id
		`).run({ $error: String(error), $now: now(), $id: job.id });
	}
}
