import { db, now } from "./db";
import { handlers } from "./handlers";

const workerId = process.argv[2] ?? "worker-1";
const startDelayMs = Number(process.env.START_DELAY_MS ?? 0);
const leaseMs = Number(process.env.LEASE_MS ?? 30_000);
const heartbeatEnabled = process.env.HEARTBEAT_ENABLED !== "0";

type ClaimedJob = {
	id: number;
	type: string;
	payload: string;
	attempts: number;
	max_attempts: number;
	lock_version: number;
};

type StopHeartbeat = () => void;

async function sleepWhenEmpty() {
	await Bun.sleep(500);
}

function backoffMs(attempts: number) {
	const base = 1_000; // 1 second
	const max = 30_000; // 30 seconds
	const exp = Math.min(base * 2 ** (attempts - 1), max);
	return Math.floor(Math.random() * exp) + 1; // random delay between 1ms and the exponential cap
}

function errorMessage(error: unknown) {
	return error instanceof Error ? error.message : String(error);
}

function shouldDeadLetter(job: ClaimedJob, message: string) {
	const permanent = message.startsWith("PERMANENT:");
	const attemptsExhausted = job.attempts >= job.max_attempts;

	return permanent || attemptsExhausted;
}

function startHeartbeat(job: ClaimedJob): StopHeartbeat {
	if (!heartbeatEnabled) {
		return () => {};
	}

	const heartbeatMs = Math.max(100, Math.floor(leaseMs / 2));

	const timer = setInterval(() => {
		const result = db.query(`
			UPDATE jobs SET
				lease_expires_at = $next,
				updated_at = $now
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

// Claiming is a single UPDATE so competing workers cannot both take the same
// queued row. lock_version is the fencing token used during later settlement.
const claimNextJobQuery = db.query(`
	UPDATE jobs SET
		status = 'running',
		locked_by = $worker,
		attempts = attempts + 1,
		lock_version = lock_version + 1,
		lease_expires_at = $now + $leaseMs,
		updated_at = $now
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

function claimNextJob() {
	return claimNextJobQuery.get({
		$worker: workerId,
		$now: now(),
		$leaseMs: leaseMs,
	}) as ClaimedJob | null;
}

async function runHandler(job: ClaimedJob) {
	const handler = handlers[job.type];
	if (!handler) {
		throw new Error(`unknown job type: ${job.type}`);
	}

	await handler(JSON.parse(job.payload));
}

function markSucceeded(job: ClaimedJob) {
	// The ownership predicates discard stale completions after a lease is
	// lost and the job has been re-claimed by another worker.
	const result = db.query(`
		UPDATE jobs SET
			status = 'succeeded',
			locked_by = NULL,
			lease_expires_at = NULL,
			last_error = NULL,
			updated_at = $now
		WHERE id = $id
		  AND locked_by = $worker
		  AND lock_version = $lockVersion
		  AND status = 'running'
	`).run({
		$now: now(),
		$id: job.id,
		$worker: workerId,
		$lockVersion: job.lock_version,
	});

	if (result.changes === 0) {
		console.log(`${workerId} stale success for job ${job.id} discarded`);
	}
}

function moveToDead(job: ClaimedJob, message: string) {
	const result = db.query(`
		UPDATE jobs SET
			status = 'dead',
			locked_by = NULL,
			lease_expires_at = NULL,
			last_error = $error,
			updated_at = $now
		WHERE id = $id
		  AND locked_by = $worker
		  AND lock_version = $lockVersion
		  AND status = 'running'
	`).run({
		$error: message,
		$now: now(),
		$id: job.id,
		$worker: workerId,
		$lockVersion: job.lock_version,
	});

	if (result.changes === 0) {
		console.log(`${workerId} stale failure for job ${job.id} discarded`);
	}
}

function retryLater(job: ClaimedJob, message: string) {
	const next = now() + backoffMs(job.attempts);

	// Transient failures return to queued with a delayed available_at so
	// retries do not hammer the same failing dependency.
	const result = db.query(`
		UPDATE jobs SET
			status = 'queued',
			locked_by = NULL,
			lease_expires_at = NULL,
			available_at = $next,
			last_error = $error,
			updated_at = $now
		WHERE id = $id
		  AND locked_by = $worker
		  AND lock_version = $lockVersion
		  AND status = 'running'
	`).run({
		$next: next,
		$error: message,
		$now: now(),
		$id: job.id,
		$worker: workerId,
		$lockVersion: job.lock_version,
	});

	if (result.changes === 0) {
		console.log(`${workerId} stale retry for job ${job.id} discarded`);
	}
}

function settleFailure(job: ClaimedJob, error: unknown) {
	const message = errorMessage(error);

	if (shouldDeadLetter(job, message)) {
		moveToDead(job, message);
		return;
	}

	retryLater(job, message);
}

async function processJob(job: ClaimedJob) {
	console.log(`${workerId} running job ${job.id} (${job.type})`);

	const stopHeartbeat = startHeartbeat(job);

	try {
		await runHandler(job);
		stopHeartbeat();
		markSucceeded(job);
	} catch (error) {
		stopHeartbeat();
		settleFailure(job, error);
	}
}

async function waitBeforeStarting() {
	if (startDelayMs <= 0) {
		return;
	}

	console.log(`${workerId} waiting ${startDelayMs}ms before starting`);
	await Bun.sleep(startDelayMs);
}

await waitBeforeStarting();

while (true) {
	const job = claimNextJob();

	if (!job) {
		await sleepWhenEmpty();
		continue;
	}

	await processJob(job);
}
