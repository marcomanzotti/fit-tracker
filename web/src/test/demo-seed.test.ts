import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { PRIVACY_POLICY_VERSION } from "@/config";
import { createDatabase, type Db } from "@/db/client";
import { exercise, staffProfile, user } from "@/db/schema";
import type { ProgramDocument, ProgramItem } from "@/lib/program/document";
import { parsePrescription } from "@/lib/program/shorthand";
import type { Actor } from "@/server/actor";
import { createAuth } from "@/server/auth";
import { acceptInvitation, createInvitation } from "@/server/care";
import { createProgram, publishProgram, saveDraft } from "@/server/programs";
import { push } from "@/server/sync";

// Demo data for trying the web app locally: `npm run seed:demo`, then `npm run dev`.
// Not a test: it only runs when DEMO_DATABASE_URL is set (never in CI). It fills an
// empty development database and writes signed-in sessions to .data for
// screenshot checks; the admin's session predates its 2FA, so it stays valid.

const url = process.env.DEMO_DATABASE_URL;
const BASE_URL = "http://localhost:3000";
const PASSWORD = "demo-password-123";

const cell = (text: string) => {
  const parsed = parsePrescription(text);
  if (!parsed.ok) throw new Error(parsed.error);
  return parsed.value;
};

const daysAgo = (days: number) => new Date(Date.now() - days * 86_400_000).toISOString().slice(0, 10);

describe.skipIf(!url)("demo data", () => {
  it("fills the development database", { timeout: 120_000 }, async () => {
    const database = createDatabase(url as string);
    await database.migrate();
    const db = database.db;
    const [existing] = await db.select({ id: user.id }).from(user).where(eq(user.email, "admin@demo.test"));
    if (existing) throw new Error("Demo data already present: delete web/.data/dev to start over.");

    const auth = createAuth({
      db,
      secret: process.env.BETTER_AUTH_SECRET ?? "local-development-only-secret-not-used-in-prod",
      baseURL: BASE_URL,
      sendMail: async () => undefined,
      rateLimit: false,
    });

    async function signUp(name: string, email: string) {
      await auth.api.signUpEmail({ body: { name, email, password: PASSWORD } });
      await db.update(user).set({ emailVerified: true }).where(eq(user.email, email));
      const response = await auth.handler(
        new Request(`${BASE_URL}/api/auth/sign-in/email`, {
          method: "POST",
          headers: { "content-type": "application/json", origin: BASE_URL },
          body: JSON.stringify({ email, password: PASSWORD }),
        }),
      );
      const cookie = response.headers.get("set-cookie")?.split(";")[0] ?? "";
      const [found] = await db.select().from(user).where(eq(user.email, email));
      const actor: Actor = { id: found.id, email, name, role: "client", twoFactorEnabled: false };
      return { cookie, actor };
    }

    // An admin who also works as a PT, and a client they follow.
    const admin = await signUp("Marco Admin", "admin@demo.test");
    await db.update(user).set({ role: "admin", twoFactorEnabled: true }).where(eq(user.id, admin.actor.id));
    await db.insert(staffProfile).values({ userId: admin.actor.id, disciplines: ["pt"] });
    const coach: Actor = { ...admin.actor, role: "admin", twoFactorEnabled: true };
    const client = await signUp("Luca Bianchi", "luca@demo.test");

    let token = "";
    await createInvitation(
      db,
      coach,
      { kind: "client", email: "luca@demo.test", assignmentRole: "pt" },
      {
        sendMail: async (mail) => {
          token = mail.text.split("/invito#")[1]?.trim() ?? "";
        },
        baseUrl: BASE_URL,
      },
    );
    const consent = { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true as const, staffSharing: true };
    await acceptInvitation(db, client.actor, { token, consent }, { ipAddress: null, userAgent: "demo-seed" });

    const program = await createProgram(db, coach, { clientId: client.actor.id, title: "Forza e ipertrofia", weeks: 6 });
    const draft = await demoProgram(db);
    await saveDraft(db, coach, program.id, { draft, revision: program.draftRevision });
    const version = await publishProgram(db, coach, program.id, { startDate: daysAgo(10), changeNote: "Prima versione" });

    await push(db, client.actor, {
      mutations: [
        ...[84.2, 83.9, 83.5, 83.6, 83.1].map((value, index) => ({
          entity: "body_measurement" as const,
          op: "upsert" as const,
          id: randomUUID(),
          data: { measuredOn: daysAgo(14 - index * 3), kind: "weight", value },
        })),
        demoSession(version.id, draft, 1, daysAgo(9), [100, 100, 100]),
        demoSession(version.id, draft, 2, daysAgo(2), [102.5, 102.5]),
      ],
    });

    mkdirSync(".data", { recursive: true });
    writeFileSync(
      ".data/demo-sessions.json",
      JSON.stringify({ admin: admin.cookie, client: client.cookie, programId: program.id, clientId: client.actor.id }, null, 2),
    );
    console.info(`Demo pronta. Accedi con admin@demo.test o luca@demo.test, password ${PASSWORD}.`);
    expect(admin.cookie).toContain("=");
    await database.close();
  });
});

