import { randomUUID } from "node:crypto";
import { and, asc, desc, eq, isNull, sql } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { EXERCISE_KINDS, exercise, exerciseAlias, MUSCLE_GROUPS } from "@/db/schema";
import { normalizeName, slugify } from "@/lib/text";
import { isStaffRole, type Actor } from "./actor";
import { badRequest, conflict, forbidden } from "./http";
import { parseWith } from "./validate";

const DEFAULT_LIMIT = 20;
// pg_trgm's default word-similarity cut (0.6) misses phrases with two typos
// ("squatt bilancere"); 0.3, set for the query's transaction only, still uses
// the trigram index through the <% operator.
const MIN_SCORE = "0.3";
// Shorter queries match almost everything; they just list the library.
const MIN_QUERY_LENGTH = 2;
const SLUG_ATTEMPTS = 5;
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
  if (query.length < MIN_QUERY_LENGTH) {
    return db.select(columns).from(exercise).where(filters).orderBy(asc(exercise.nameIt)).limit(limit);
  }

  // The normalized query holds only [a-z0-9 ], so it is safe inside LIKE.
  const score = sql<number>`max(word_similarity(${query}, ${exerciseAlias.aliasNorm}))`;
  return db.transaction(async (tx) => {
    await tx.execute(sql`select set_config('pg_trgm.word_similarity_threshold', ${MIN_SCORE}, true)`);
    return tx
      .select({ ...columns, score })
      .from(exerciseAlias)
      .innerJoin(exercise, eq(exercise.id, exerciseAlias.exerciseId))
      .where(
        and(
          filters,
          sql`(${query} <% ${exerciseAlias.aliasNorm} or ${exerciseAlias.aliasNorm} like ${`%${query}%`})`,
        ),
      )
      .groupBy(exercise.id)
      .orderBy(desc(score), asc(exercise.nameIt))
      .limit(limit);
  });
}

// Professionals add exercises to the shared studio library.
export async function createExercise(db: Db, actor: Actor, raw: unknown) {
  if (!isStaffRole(actor.role)) throw forbidden();
  const input = parseWith(createExerciseInput, raw);
  const nameEn = input.nameEn ?? input.nameIt;
  const base = slugify(nameEn) || slugify(input.nameIt);
  if (!base) throw badRequest("invalid_name", "Use a name with letters or digits");

  return db.transaction(async (tx) => {
    // "plank", then "plank-2", "plank-3"...; ON CONFLICT makes concurrent creates safe.
    let created: Awaited<ReturnType<typeof insertExercise>> | undefined;
    for (let attempt = 1; !created && attempt <= SLUG_ATTEMPTS + 1; attempt++) {
      const suffix = attempt <= SLUG_ATTEMPTS ? String(attempt) : randomUUID().slice(0, 8);
      const slug = attempt === 1 ? base : `${base}-${suffix}`;
      created = await insertExercise(tx, { ...input, nameEn, slug, createdBy: actor.id });
    }
    if (!created) throw conflict("slug_taken", "Could not name this exercise, try a different name");
    const aliases = [...new Set([normalizeName(input.nameIt), normalizeName(nameEn)])].filter(Boolean);
    await tx
      .insert(exerciseAlias)
      .values(aliases.map((aliasNorm) => ({ aliasNorm, exerciseId: created.id })))
      .onConflictDoNothing();
    return created;
  });
}

async function insertExercise(tx: Db, values: typeof exercise.$inferInsert) {
  const [row] = await tx.insert(exercise).values(values).onConflictDoNothing({ target: exercise.slug }).returning(columns);
  return row;
}
