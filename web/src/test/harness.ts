import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { createDatabase, type Database, type Db } from "@/db/client";
import { staffProfile, user, type Discipline, type Role } from "@/db/schema";
import type { Actor } from "@/server/actor";
import type { Mail } from "@/server/mail";
import type { RequestMeta } from "@/server/validate";

// A migrated, empty database per test. With TEST_POSTGRES_URL set (CI job
// "postgres"), it is a throwaway database on a real server, so races and
// transaction mistakes that PGlite's single connection hides show up.
export async function freshDatabase(): Promise<Database> {
  const admin = process.env.TEST_POSTGRES_URL;
  if (!admin) {
    const database = createDatabase("pglite://memory");
    await database.migrate();
    return database;
  }
  const name = `test_${randomUUID().replaceAll("-", "")}`;
  await runAdmin(admin, `create database ${name}`);
  const url = new URL(admin);
  url.pathname = `/${name}`;
  const database = createDatabase(url.toString());
  await database.migrate();
  return {
    ...database,
    close: async () => {
      await database.close();
      await runAdmin(admin, `drop database ${name} with (force)`);
    },
  };
}

async function runAdmin(url: string, statement: string): Promise<void> {
  const pool = new Pool({ connectionString: url, max: 1 });
  try {
    await pool.query(statement);
  } finally {
    await pool.end();
  }
}

export const META: RequestMeta = { ipAddress: "203.0.113.1", userAgent: "vitest" };

type UserSpec = { role?: Role; name?: string; email?: string; disciplines?: Discipline[]; twoFactor?: boolean };

// Inserts a verified user directly, skipping the sign-up flow (tested in auth.test.ts).
export async function makeUser(db: Db, spec: UserSpec = {}): Promise<Actor> {
  const role = spec.role ?? "client";
  const name = spec.name ?? `${role} ${randomUUID().slice(0, 8)}`;
  const email = spec.email ?? `${randomUUID().slice(0, 12)}@example.test`;
  const twoFactorEnabled = spec.twoFactor ?? role !== "client";
  const [created] = await db
    .insert(user)
    .values({ name, email, emailVerified: true, role, twoFactorEnabled })
    .returning({ id: user.id });
  if (spec.disciplines) {
    await db.insert(staffProfile).values({ userId: created.id, disciplines: spec.disciplines });
  }
  return { id: created.id, name, email, role, twoFactorEnabled };
}

export function mailbox() {
  const outbox: Mail[] = [];
  return {
    outbox,
    sendMail: async (mail: Mail) => {
      outbox.push(mail);
    },
    // The token at the end of the last invitation link.
    lastToken: () => outbox.at(-1)?.text.split("/invito/")[1]?.trim() ?? "",
  };
}
