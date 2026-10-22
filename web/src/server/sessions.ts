import { and, asc, eq, inArray } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { program, programVersion, SESSION_SOURCES, sessionExercise, setLog, workoutSession } from "@/db/schema";
import { SET_TYPES } from "@/lib/program/document";

// A logged workout as the apps send and receive it: the session with its
// exercises and sets, one sync aggregate (ADR-0002). Stored as rows.

const setSchema = z.object({
  id: z.uuid(),
  type: z.enum(SET_TYPES).default("work"),
  reps: z.int().min(0).max(1000).nullish(),
  loadKg: z.number().min(0).max(1000).nullish(),
  seconds: z.int().min(0).max(36_000).nullish(),
  rir: z.number().min(0).max(10).nullish(),
  rpe: z.number().min(1).max(10).nullish(),
  done: z.boolean().default(true),
});

const exerciseSchema = z.object({
  id: z.uuid(),
  exerciseId: z.uuid().nullish(),
  name: z.string().trim().min(1).max(120),
  itemId: z.string().max(40).nullish(),
  target: z.string().max(200).nullish(),
  notes: z.string().max(1000).nullish(),
  sets: z.array(setSchema).max(50),
});

export const sessionDataSchema = z.object({
  localDay: z.iso.date(),
  startedAt: z.iso.datetime({ offset: true }).nullish(),
  endedAt: z.iso.datetime({ offset: true }).nullish(),
  title: z.string().trim().min(1).max(120),
  programVersionId: z.uuid().nullish(),
  dayId: z.string().max(40).nullish(),
  week: z.int().min(1).max(52).nullish(),
  durationSec: z.int().min(0).max(86_400).nullish(),
  rpe: z.int().min(1).max(10).nullish(),
  notes: z.string().max(2000).nullish(),
  source: z.enum(SESSION_SOURCES).default("manual"),
  exercises: z.array(exerciseSchema).max(40),
});
export type SessionData = z.infer<typeof sessionDataSchema>;

export type UpsertResult = { status: "ok" | "forbidden" } | { status: "invalid"; error: string };

// Insert or replace a session owned by `userId`. The program version must be one
// of the user's own programs: a client cannot attach their log to someone else's.
export async function upsertSession(tx: Db, userId: string, id: string, raw: unknown): Promise<UpsertResult> {
  const parsed = sessionDataSchema.safeParse(raw);
  if (!parsed.success) return { status: "invalid", error: z.prettifyError(parsed.error) };
  const { exercises, ...session } = parsed.data;

  if (session.programVersionId && !(await ownsVersion(tx, userId, session.programVersionId))) {
    return { status: "invalid", error: "Unknown program version" };
  }
  const values = {
    ...session,
    startedAt: session.startedAt ? new Date(session.startedAt) : null,
    endedAt: session.endedAt ? new Date(session.endedAt) : null,
    deletedAt: null,
  };
  const written = await tx
    .insert(workoutSession)
    .values({ ...values, id, userId })
    .onConflictDoUpdate({ target: workoutSession.id, set: values, setWhere: eq(workoutSession.userId, userId) })
    .returning({ id: workoutSession.id });
  if (written.length === 0) return { status: "forbidden" };

  // Children are replaced as a whole: the device always sends the full session.
  await tx.delete(sessionExercise).where(eq(sessionExercise.sessionId, id));
  if (exercises.length > 0) {
    await tx.insert(sessionExercise).values(
      exercises.map((exercise, position) => ({
        id: exercise.id,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        itemId: exercise.itemId,
        target: exercise.target,
        notes: exercise.notes,
        sessionId: id,
        position,
      })),
    );
    const sets = exercises.flatMap((exercise) =>
      exercise.sets.map((set, position) => ({ ...set, sessionExerciseId: exercise.id, position })),
    );
    if (sets.length > 0) await tx.insert(setLog).values(sets);
  }
  return { status: "ok" };
}

async function ownsVersion(tx: Db, userId: string, versionId: string): Promise<boolean> {
  const [row] = await tx
    .select({ id: programVersion.id })
    .from(programVersion)
    .innerJoin(program, eq(program.id, programVersion.programId))
    .where(and(eq(programVersion.id, versionId), eq(program.clientId, userId)));
  return row !== undefined;
}

export type LoggedSession = SessionData & { id: string };

// Full sessions (with exercises and sets) for the given ids, in input order.
export async function readSessions(tx: Db, ids: string[]): Promise<LoggedSession[]> {
  if (ids.length === 0) return [];
  const sessions = await tx.select().from(workoutSession).where(inArray(workoutSession.id, ids));
  const exercises = await tx
    .select()
    .from(sessionExercise)
    .where(inArray(sessionExercise.sessionId, ids))
    .orderBy(asc(sessionExercise.position));
  const sets =
    exercises.length === 0
      ? []
      : await tx
          .select()
          .from(setLog)
          .where(
            inArray(
              setLog.sessionExerciseId,
              exercises.map((exercise) => exercise.id),
            ),
          )
          .orderBy(asc(setLog.position));

  const byId = new Map(sessions.map((session) => [session.id, session]));
  return ids.flatMap((id) => {
    const session = byId.get(id);
    if (!session) return [];
    return [
      {
        id,
        localDay: session.localDay,
        startedAt: session.startedAt?.toISOString() ?? null,
        endedAt: session.endedAt?.toISOString() ?? null,
        title: session.title,
        programVersionId: session.programVersionId,
        dayId: session.dayId,
        week: session.week,
        durationSec: session.durationSec,
        rpe: session.rpe,
        notes: session.notes,
        source: session.source as SessionData["source"],
        exercises: exercises
          .filter((exercise) => exercise.sessionId === id)
          .map((exercise) => ({
            id: exercise.id,
            exerciseId: exercise.exerciseId,
            name: exercise.name,
            itemId: exercise.itemId,
            target: exercise.target,
            notes: exercise.notes,
            sets: sets
              .filter((set) => set.sessionExerciseId === exercise.id)
              .map(({ id: setId, type, reps, loadKg, seconds, rir, rpe, done }) => ({
                id: setId,
                type: type as SessionData["exercises"][number]["sets"][number]["type"],
                reps,
                loadKg,
                seconds,
                rir,
                rpe,
                done,
              })),
          })),
      },
    ];
  });
}
