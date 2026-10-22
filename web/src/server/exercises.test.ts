import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import type { Database, Db } from "@/db/client";
import { exercise } from "@/db/schema";
import { EXERCISE_SEED } from "@/db/seed/exercises";
import { seedReferenceData } from "@/db/seed";
import { freshDatabase, makeUser } from "@/test/harness";
import { createExercise, searchExercises } from "./exercises";

let database: Database;
let db: Db;

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
});

afterEach(async () => {
  await database.close();
});

const names = (rows: { nameIt: string }[]) => rows.map((row) => row.nameIt);

describe("exercise library", () => {
  it("is seeded once with the iOS library, even when seeding runs again", async () => {
    await seedReferenceData(db);

    const rows = await db.select({ id: exercise.id }).from(exercise);
    expect(rows).toHaveLength(EXERCISE_SEED.length);
  });

  it("finds exercises by Italian name", async () => {
    const results = await searchExercises(db, { q: "panca piana" });

    expect(names(results).slice(0, 2).sort()).toEqual(["Panca piana con bilanciere", "Panca piana con manubri"]);
  });

  it("finds exercises by English name", async () => {
    const [first] = await searchExercises(db, { q: "lat pulldown" });

    expect(first.nameIt).toBe("Lat machine");
  });

  it("tolerates typos and accents", async () => {
    expect(names(await searchExercises(db, { q: "squatt bilancere" }))).toContain("Squat con bilanciere");
    expect(names(await searchExercises(db, { q: "Àlzate laterali" }))[0]).toMatch(/^Alzate laterali/);
  });

  it("filters by muscle group and hides archived exercises", async () => {
    await db.update(exercise).set({ archivedAt: new Date() }).where(eq(exercise.slug, "plank"));

    const core = await searchExercises(db, { category: "core", limit: 100 });

    expect(core.every((row) => row.category === "core")).toBe(true);
    expect(names(core)).not.toContain("Plank");
  });

  it("lets professionals add exercises, searchable right away", async () => {
    const pt = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    const created = await createExercise(db, pt, { nameIt: "Panca Larsen", category: "chest" });
    const [found] = await searchExercises(db, { q: "larsen" });

    expect(created).toMatchObject({ slug: "panca-larsen", nameEn: "Panca Larsen", kind: "reps" });
    expect(found.id).toBe(created.id);
  });

  it("gives a second exercise with the same name its own slug", async () => {
    const pt = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    const created = await createExercise(db, pt, { nameIt: "Plank", category: "core" });

    expect(created.slug).toBe("plank-2");
  });

  it("does not let clients change the library", async () => {
    const client = await makeUser(db);

    await expect(createExercise(db, client, { nameIt: "Mio esercizio", category: "other" })).rejects.toMatchObject({
      status: 403,
    });
  });
});
