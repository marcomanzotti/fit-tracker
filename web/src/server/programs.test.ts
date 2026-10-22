import { randomUUID } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Database, Db } from "@/db/client";
import { exercise, program } from "@/db/schema";
import type { ProgramDocument } from "@/lib/program/document";
import { parsePrescription } from "@/lib/program/shorthand";
import { freshDatabase, makeUser, mailbox, META } from "@/test/harness";
import type { Actor } from "./actor";
import { acceptInvitation, createInvitation } from "./care";
import { listSessions } from "./client-data";
import {
  assignTemplate,
  createProgram,
  getProgram,
  listPrograms,
  localDay,
  myProgram,
  programProgress,
  publishProgram,
  saveDraft,
} from "./programs";
import { push } from "./sync";

let database: Database;
let db: Db;
let pt: Actor;
let client: Actor;
let squat: string;
let bench: string;

const cell = (text: string) => {
  const result = parsePrescription(text);
  if (!result.ok) throw new Error(result.error);
  return result.value;
};

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
  pt = await makeUser(db, { role: "staff", name: "Paola PT", disciplines: ["pt"] });
  client = await follow(pt, "luca@example.test");
  const ids = await db.select({ id: exercise.id, slug: exercise.slug }).from(exercise);
  squat = ids.find((e) => e.slug === "back-squat")!.id;
  bench = ids.find((e) => e.slug === "barbell-bench-press")!.id;
});

afterEach(async () => {
  await database.close();
});

async function follow(professional: Actor, email: string) {
  const mail = mailbox();
  await createInvitation(
    db,
    professional,
    { kind: "client", email, assignmentRole: "pt" },
    { sendMail: mail.sendMail, baseUrl: "https://studio.example" },
  );
  const followed = await makeUser(db, { email });
  const consent = { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true as const, staffSharing: true };
  await acceptInvitation(db, followed, { token: mail.lastToken(), consent }, META);
  return followed;
}

function strengthDoc(): ProgramDocument {
  return {
    schemaVersion: 1,
    weeks: 4,
    phases: [],
    days: [
      {
        id: "dayA",
        label: "Giorno A",
        weekday: 1,
        blocks: [
          {
            id: "b1",
            type: "single",
            items: [{ id: "sq", exerciseId: squat, base: cell("3x5@75%"), progression: { rule: "none" }, overrides: {} }],
          },
          {
            id: "b2",
            type: "single",
            items: [
              { id: "bp", exerciseId: bench, base: cell("4x8@60kg"), progression: { rule: "load", step: 2.5 }, overrides: {} },
            ],
          },
        ],
      },
    ],
  };
}

async function publishedProgram() {
  const created = await createProgram(db, pt, { clientId: client.id, title: "Forza base", weeks: 4 });
  await saveDraft(db, pt, created.id, { draft: strengthDoc(), revision: created.draftRevision });
  const version = await publishProgram(db, pt, created.id, { startDate: "2020-01-06" });
  return { programId: created.id, versionId: version.id };
}

function loggedSession(
  versionId: string,
  sets: { reps: number; loadKg: number }[],
  { itemId = "sq", day = "2020-01-06" }: { itemId?: string; day?: string } = {},
) {
  return {
    entity: "workout_session" as const,
    op: "upsert" as const,
    id: randomUUID(),
    data: {
      localDay: day,
      title: "Giorno A",
      programVersionId: versionId,
      dayId: "dayA",
      week: 1,
      exercises: [
        {
          id: randomUUID(),
          exerciseId: itemId === "sq" ? squat : bench,
          name: itemId === "sq" ? "Squat con bilanciere" : "Panca piana con bilanciere",
          itemId,
          target: "3x5@75%",
          sets: sets.map((set) => ({ id: randomUUID(), type: "work", ...set })),
        },
      ],
    },
  };
}

describe("program drafts", () => {
  it("are created by the client's professional and saved with a revision check", async () => {
    const created = await createProgram(db, pt, { clientId: client.id, title: "Ipertrofia", weeks: 6 });

    const saved = await saveDraft(db, pt, created.id, { draft: strengthDoc(), revision: 1, title: "Forza 12 settimane" });
    const stale = saveDraft(db, pt, created.id, { draft: strengthDoc(), revision: 1 });

    expect(created).toMatchObject({ status: "draft", draftRevision: 1 });
    expect(created.draft.weeks).toBe(6);
    expect(saved.draftRevision).toBe(2);
    expect(saved.title).toBe("Forza 12 settimane");
    await expect(stale).rejects.toMatchObject({ code: "edited_elsewhere" });
  });

  it("reject exercises that are not in the library", async () => {
    const created = await createProgram(db, pt, { clientId: client.id, title: "X" });
    const draft = strengthDoc();
    draft.days[0].blocks[0].items[0].exerciseId = randomUUID();

    await expect(saveDraft(db, pt, created.id, { draft, revision: 1 })).rejects.toMatchObject({ code: "unknown_exercise" });
  });

  it("are closed to clients and to professionals who do not follow the client", async () => {
    const stranger = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    await expect(createProgram(db, client, { clientId: client.id, title: "Mia" })).rejects.toMatchObject({ status: 403 });
    await expect(createProgram(db, stranger, { clientId: client.id, title: "X" })).rejects.toMatchObject({ code: "no_access" });
  });
});

