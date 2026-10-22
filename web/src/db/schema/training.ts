import { sql } from "drizzle-orm";
import { boolean, check, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { inList } from "./sql";

const TZ = { withTimezone: true } as const;

// Same groups as the iOS MuscleGroup enum, so imported sessions map 1:1.
export const MUSCLE_GROUPS = [
  "chest",
  "back",
  "legs",
  "shoulders",
  "arms",
  "core",
  "fullbody",
  "cardio",
  "other",
] as const;
export type MuscleGroup = (typeof MUSCLE_GROUPS)[number];

export const EXERCISE_KINDS = ["reps", "timed", "interval"] as const;
export type ExerciseKind = (typeof EXERCISE_KINDS)[number];

// The studio's exercise library. Stable ids replace the iOS habit of matching by
// name; never deleted (sessions and programs point at them), only archived.
export const exercise = pgTable(
  "exercise",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    slug: text("slug").notNull().unique(),
    nameIt: text("name_it").notNull(),
    nameEn: text("name_en").notNull(),
    category: text("category").notNull(),
    kind: text("kind").notNull().default("reps"),
    isBodyweight: boolean("is_bodyweight").notNull().default(false),
    mediaUrl: text("media_url"),
    createdBy: uuid("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
    archivedAt: timestamp("archived_at", TZ),
  },
  (t) => [
    check("exercise_category_check", sql`${t.category} in (${sql.raw(inList(MUSCLE_GROUPS))})`),
    check("exercise_kind_check", sql`${t.kind} in (${sql.raw(inList(EXERCISE_KINDS))})`),
  ],
);

// Every name an exercise is known by (Italian, English, the free text typed on
// iOS or in an Excel sheet), normalized; fuzzy-searched with pg_trgm.
export const exerciseAlias = pgTable(
  "exercise_alias",
  {
    aliasNorm: text("alias_norm").primaryKey(),
    exerciseId: uuid("exercise_id")
      .notNull()
      .references(() => exercise.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
  },
  (t) => [
    index("exercise_alias_trgm_idx").using("gin", sql`${t.aliasNorm} gin_trgm_ops`),
    index("exercise_alias_exercise_idx").on(t.exerciseId),
  ],
);
