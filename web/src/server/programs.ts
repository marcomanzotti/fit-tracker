import { and, desc, eq, gte, inArray, isNull, max, ne, sql } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import {
  clientProfile,
  exercise,
  program,
  programVersion,
  sessionExercise,
  setLog,
  workoutSession,
} from "@/db/schema";
import {
  emptyDocument,
  exerciseIdsOf,
  MAX_WEEKS,
  programDocumentSchema,
  type ProgramDocument,
} from "@/lib/program/document";
import { estimateOneRepMax, isOverridden, resolveItem, suggestedKg, weekOf } from "@/lib/program/resolve";
import { formatPrescription } from "@/lib/program/shorthand";
import { withClientAccess } from "./access";
import { isStaffRole, type Actor } from "./actor";
import { badRequest, conflict, forbidden, notFound } from "./http";
import { parseWith } from "./validate";

// Programs (schede) and their versions (ADR-0003). Professionals work on drafts;
// a client only ever sees the published version, resolved for the current week.

const E1RM_LOOKBACK_DAYS = 180;
const PROGRESSING_SET_TYPES = ["work", "amrap", "backoff"];

export const createProgramInput = z.object({
  clientId: z.uuid().optional(),
  title: z.string().trim().min(1).max(120),
  goal: z.string().trim().max(500).optional(),
  weeks: z.int().min(1).max(MAX_WEEKS).default(4),
});
export const saveDraftInput = z.object({ draft: programDocumentSchema, revision: z.int().min(1) });
export const publishInput = z.object({
  changeNote: z.string().trim().max(500).optional(),
  startDate: z.iso.date().optional(),
});
export const assignInput = z.object({ clientIds: z.array(z.uuid()).min(1).max(50) });
export const listInput = z.object({ clientId: z.uuid().optional() });

type ProgramRow = typeof program.$inferSelect;

// Calendar day in the client's time zone: "today" is the client's today.
export function localDay(timezone: string, at = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit" }).format(at);
}

async function loadProgram(db: Db, id: string): Promise<ProgramRow> {
  const [row] = await db.select().from(program).where(eq(program.id, id));
  if (!row) throw notFound("Program");
  return row;
}

// Programs are training data. Templates (no client) are the studio's shared
// library: any professional may use them. Drafts are staff work: never clients.
async function withProgramAccess<T>(
  db: Db,
  actor: Actor,
  row: Pick<ProgramRow, "id" | "clientId">,
  action: "read" | "write",
  work: (db: Db) => Promise<T>,
): Promise<T> {
  if (!isStaffRole(actor.role)) throw forbidden();
  if (!row.clientId) return work(db);
  return withClientAccess(db, actor, row.clientId, { scope: "training", resource: "program", resourceId: row.id, action }, work);
}

export async function createProgram(db: Db, actor: Actor, raw: unknown) {
  const input = parseWith(createProgramInput, raw);
  const target = { id: "new", clientId: input.clientId ?? null };
  return withProgramAccess(db, actor, target, "write", async (tx) => {
    const [created] = await tx
      .insert(program)
      .values({
        clientId: input.clientId ?? null,
        ownerId: actor.id,
        title: input.title,
        goal: input.goal ?? null,
        draft: emptyDocument(input.weeks),
      })
      .returning();
    return created;
  });
}

export async function listPrograms(db: Db, actor: Actor, raw: unknown) {
  const { clientId } = parseWith(listInput, raw);
  const columns = {
    id: program.id,
    clientId: program.clientId,
    title: program.title,
    goal: program.goal,
    status: program.status,
    startDate: program.startDate,
    activeVersionId: program.activeVersionId,
    updatedAt: program.updatedAt,
  };
  const target = { id: "list", clientId: clientId ?? null };
  return withProgramAccess(db, actor, target, "read", (tx) =>
    tx
      .select(columns)
      .from(program)
      .where(clientId ? eq(program.clientId, clientId) : isNull(program.clientId))
      .orderBy(desc(program.updatedAt)),
  );
}

