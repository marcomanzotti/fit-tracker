import "server-only";
import { createDatabase, type Database } from "@/db/client";
import { createAuth, type Auth } from "./auth";
import { env } from "./env";
import { sendMail } from "./mail";

type Singletons = { database?: Promise<Database>; auth?: Promise<Auth> };

// Kept on globalThis so dev hot reloads reuse the open database: PGlite allows a
// single instance per data directory, and a second one would leak or corrupt it.
const store = globalThis as typeof globalThis & { __fitTracker?: Singletons };
const singletons: Singletons = (store.__fitTracker ??= {});

// One database per server process. Migrations run on first use: the app is a
// single instance on one VPS, so a failed migration stops it from serving at all.
export function getDatabase(): Promise<Database> {
  singletons.database ??= openDatabase(env().DATABASE_URL).catch((error: unknown) => {
    singletons.database = undefined;
    throw error;
  });
  return singletons.database;
}

export function getAuth(): Promise<Auth> {
  singletons.auth ??= getDatabase()
    .then(({ db }) =>
      createAuth({
        db,
        secret: env().BETTER_AUTH_SECRET,
        baseURL: env().BETTER_AUTH_URL,
        sendMail,
      }),
    )
    .catch((error: unknown) => {
      singletons.auth = undefined;
      throw error;
    });
  return singletons.auth;
}

async function openDatabase(url: string): Promise<Database> {
  const database = createDatabase(url);
  try {
    await database.migrate();
    return database;
  } catch (error: unknown) {
    await database.close().catch((closeError: unknown) => {
      console.error("closing the database after a failed migration", closeError);
    });
    throw error;
  }
}