async function demoProgram(db: Db): Promise<ProgramDocument> {
  const rows = await db.select({ id: exercise.id, slug: exercise.slug }).from(exercise);
  const id = (slug: string) => {
    const found = rows.find((row) => row.slug === slug);
    if (!found) throw new Error(`missing exercise ${slug}`);
    return found.id;
  };
  const item = (itemId: string, slug: string, base: string, progression: ProgramItem["progression"] = { rule: "none" }): ProgramItem => ({
    id: itemId,
    exerciseId: id(slug),
    base: cell(base),
    progression,
    overrides: {},
    restSec: 120,
  });
  return {
    schemaVersion: 1,
    weeks: 6,
    phases: [{ id: "deload6", name: "Scarico", fromWeek: 6, toWeek: 6, deload: true }],
    days: [
      {
        id: "dayA",
        label: "Giorno A",
        weekday: 1,
        blocks: [
          { id: "a1", type: "single", items: [item("squat", "back-squat", "w:2x5@60kg + 3x5@100kg", { rule: "load", step: 2.5 })] },
          {
            id: "a2",
            type: "superset",
            items: [
              item("bench", "flat-dumbbell-press", "4x8-10@RIR2", { rule: "reps", step: 1 }),
              item("row", "barbell-row", "4x10@60kg", { rule: "load", step: 2.5 }),
            ],
          },
          { id: "a3", type: "single", items: [item("plank", "plank", "3x45s")] },
        ],
      },
      {
        id: "dayB",
        label: "Giorno B",
        weekday: 4,
        blocks: [
          { id: "b1", type: "single", items: [item("rdl", "romanian-deadlift", "4x8@RPE8")] },
          { id: "b2", type: "single", items: [item("lat", "lat-pulldown", "4x10-12@RIR2", { rule: "reps", step: 1 })] },
          { id: "b3", type: "single", items: [item("press", "overhead-barbell-press", "3x6@75%")] },
        ],
      },
    ],
  };
}

function demoSession(versionId: string, doc: ProgramDocument, week: number, day: string, squatLoads: number[]) {
  const squat = doc.days[0].blocks[0].items[0];
  return {
    entity: "workout_session" as const,
    op: "upsert" as const,
    id: randomUUID(),
    data: {
      localDay: day,
      title: "Giorno A",
      programVersionId: versionId,
      dayId: "dayA",
      week,
      source: "program",
      exercises: [
        {
          id: randomUUID(),
          exerciseId: squat.exerciseId,
          name: "Squat con bilanciere",
          itemId: squat.id,
          target: "3x5@100kg",
          sets: squatLoads.map((loadKg) => ({ id: randomUUID(), type: "work", reps: 5, loadKg, done: true })),
        },
      ],
    },
  };
}