export async function getProgram(db: Db, actor: Actor, id: string) {
  const row = await loadProgram(db, id);
  return withProgramAccess(db, actor, row, "read", async (tx) => {
    const versions = await tx
      .select({
        id: programVersion.id,
        version: programVersion.version,
        changeNote: programVersion.changeNote,
        publishedAt: programVersion.publishedAt,
      })
      .from(programVersion)
      .where(eq(programVersion.programId, id))
      .orderBy(desc(programVersion.version));
    return { ...row, versions };
  });
}

// Autosave from the editor. `revision` is the one the editor loaded: if someone
// else saved in the meantime, the save is refused instead of overwriting them.
export async function saveDraft(db: Db, actor: Actor, id: string, raw: unknown) {
  const input = parseWith(saveDraftInput, raw);
  const row = await loadProgram(db, id);
  return withProgramAccess(db, actor, row, "write", async (tx) => {
    await assertExercisesExist(tx, input.draft);
    const [saved] = await tx
      .update(program)
      .set({ draft: input.draft, draftRevision: input.revision + 1 })
      .where(and(eq(program.id, id), eq(program.draftRevision, input.revision)))
      .returning({ draftRevision: program.draftRevision, updatedAt: program.updatedAt });
    if (!saved) throw conflict("edited_elsewhere", "Someone else changed this program: reload to see their edits");
    return saved;
  });
}

async function assertExercisesExist(tx: Db, doc: ProgramDocument): Promise<void> {
  const ids = exerciseIdsOf(doc);
  if (ids.length === 0) return;
  const found = await tx.select({ id: exercise.id }).from(exercise).where(inArray(exercise.id, ids));
  if (found.length !== ids.length) throw badRequest("unknown_exercise", "The program uses an exercise that is not in the library");
}

// Freezes the draft as the next version; the client sees it from now on. A
// client follows one program at a time, so their other active ones are archived.
export async function publishProgram(db: Db, actor: Actor, id: string, raw: unknown) {
  const input = parseWith(publishInput, raw);
  const row = await loadProgram(db, id);
  const clientId = row.clientId;
  if (!clientId) throw badRequest("template_not_publishable", "Assign the template to a client, then publish it");
  if (row.draft.days.length === 0) throw badRequest("empty_program", "Add at least one day before publishing");

  return withProgramAccess(db, actor, row, "write", async (tx) => {
    await tx.select({ id: program.id }).from(program).where(eq(program.id, id)).for("update");
    const [{ latest }] = await tx
      .select({ latest: max(programVersion.version) })
      .from(programVersion)
      .where(eq(programVersion.programId, id));
    const [version] = await tx
      .insert(programVersion)
      .values({
        programId: id,
        version: (latest ?? 0) + 1,
        content: row.draft,
        changeNote: input.changeNote ?? null,
        publishedBy: actor.id,
      })
      .returning();
    const startDate = input.startDate ?? row.startDate ?? localDay(await clientTimezone(tx, clientId));
    await tx
      .update(program)
      .set({ status: "active", activeVersionId: version.id, startDate })
      .where(eq(program.id, id));
    await tx
      .update(program)
      .set({ status: "archived" })
      .where(and(eq(program.clientId, clientId), eq(program.status, "active"), ne(program.id, id)));
    return version;
  });
}

export async function archiveProgram(db: Db, actor: Actor, id: string) {
  const row = await loadProgram(db, id);
  return withProgramAccess(db, actor, row, "write", async (tx) => {
    const [archived] = await tx.update(program).set({ status: "archived" }).where(eq(program.id, id)).returning();
    return archived;
  });
}

