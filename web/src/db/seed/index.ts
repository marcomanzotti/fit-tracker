import { normalizeName, slugify } from "@/lib/text";
import type { Db } from "../client";
import { exercise, exerciseAlias } from "../schema";
import { EXERCISE_SEED } from "./exercises";

// Reference data every installation needs. Idempotent: existing rows (and the
// studio's edits to them) are left alone, so it runs after every migration.
export async function seedReferenceData(db: Db): Promise<void> {
  const rows = EXERCISE_SEED.map(([category, nameEn, nameIt, ...flags]) => ({
    slug: slugify(nameEn),
    nameEn,
    nameIt,
    category,
    isBodyweight: flags.includes("bw"),
    kind: flags.find((flag) => flag !== "bw") ?? "reps",
  }));

  await db.transaction(async (tx) => {
    const inserted = await tx
      .insert(exercise)
      .values(rows)
      .onConflictDoNothing({ target: exercise.slug })
      .returning({ id: exercise.id, nameEn: exercise.nameEn, nameIt: exercise.nameIt });
    if (inserted.length === 0) return;

    const aliases = inserted.flatMap((row) =>
      [...new Set([normalizeName(row.nameEn), normalizeName(row.nameIt)])].map((aliasNorm) => ({
        aliasNorm,
        exerciseId: row.id,
      })),
    );
    await tx.insert(exerciseAlias).values(aliases).onConflictDoNothing();
  });
}
