import { sql } from "drizzle-orm";
import {
  boolean,
  check,
  date,
  doublePrecision,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import type { ProgramDocument } from "@/lib/program/document";
import { SET_TYPES } from "@/lib/program/document";
import { user } from "./auth";
import { syncColumns } from "./health";
import { inList } from "./sql";
import { exercise } from "./training";

const TZ = { withTimezone: true } as const;

export const PROGRAM_STATUSES = ["draft", "active", "archived"] as const;
export const SESSION_SOURCES = ["manual", "program", "health_connect", "ios_import"] as const;

// A client's program, or a template when client_id is null (ADR-0003). The PT
// edits `draft`; publishing copies it into an immutable program_version.
// draft_revision guards against two PTs overwriting each other's edits.
export const program = pgTable(
  "program",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    clientId: uuid("client_id").references(() => user.id, { onDelete: "cascade" }),
    ownerId: uuid("owner_id").references(() => user.id, { onDelete: "set null" }),
    title: text("title").notNull(),
    goal: text("goal"),
    startDate: date("start_date"),
    status: text("status").notNull().default("draft"),
    draft: jsonb("draft").$type<ProgramDocument>().notNull(),
    draftRevision: integer("draft_revision").notNull().default(1),
    activeVersionId: uuid("active_version_id"),
    sourceTemplateId: uuid("source_template_id"),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", TZ)
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (t) => [
    index("program_client_idx").on(t.clientId),
    index("program_owner_idx").on(t.ownerId),
    check("program_status_check", sql`${t.status} in (${sql.raw(inList(PROGRAM_STATUSES))})`),
    check("program_title_check", sql`length(${t.title}) between 1 and 120`),
  ],
);

export const programVersion = pgTable(
  "program_version",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    programId: uuid("program_id")
      .notNull()
      .references(() => program.id, { onDelete: "cascade" }),
    version: integer("version").notNull(),
    content: jsonb("content").$type<ProgramDocument>().notNull(),
    changeNote: text("change_note"),
    publishedBy: uuid("published_by").references(() => user.id, { onDelete: "set null" }),
    publishedAt: timestamp("published_at", TZ).defaultNow().notNull(),
  },
  (t) => [unique("program_version_unique").on(t.programId, t.version)],
);

// A logged workout, written by the client's devices (synced, ADR-0002). Exercises
// and sets are stored as rows so the dashboard can query them, but they travel
// as one aggregate with the session (src/server/sessions.ts).
export const workoutSession = pgTable(
  "workout_session",
  {
    ...syncColumns(),
    localDay: date("local_day").notNull(),
    startedAt: timestamp("started_at", TZ),
    endedAt: timestamp("ended_at", TZ),
    title: text("title").notNull(),
    // The prescription followed, so planned vs done is exact after edits.
    programVersionId: uuid("program_version_id").references(() => programVersion.id, { onDelete: "set null" }),
    dayId: text("day_id"),
    week: integer("week"),
    durationSec: integer("duration_sec"),
    rpe: integer("rpe"),
    notes: text("notes"),
    source: text("source").notNull().default("manual"),
  },
  (t) => [
    index("workout_session_user_rev_idx").on(t.userId, t.rev),
    index("workout_session_user_day_idx").on(t.userId, t.localDay),
    index("workout_session_version_idx").on(t.programVersionId),
    check("workout_session_rpe_check", sql`${t.rpe} is null or ${t.rpe} between 1 and 10`),
    check("workout_session_source_check", sql`${t.source} in (${sql.raw(inList(SESSION_SOURCES))})`),
  ],
);

export const sessionExercise = pgTable(
  "session_exercise",
  {
    id: uuid("id").primaryKey(),
    sessionId: uuid("session_id")
      .notNull()
      .references(() => workoutSession.id, { onDelete: "cascade" }),
    position: integer("position").notNull(),
    exerciseId: uuid("exercise_id").references(() => exercise.id, { onDelete: "set null" }),
    // Name as shown when logged, kept even if the library entry is renamed.
    name: text("name").notNull(),
    // The program item followed and its target as text ("4x8@80kg").
    itemId: text("item_id"),
    target: text("target"),
    notes: text("notes"),
  },
  (t) => [
    index("session_exercise_session_idx").on(t.sessionId),
    index("session_exercise_exercise_idx").on(t.exerciseId),
  ],
);

export const setLog = pgTable(
  "set_log",
  {
    id: uuid("id").primaryKey(),
    sessionExerciseId: uuid("session_exercise_id")
      .notNull()
      .references(() => sessionExercise.id, { onDelete: "cascade" }),
    position: integer("position").notNull(),
    type: text("type").notNull().default("work"),
    reps: integer("reps"),
    loadKg: doublePrecision("load_kg"),
    seconds: integer("seconds"),
    rir: doublePrecision("rir"),
    rpe: doublePrecision("rpe"),
    done: boolean("done").notNull().default(true),
  },
  (t) => [
    index("set_log_exercise_idx").on(t.sessionExerciseId),
    check("set_log_type_check", sql`${t.type} in (${sql.raw(inList(SET_TYPES))})`),
    check("set_log_reps_check", sql`${t.reps} is null or ${t.reps} between 0 and 1000`),
    check("set_log_load_check", sql`${t.loadKg} is null or ${t.loadKg} between 0 and 1000`),
  ],
);
