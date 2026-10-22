import { and, asc, desc, eq, isNull, sql } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { EXERCISE_KINDS, exercise, exerciseAlias, MUSCLE_GROUPS } from "@/db/schema";
import { normalizeName, slugify } from "@/lib/text";
import { isStaffRole, type Actor } from "./actor";
import { forbidden } from "./http";
import { parseWith } from "./validate";

const DEFAULT_LIMIT = 20;
// pg_trgm's default word-similarity cut (0.6) misses phrases with two typos
// ("squatt bilancere"); the library is a few hundred aliases, so a lower bar
// ordered by score stays cheap and precise enough.
const MIN_SCORE = 0.3;
const MAX_LIMIT = 100;

export const searchInput = z.object({
  q: z.string().trim().max(100).optional(),
  category: z.enum(MUSCLE_GROUPS).optional(),
  limit: z.coerce.number().int().min(1).max(MAX_LIMIT).default(DEFAULT_LIMIT),
});

export const createExerciseInput = z.object({
  nameIt: z.string().trim().min(2).max(100),
  nameEn: z.string().trim().min(2).max(100).optional(),
  category: z.enum(MUSCLE_GROUPS),
  kind: z.enum(EXERCISE_KINDS).default("reps"),
  isBodyweight: z.boolean().default(false),
});

const columns = {
  id: exercise.id,
  slug: exercise.slug,
  nameIt: exercise.nameIt,
  nameEn: exercise.nameEn,
  category: exercise.category,
  kind: exercise.kind,
  isBodyweight: exercise.isBodyweight,
};

// Search by any known name, tolerant to typos and partial words
// ("panca pi", "squatt", "lat pulldown" -> Lat machine). Without a query the
// library is listed alphabetically (Italian names), optionally by muscle group.
export async function searchExercises(db: Db, raw: unknown) {
  const { q, category, limit } = parseWith(searchInput, raw);
  const filters = and(isNull(exercise.archivedAt), category ? eq(exercise.category, category) : undefined);
  const query = q ? normalizeName(q) : "";
  if (!query) {
    return db.select(columns).from(exercise).where(filters).orderBy(asc(exercise.nameIt)).limit(limit);
  }

  // The normalized query holds only [a-z0-9 ], so it is safe inside LIKE.
  const score = sql<number>`max(word_similarity(${query}, ${exerciseAlias.aliasNorm}))`;
  return db
    .select({ ...columns, score })
    .from(exerciseAlias)
    .innerJoin(exercise, eq(exercise.id, exerciseAlias.exerciseId))
    .where(
      and(
        filters,
        sql`(word_similarity(${query}, ${exerciseAlias.aliasNorm}) >= ${MIN_SCORE} or ${exerciseAlias.aliasNorm} like ${`%${query}%`})`,
      ),
    )
    .groupBy(exercise.id)
    .orderBy(desc(score), asc(exercise.nameIt))
    .limit(limit);
}

// Professionals add exercises to the shared studio library.
export async function createExercise(db: Db, actor: Actor, raw: unknown) {
  if (!isStaffRole(actor.role)) throw forbidden();
  const input = parseWith(createExerciseInput, raw);
  const nameEn = input.nameEn ?? input.nameIt;

  return db.transaction(async (tx) => {
    const base = slugify(nameEn);
    const taken = await tx
      .select({ slug: exercise.slug })
      .from(exercise)
      .where(sql`${exercise.slug} = ${base} or ${exercise.slug} like ${`${base}-%`}`);
    const slug = taken.length === 0 ? base : `${base}-${taken.length + 1}`;

    const [created] = await tx
      .insert(exercise)
      .values({ ...input, nameEn, slug, createdBy: actor.id })
      .returning(columns);
    const aliases = [...new Set([normalizeName(input.nameIt), normalizeName(nameEn)])];
    await tx
      .insert(exerciseAlias)
      .values(aliases.map((aliasNorm) => ({ aliasNorm, exerciseId: created.id })))
      .onConflictDoNothing();
    return created;
  });
}
