import { mkdirSync } from "node:fs";
import path from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { drizzle as drizzlePglite } from "drizzle-orm/pglite";
import { migrate as migratePglite } from "drizzle-orm/pglite/migrator";
import { drizzle as drizzlePg } from "drizzle-orm/node-postgres";
import { migrate as migratePg } from "drizzle-orm/node-postgres/migrator";
import type { PgDatabase, PgQueryResultHKT } from "drizzle-orm/pg-core";
import { Pool } from "pg";
import * as schema from "./schema";

export type Db = PgDatabase<PgQueryResultHKT, typeof schema>;

export type Database = {
  db: Db;
  migrate(): Promise<void>;
  close(): Promise<void>;
};

const PGLITE_PREFIX = "pglite://";
const MIGRATIONS = { migrationsFolder: path.join(process.cwd(), "drizzle") };

// `pglite://memory` = throwaway in-process database (tests);
// `pglite://<dir>` = embedded database on disk (local development);
// anything else = a real Postgres connection string (production).
export function createDatabase(url: string): Database {
  if (url.startsWith(PGLITE_PREFIX)) {
    const dir = url.slice(PGLITE_PREFIX.length);
    const inMemory = dir === "memory";
    if (!inMemory) mkdirSync(dir, { recursive: true });
    const client = new PGlite(inMemory ? undefined : dir);
    const db = drizzlePglite(client, { schema });
    return {
      db,
      migrate: () => migratePglite(db, MIGRATIONS),
      close: () => client.close(),
    };
  }
  const pool = new Pool({ connectionString: url, ...POOL_LIMITS });
  // An idle client that loses its connection (e.g. Postgres restarts) emits
  // 'error' on the pool; without a listener Node would crash the whole server.
  pool.on("error", (error) => console.error("postgres pool error", error));
  const db = drizzlePg(pool, { schema });
  return {
    db,
    migrate: () => migrateWithLock(pool),
    close: () => pool.end(),
  };
}

const POOL_LIMITS = { max: 10, connectionTimeoutMillis: 5_000, idleTimeoutMillis: 30_000 };
// Arbitrary constant: two containers overlapping during a deploy wait for each
// other instead of running the same migration twice.
const MIGRATION_LOCK_KEY = 727_001;

async function migrateWithLock(pool: Pool): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("select pg_advisory_lock($1)", [MIGRATION_LOCK_KEY]);
    await migratePg(drizzlePg(client, { schema }), MIGRATIONS);
  } finally {
    const unlocked = await client
      .query("select pg_advisory_unlock($1)", [MIGRATION_LOCK_KEY])
      .then(
        () => true,
        (error: unknown) => {
          console.error("releasing the migration lock", error);
          return false;
        },
      );
    // release(true) destroys the connection, which also drops a lock still held.
    client.release(!unlocked);
  }
}