describe("publishing", () => {
  it("creates numbered versions and keeps only one active program per client", async () => {
    const { programId } = await publishedProgram();
    const second = await createProgram(db, pt, { clientId: client.id, title: "Fase 2" });
    await saveDraft(db, pt, second.id, { draft: strengthDoc(), revision: 1 });

    const again = await publishProgram(db, pt, programId, { changeNote: "Più volume" });
    await publishProgram(db, pt, second.id, {});
    const [first] = await db.select({ status: program.status }).from(program).where(eq(program.id, programId));
    const detail = await getProgram(db, pt, programId);

    expect(again.version).toBe(2);
    expect(detail.versions.map((v) => v.version)).toEqual([2, 1]);
    expect(first.status).toBe("archived");
  });

  it("refuses templates and empty programs", async () => {
    const template = await createProgram(db, pt, { title: "Template PPL" });
    const empty = await createProgram(db, pt, { clientId: client.id, title: "Vuota" });

    await expect(publishProgram(db, pt, template.id, {})).rejects.toMatchObject({ code: "template_not_publishable" });
    await expect(publishProgram(db, pt, empty.id, {})).rejects.toMatchObject({ code: "empty_program" });
  });
});

describe("the client's program", () => {
  it("is resolved for the current week, with kg suggested from logged sets", async () => {
    const { versionId } = await publishedProgram();
    // Logged today: the e1RM only looks at the last 180 days.
    const today = localDay("Europe/Rome");
    await push(db, client, { mutations: [loggedSession(versionId, [{ reps: 5, loadKg: 120 }], { day: today })] });

    const mine = await myProgram(db, client);

    // Started long ago: clamped to the last week, where bench has had 3 load steps.
    expect(mine?.week).toBe(4);
    const [squatItem, benchItem] = mine!.days[0].blocks.map((block) => block.items[0]);
    expect(squatItem.exercise?.nameIt).toBe("Squat con bilanciere");
    expect(squatItem.targetText).toBe("3x5@75%");
    // 75% of 120 x (1 + 5/30) = 105 kg
    expect(squatItem.suggestedKg).toEqual([105]);
    expect(benchItem.targetText).toBe("4x8@67,5kg");
  });

  it("is null when nothing is published", async () => {
    expect(await myProgram(db, client)).toBeNull();
  });
});

describe("logged sessions", () => {
  it("can only point at the client's own program", async () => {
    const { versionId } = await publishedProgram();
    const other = await follow(pt, "anna@example.test");

    const [result] = await push(db, other, { mutations: [loggedSession(versionId, [{ reps: 5, loadKg: 100 }])] });

    expect(result).toMatchObject({ status: "invalid", error: "Unknown program version" });
  });

  it("are readable by the professional through the access guard", async () => {
    const { versionId } = await publishedProgram();
    await push(db, client, { mutations: [loggedSession(versionId, [{ reps: 5, loadKg: 100 }, { reps: 5, loadKg: 100 }])] });

    const [session] = await listSessions(db, pt, client.id, {}, null);

    expect(session.exercises[0].sets.map((s) => s.loadKg)).toEqual([100, 100]);
  });
});

describe("planned vs done", () => {
  it("shows the target and the logged sets per item and week", async () => {
    const { programId, versionId } = await publishedProgram();
    await push(db, client, { mutations: [loggedSession(versionId, [{ reps: 5, loadKg: 100 }, { reps: 5, loadKg: 100 }])] });

    const progress = await programProgress(db, pt, programId);

    const squatRow = progress.days[0].items.find((item) => item.itemId === "sq")!;
    expect(squatRow.weeks[0]).toMatchObject({ week: 1, planned: "3x5@75%", completion: 2 / 3 });
    expect(squatRow.weeks[0].done.map((s) => s.loadKg)).toEqual([100, 100]);
    expect(squatRow.weeks[1].completion).toBe(0);
  });
});

describe("templates", () => {
  it("are copied to each followed client as an independent draft", async () => {
    const template = await createProgram(db, pt, { title: "PPL 3 giorni" });
    await saveDraft(db, pt, template.id, { draft: strengthDoc(), revision: 1 });
    const second = await follow(pt, "giulia@example.test");

    const created = await assignTemplate(db, pt, template.id, { clientIds: [client.id, second.id] });
    const forLuca = await listPrograms(db, pt, { clientId: client.id });
    const templates = await listPrograms(db, pt, {});

    expect(created).toHaveLength(2);
    expect(forLuca[0]).toMatchObject({ title: "PPL 3 giorni", status: "draft" });
    expect(templates.map((t) => t.id)).toEqual([template.id]);
  });

  it("cannot be assigned to a client the professional does not follow", async () => {
    const template = await createProgram(db, pt, { title: "T" });
    const stranger = await makeUser(db);

    await expect(assignTemplate(db, pt, template.id, { clientIds: [stranger.id] })).rejects.toMatchObject({
      status: 403,
    });
  });
});
