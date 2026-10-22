import { and, asc, eq, gt, inArray, isNull, sql } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { BODY_KINDS, bodyMeasurement, MEASUREMENT_SOURCES, workoutSession } from "@/db/schema";
import type { Actor } from "./actor";
import { currentConsent } from "./consents";
import { forbidden, isDataError, pgErrorCode } from "./http";
import { readSessions, upsertSession, type UpsertResult } from "./sessions";
import { parseWith } from "./validate";

// Sync protocol (ADR-0002). Every synced table carries the syncColumns (id,
// user_id, rev, deleted_at); each entity registered here knows how to write and
// read its own data, while pull, delete and ownership are shared.

// The shared columns are defined once (syncColumns), so the generic queries are
// typed against one synced table and work on all of them.
type SyncTable = typeof bodyMeasurement;

type SyncEntity = {
  table: SyncTable | typeof workoutSession;
  upsert(tx: Db, userId: string, id: string, data: unknown): Promise<UpsertResult>;
  // The data of live rows, by id.
  read(tx: Db, ids: string[]): Promise<Map<string, unknown>>;
};

const bodyData = z.object({
  measuredOn: z.iso.date(),
  kind: z.enum(BODY_KINDS),
  value: z.number().positive().lt(1000),
  source: z.enum(MEASUREMENT_SOURCES).default("manual"),
});

const entities = {
  body_measurement: {
    table: bodyMeasurement,
    async upsert(tx, userId, id, raw) {
      const parsed = bodyData.safeParse(raw);
      if (!parsed.success) return { status: "invalid", error: z.prettifyError(parsed.error) };
      const values = { ...parsed.data, deletedAt: null };
      // Insert, or update only when the existing row belongs to this user. A
      // later upsert of a deleted row brings it back (deletedAt reset).
      const written = await tx
        .insert(bodyMeasurement)
        .values({ ...values, id, userId })
        .onConflictDoUpdate({ target: bodyMeasurement.id, set: values, setWhere: eq(bodyMeasurement.userId, userId) })
        .returning({ id: bodyMeasurement.id });
      return { status: written.length > 0 ? "ok" : "forbidden" };
    },
    async read(tx, ids) {
      const rows = await tx
        .select({
          id: bodyMeasurement.id,
          measuredOn: bodyMeasurement.measuredOn,
          kind: bodyMeasurement.kind,
          value: bodyMeasurement.value,
          source: bodyMeasurement.source,
        })
        .from(bodyMeasurement)
        .where(inArray(bodyMeasurement.id, ids));
      return new Map(rows.map(({ id, ...data }) => [id, data]));
    },
  },
  workout_session: {
    table: workoutSession,
    upsert: upsertSession,
    async read(tx, ids) {
      const sessions = await readSessions(tx, ids);
      return new Map(sessions.map(({ id, ...data }) => [id, data]));
    },
  },
} satisfies Record<string, SyncEntity>;

type EntityName = keyof typeof entities;
const ENTITY_NAMES = Object.keys(entities) as [EntityName, ...EntityName[]];
const shared = (entity: EntityName) => entities[entity].table as SyncTable;

const DEFAULT_PULL = 500;
const MAX_PULL = 1000;
const MAX_PUSH = 500;

export const pullInput = z.object({
  cursor: z.coerce.number().int().min(0).default(0),
  limit: z.coerce.number().int().min(1).max(MAX_PULL).default(DEFAULT_PULL),
});

export const pushInput = z.object({
  mutations: z
    .array(
      z.object({
        entity: z.enum(ENTITY_NAMES),
        op: z.enum(["upsert", "delete"]),
        id: z.uuid(),
        data: z.unknown().optional(),
      }),
    )
    .max(MAX_PUSH),
});

export type Change = { entity: EntityName; id: string; rev: number; deleted: boolean; data: unknown };
export type MutationResult = { id: string; status: "ok" | "forbidden" | "invalid"; error?: string };

// Writes for one user are serialized by the bump_sync_rev trigger (migration
// 0005), so their revs commit in order and a pull cursor never skips a late row.
// push takes the same lock up front, with a timeout, so a burst of retries from
// one phone waits a bounded time instead of piling up on the connection pool.
const LOCK_TIMEOUT = "5s";

async function lockUser(tx: Db, userId: string): Promise<void> {
  await tx.execute(sql`select set_config('lock_timeout', ${LOCK_TIMEOUT}, true)`);
  await tx.execute(sql`select pg_advisory_xact_lock(hashtext('sync'), hashtext(${userId}))`);
}