// Copies a template to each client as a draft: a copy, not a link, so editing
// one client's program never changes another's. The PT reviews, then publishes.
export async function assignTemplate(db: Db, actor: Actor, templateId: string, raw: unknown) {
  const { clientIds } = parseWith(assignInput, raw);
  const template = await loadProgram(db, templateId);
  if (template.clientId) throw badRequest("not_a_template", "Only templates can be assigned");
  const created: { clientId: string; programId: string }[] = [];
  for (const clientId of [...new Set(clientIds)]) {
    const copy = await withProgramAccess(db, actor, { id: templateId, clientId }, "write", async (tx) => {
      const [row] = await tx
        .insert(program)
        .values({
          clientId,
          ownerId: actor.id,
          title: template.title,
          goal: template.goal,
          draft: template.draft,
          sourceTemplateId: template.id,
        })
        .returning({ id: program.id });
      return row;
    });
    created.push({ clientId, programId: copy.id });
  }
  return created;
}

async function clientTimezone(db: Db, clientId: string): Promise<string> {
  const [profile] = await db
    .select({ timezone: clientProfile.timezone })
    .from(clientProfile)
    .where(eq(clientProfile.userId, clientId));
  return profile?.timezone ?? "Europe/Rome";
}

// Best recent Epley estimate per exercise, from the client's logged work sets.
async function recentOneRepMaxes(db: Db, clientId: string, exerciseIds: string[], today: string) {
  const result = new Map<string, number>();
  if (exerciseIds.length === 0) return result;
  const since = new Date(Date.parse(`${today}T00:00:00Z`) - E1RM_LOOKBACK_DAYS * 86_400_000).toISOString().slice(0, 10);
  const sets = await db
    .select({ exerciseId: sessionExercise.exerciseId, reps: setLog.reps, loadKg: setLog.loadKg })
    .from(setLog)
    .innerJoin(sessionExercise, eq(sessionExercise.id, setLog.sessionExerciseId))
    .innerJoin(workoutSession, eq(workoutSession.id, sessionExercise.sessionId))
    .where(
      and(
        eq(workoutSession.userId, clientId),
        isNull(workoutSession.deletedAt),
        gte(workoutSession.localDay, since),
        inArray(sessionExercise.exerciseId, exerciseIds),
        eq(setLog.done, true),
        inArray(setLog.type, PROGRESSING_SET_TYPES),
      ),
    );
  for (const set of sets) {
    const e1rm = set.exerciseId && set.loadKg && set.reps ? estimateOneRepMax(set.loadKg, set.reps) : null;
    if (set.exerciseId && e1rm && e1rm > (result.get(set.exerciseId) ?? 0)) result.set(set.exerciseId, e1rm);
  }
  return result;
}

async function exerciseNames(db: Db, ids: string[]) {
  if (ids.length === 0) return new Map<string, { nameIt: string; nameEn: string; kind: string; isBodyweight: boolean }>();
  const rows = await db
    .select({ id: exercise.id, nameIt: exercise.nameIt, nameEn: exercise.nameEn, kind: exercise.kind, isBodyweight: exercise.isBodyweight })
    .from(exercise)
    .where(inArray(exercise.id, ids));
  return new Map(rows.map(({ id, ...rest }) => [id, rest]));
}

