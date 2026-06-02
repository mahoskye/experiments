import {db, now} from "./db";
import {handlers} from "./handlers"

const workerId = process.argv[2] ?? "worker-1";
const startDelayMs = Number(process.env.START_DELAY_MS ?? 0);
const leaseMs = Number(process.env.LEASE_MS ?? 30_000);

type ClaimedJob = {
	id: number;
	type: string;
	payload: string;
	attempts: number;
	max_attempts: number;
	lock_version: number;
};

async function sleepWhenEmpty() {
	await Bun.sleep(500);
}

function backoffMs(attempts: number){
	const base = 1_000; // 1 second
	const max = 30_000; // 30 seconds
	const exp = Math.min(base * 2 ** (attempts - 1), max);
	return Math.floor(Math.random() * exp) + 1; // random delay between 1ms and the exponential cap
}

function heartbeat(job: ClaimedJob){
	const heartbeatMs = Math.max(100, Math.floor(leaseMs / 2));

	const timer = setInterval(()=>{
		const result = db.query(`
			UPDATE jobs SET
				lease_expires_at = $next,
				updated_at =  $now
			WHERE id = $id
			  AND locked_by = $worker
			  AND status = 'running'
			  AND lock_version = $lockVersion
		`).run({
			$next: now() + leaseMs,
			$now: now(),
			$id: job.id,
			$worker: workerId,
			$lockVersion: job.lock_version,
		});

		if (result.changes === 0) {
			console.log(`${workerId} heartbeat lost job ${job.id}`);
			clearInterval(timer);
		}
	}, heartbeatMs);

	return () => clearInterval(timer);
}

const claim = db.query(`
	UPDATE jobs SET
		status = 'running',
		locked_by = $worker,
		attempts = attempts + 1,
		lock_version = lock_version + 1,
		lease_expires_at = $now + $leaseMs,
		updated_at =  $now
	WHERE id = (
		SELECT id
		FROM jobs
		WHERE status = 'queued'
		  AND available_at <= $now
		ORDER BY priority DESC, id
		LIMIT 1
	)
	RETURNING id, type, payload, attempts, max_attempts, lock_version;
`);

if (startDelayMs > 0) {
	console.log(`${workerId} waiting ${startDelayMs}ms before starting`);
	await Bun.sleep(startDelayMs);
}

while(true){
	const job = claim.get({
		$worker: workerId,
		$now: now(),
		$leaseMs: leaseMs,
	}) as ClaimedJob | null;

	if(!job) {
		await sleepWhenEmpty();
		continue;
	}

	console.log(`${workerId} running job ${job.id} (${job.type})`);

	const stopHeartbeat = heartbeat(job);

	try {
		const handler = handlers[job.type];
		if(!handler) throw new Error(`unknown job type: ${job.type}`);

		await handler(JSON.parse(job.payload));

		stopHeartbeat();

		db.query(`
			UPDATE jobs SET
				status = 'succeeded',
				locked_by = NULL,
				lease_expires_at = NULL,
				last_error = NULL,
				updated_at = $now
			WHERE id = $id
		`).run({ $now: now(), $id: job.id });
	}
	catch (error) {

		stopHeartbeat();

		const message = error instanceof Error ? error.message : String(error);
		const permanent = message.startsWith("PERMANENT:");
		const attemptsExhausted = job.attempts >= job.max_attempts;

		if(permanent || attemptsExhausted){
			db.query(`
				UPDATE jobs SET
					status = 'dead',
					locked_by = NULL,
					lease_expires_at = NULL,
					last_error = $error,
					updated_at = $now
				WHERE id = $id
			`).run({$error: message, $now: now(), $id: job.id});
		} else {

			const next = now() + backoffMs(job.attempts);

			db.query(`
				UPDATE jobs SET
					status = 'queued',
					locked_by = NULL,
					lease_expires_at = NULL,
					available_at = $next,
					last_error = $error,
					updated_at = $now
				WHERE id = $id
			`).run({ $next: next, $error: message, $now: now(), $id: job.id });
		}
	}
}
