import { randomUUID } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Database, Db } from "@/db/client";
import { freshDatabase, makeUser, mailbox, META } from "@/test/harness";
import { exportAccount, getMe, updateProfile } from "./account";
import type { Actor } from "./actor";
import { acceptInvitation, createInvitation } from "./care";
import { listBodyMeasurements } from "./client-data";
import { push } from "./sync";

let database: Database;
let db: Db;
let pt: Actor;
let client: Actor;

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
  pt = await makeUser(db, { role: "staff", name: "Paola PT", disciplines: ["pt"] });
  client = await makeUser(db, { email: "luca@example.test", name: "Luca" });
  const mail = mailbox();
  await createInvitation(
    db,
    pt,
    { kind: "client", email: client.email, assignmentRole: "pt" },
    { sendMail: mail.sendMail, baseUrl: "https://studio.example" },
  );
  const consent = { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true as const, staffSharing: true };
  await acceptInvitation(db, client, { token: mail.lastToken(), consent }, META);
  await push(db, client, {
    mutations: [
      { entity: "body_measurement", op: "upsert", id: randomUUID(), data: { measuredOn: "2026-10-01", kind: "weight", value: 84 } },
      { entity: "body_measurement", op: "upsert", id: randomUUID(), data: { measuredOn: "2026-10-15", kind: "weight", value: 82.5 } },
    ],
  });
});

afterEach(async () => {
  await database.close();
});

describe("me", () => {
  it("returns the user, profile, consents and care team in one call", async () => {
    const me = await getMe(db, client);

    expect(me.user).toMatchObject({ email: "luca@example.test", role: "client" });
    expect(me.profile).toMatchObject({ timezone: "Europe/Rome" });
    expect(me.consents.health_processing?.granted).toBe(true);
    expect(me.care[0].person.name).toBe("Paola PT");
  });

  it("updates the client's profile and validates it", async () => {
    const saved = await updateProfile(db, client, { sex: "m", birthDate: "1995-04-02", heightCm: 181 });

    expect(saved).toMatchObject({ sex: "m", birthDate: "1995-04-02", heightCm: 181 });
    await expect(updateProfile(db, client, { heightCm: 20 })).rejects.toMatchObject({ code: "validation_failed" });
    await expect(updateProfile(db, client, { timezone: "Mars/Olympus" })).rejects.toMatchObject({ status: 400 });
  });
});

describe("staff reading client data", () => {
  it("returns the measurements in a date range and logs the access", async () => {
    const rows = await listBodyMeasurements(db, pt, client.id, { from: "2026-10-10" }, "203.0.113.4");
    const exported = await exportAccount(db, client);

    expect(rows.map((row) => row.value)).toEqual([82.5]);
    expect(exported.accessLog).toEqual([
      expect.objectContaining({ action: "read", resource: "body_measurement", staff: { name: "Paola PT", email: pt.email } }),
    ]);
  });
});

describe("export", () => {
  it("contains the account, consents, care team and measurements, without secrets", async () => {
    const exported = await exportAccount(db, client);

    expect(exported.account).toMatchObject({ email: "luca@example.test" });
    expect(exported.consents.map((c) => c.purpose)).toEqual(["health_processing", "staff_sharing"]);
    expect(exported.care[0]).toMatchObject({ role: "pt", status: "active", staff: { name: "Paola PT" } });
    expect(exported.bodyMeasurements.map((m) => m.value)).toEqual([84, 82.5]);
    expect(JSON.stringify(exported)).not.toMatch(/password|token/i);
  });
});