// The client's active program, resolved for this week: what the app shows.
export async function myProgram(db: Db, actor: Actor) {
  const [active] = await db
    .select({ program, content: programVersion.content, version: programVersion.version, versionId: programVersion.id })
    .from(program)
    .innerJoin(programVersion, eq(programVersion.id, program.activeVersionId))
    .where(and(eq(program.clientId, actor.id), eq(program.status, "active")))
    .orderBy(desc(programVersion.publishedAt))
    .limit(1);
  if (!active) return null;

  const doc = active.content;
  const today = localDay(await clientTimezone(db, actor.id));
  const week = weekOf(doc, active.program.startDate ?? today, today);
  const ids = exerciseIdsOf(doc);
  const [names, maxes] = await Promise.all([exerciseNames(db, ids), recentOneRepMaxes(db, actor.id, ids, today)]);

  return {
    programId: active.program.id,
    versionId: active.versionId,
    version: active.version,
    title: active.program.title,
    goal: active.program.goal,
    startDate: active.program.startDate,
    week,
    weeks: doc.weeks,
    days: doc.days.map((day) => ({
      id: day.id,
      label: day.label,
      weekday: day.weekday ?? null,
      notes: day.notes ?? null,
      blocks: day.blocks.map((block) => ({
        id: block.id,
        type: block.type,
        rounds: block.rounds ?? null,
        restAfterSec: block.restAfterSec ?? null,
        items: block.items.map((item) => {
          const target = resolveItem(item, week, doc.phases);
          const e1rm = maxes.get(item.exerciseId) ?? null;
          return {
            itemId: item.id,
            exerciseId: item.exerciseId,
            exercise: names.get(item.exerciseId) ?? null,
            notes: item.notes ?? null,
            restSec: item.restSec ?? null,
            tempo: item.tempo ?? null,
            target,
            targetText: formatPrescription(target),
            suggestedKg: target.sets.map((group) => suggestedKg(group, e1rm)),
          };
        }),
      })),
    })),
  };
}

type DoneSet = { reps: number | null; loadKg: number | null; rir: number | null; type: string };

// Planned vs done for the PT: per item and week, the target and what the client
// actually logged against it, across every published version of the program.
export async function programProgress(db: Db, actor: Actor, id: string) {
  const row = await loadProgram(db, id);
  if (!row.clientId) throw badRequest("not_a_client_program", "Templates have no progress");
  return withProgramAccess(db, actor, row, "read", async (tx) => {
    // "Planned" is what the client was shown: the published version, not the draft.
    const [active] = row.activeVersionId
      ? await tx.select({ content: programVersion.content }).from(programVersion).where(eq(programVersion.id, row.activeVersionId))
      : [];
    const doc = active?.content ?? row.draft;
    const logged = await tx
      .select({
        itemId: sessionExercise.itemId,
        week: workoutSession.week,
        localDay: workoutSession.localDay,
        reps: setLog.reps,
        loadKg: setLog.loadKg,
        rir: setLog.rir,
        type: setLog.type,
      })
      .from(setLog)
      .innerJoin(sessionExercise, eq(sessionExercise.id, setLog.sessionExerciseId))
      .innerJoin(workoutSession, eq(workoutSession.id, sessionExercise.sessionId))
      .innerJoin(programVersion, eq(programVersion.id, workoutSession.programVersionId))
      .where(
        and(
          eq(programVersion.programId, id),
          isNull(workoutSession.deletedAt),
          eq(setLog.done, true),
          sql`${sessionExercise.itemId} is not null`,
        ),
      )
      .orderBy(workoutSession.localDay, setLog.position);

    const done = new Map<string, DoneSet[]>();
    for (const set of logged) {
      const key = `${set.itemId}:${set.week}`;
      done.set(key, [...(done.get(key) ?? []), set]);
    }
    const names = await exerciseNames(tx, exerciseIdsOf(doc));
    const weeks = Array.from({ length: doc.weeks }, (_, i) => i + 1);

    return {
      weeks: doc.weeks,
      days: doc.days.map((day) => ({
        id: day.id,
        label: day.label,
        items: day.blocks.flatMap((block) =>
          block.items.map((item) => ({
            itemId: item.id,
            exercise: names.get(item.exerciseId)?.nameIt ?? null,
            weeks: weeks.map((week) => {
              const target = resolveItem(item, week, doc.phases);
              const sets = done.get(`${item.id}:${week}`) ?? [];
              const plannedWork = target.sets.filter((g) => g.type !== "warmup").reduce((n, g) => n + g.count, 0);
              const doneWork = sets.filter((s) => s.type !== "warmup").length;
              return {
                week,
                planned: formatPrescription(target),
                overridden: isOverridden(item, week),
                done: sets,
                completion: plannedWork === 0 ? null : Math.min(1, doneWork / plannedWork),
              };
            }),
          })),
        ),
      })),
    };
  });
}
