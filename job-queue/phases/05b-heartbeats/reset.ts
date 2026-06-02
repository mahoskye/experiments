import {unlinkSync} from "node:fs";

for(const file of ["queue.db", "queue.db-shm", "queue.db-wal"]){
	try {
		unlinkSync(file);
		console.log(`removed ${file}`);
	}
	catch (error:any){
		if(error?.code !== "ENOENT") throw error;
	}
}