export async function pull(db: Db, actor: Actor, raw: unknown) {
  const { cursor, limit } = parseWith(pullInput, raw);
  // One snapshot for all entities: separate snapshots could see a later rev of
  // one entity but miss an earlier rev of another committed in between.
  const perEntity = await db.transaction(
    (tx) => Promise.all(ENTITY_NAMES.map((entity) => pullEntity(tx, actor.id, entity, cursor, limit))),
    { isolationLevel: "repeatable read", accessMode: "read only" },
  );
  // Merge by rev and cut at `limit`: anything not returned has a higher rev than
  // the new cursor, so the next pull picks it up.
  const all = perEntity.flat().sort((a, b) => a.rev - b.rev);
  const changes = all.slice(0, limit);
  return { changes, cursor: changes.at(-1)?.rev ?? cursor, hasMore: all.length > limit };
}

async function pullEntity(tx: Db, userId: string, entity: EntityName, cursor: number, limit: number) {
  const table = shared(entity);
  const rows = await tx
    .select({ id: table.id, rev: table.rev, deletedAt: table.deletedAt })
    .from(table)
    .where(and(eq(table.userId, userId), gt(table.rev, cursor)))
    .orderBy(asc(table.rev))
    .limit(limit + 1);
  const live = rows.filter((row) => row.deletedAt === null).map((row) => row.id);
  const data = live.length > 0 ? await entities[entity].read(tx, live) : new Map<string, unknown>();
  return rows.map(
    (row): Change => ({
      entity,
      id: row.id,
      rev: row.rev,
      deleted: row.deletedAt !== null,
      data: row.deletedAt ? null : (data.get(row.id) ?? null),
    }),
  );
}

export async function push(db: Db, actor: Actor, raw: unknown): Promise<MutationResult[]> {
  const { mutations } = parseWith(pushInput, raw);
  // Every synced entity holds health data (ADR-0005).
  if (mutations.length > 0 && !(await currentConsent(db, actor.id, "health_processing"))) {
    throw forbidden("consent_required", "Consent to health data processing first");
  }

  return db.transaction(async (tx) => {
    await lockUser(tx, actor.id);
    const results: MutationResult[] = [];
    for (const mutation of mutations) {
      // A savepoint per mutation: a row the database rejects as bad data (SQLSTATE
      // class 22/23) is reported as invalid instead of blocking the app's queue
      // forever. Anything else (timeout, deadlock, lost connection) fails the whole
      // push so the app retries it later rather than dropping good data.
      try {
        results.push(await tx.transaction((savepoint) => applyMutation(savepoint, actor, mutation)));
      } catch (error: unknown) {
        const code = pgErrorCode(error);
        if (!code || !isDataError(code)) throw error;
        // Code only: the error text would carry the health values.
        console.error(`sync mutation rejected entity=${mutation.entity} id=${mutation.id} code=${code}`);
        results.push({ id: mutation.id, status: "invalid", error: "Rejected by the server" });
      }
    }
    return results;
  });
}

type Mutation = z.infer<typeof pushInput>["mutations"][number];

async function applyMutation(tx: Db, actor: Actor, mutation: Mutation): Promise<MutationResult> {
  if (mutation.op === "delete") return removeRow(tx, actor, mutation);
  const result = await entities[mutation.entity].upsert(tx, actor.id, mutation.id, mutation.data);
  if (result.status === "forbidden") return forbiddenResult(mutation.id);
  return result.status === "invalid" ? { id: mutation.id, ...result } : { id: mutation.id, status: "ok" };
}

async function removeRow(tx: Db, actor: Actor, mutation: Mutation): Promise<MutationResult> {
  const table = shared(mutation.entity);
  // Only live rows: a repeated delete must not bump rev again.
  const deleted = await tx
    .update(table)
    .set({ deletedAt: new Date() })
    .where(and(eq(table.id, mutation.id), eq(table.userId, actor.id), isNull(table.deletedAt)))
    .returning({ id: table.id });
  if (deleted.length > 0) return { id: mutation.id, status: "ok" };
  // Already deleted, or never seen by the server (created and deleted offline):
  // fine. Someone else's row: not.
  const [row] = await tx.select({ userId: table.userId }).from(table).where(eq(table.id, mutation.id));
  return row && row.userId !== actor.id ? forbiddenResult(mutation.id) : { id: mutation.id, status: "ok" };
}

const forbiddenResult = (id: string): MutationResult => ({ id, status: "forbidden", error: "Not your record" });
