import { db, now } from "./db";

export type Handler = (payload: any) => Promise<void>;

export const handlers: Record<string, Handler> = {
	"send-email": async (payload) => {
		if(Math.random() < 0.4) {
			throw new Error("SMTP timeout (transient)");
		}

		await Bun.sleep(200);
		console.log(`sent email to ${payload.to}`);
	},

	"build-report": async (payload) => {
		console.log(`building report ${payload.id}`);
		await Bun.sleep(Number(payload.durationMs ?? 200));
		console.log(`report ${payload.id} done`);
	},

	"charge-account": async (payload) => {
		db.query(`
			INSERT INTO side_effects (dedup_key, info, created_at)
			VALUES ($dedupKey, $info, $createdAt)
			ON CONFLICT(dedup_key) DO NOTHING
		`).run({
			$dedupKey: payload.dedupKey,
			$info: JSON.stringify({ account: payload.account, amount: payload.amount }),
			$createdAt: now(),
		});
	},
};
