import { connection } from "next/server";
import { sql } from "drizzle-orm";
import { fail, ok } from "@/server/http";
import { getDatabase } from "@/server/runtime";

// Liveness for the uptime monitor: the app is up and the database answers.
export async function GET(): Promise<Response> {
  await connection();
  try {
    const { db } = await getDatabase();
    await db.execute(sql`select 1`);
    return ok({ database: "up" });
  } catch (error: unknown) {
    console.error("health check failed", error);
    return fail(503, "database_unavailable", "Database not reachable");
  }
}
