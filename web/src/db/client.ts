import { mkdirSync } from "node:fs";
import path from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { drizzle as drizzlePglite } from "drizzle-orm/pglite";
import { migrate as migratePglite } from "drizzle-orm/pglite/migrator";
import { drizzle as drizzlePg } from "drizzle-orm/node-postgres";
import { migrate as migratePg } from "drizzle-orm/node-postgres/migrator";
import type { PgDatabase, PgQueryResultHKT } from "drizzle-orm/pg-core";
import { Pool } from "pg";
import * as schema from "./schema";
import { seedReferenceData } from "./seed";

export type Db = PgDatabase<PgQueryResultHKT, typeof schema>;

export type Database = {
  db: Db;
  // Applies pending migrations, then the idempotent reference data (db/seed).
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
    // Options in one object: with the (dataDir, options) form and no dataDir,
    // PGlite 0.5 ignores the extensions.
    const client = new PGlite({ dataDir: inMemory ? undefined : dir, extensions: { pg_trgm } });
    const db = drizzlePglite(client, { schema });
    return {
      db,
      migrate: async () => {
        await migratePglite(db, MIGRATIONS);
        await seedReferenceData(db);
      },
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
    migrate: async () => {
      await migrateWithLock(pool);
      await seedReferenceData(db);
    },
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
