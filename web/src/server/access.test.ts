import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Database, Db } from "@/db/client";
import { eq } from "drizzle-orm";
import { auditLog, user } from "@/db/schema";
import { freshDatabase, makeUser, mailbox, META } from "@/test/harness";
import { withClientAccess, type AccessRequest } from "./access";
import type { Actor } from "./actor";
import { acceptInvitation, createInvitation, listCare } from "./care";
import { setConsent } from "./consents";

const BODY: AccessRequest = { scope: "body", resource: "body_measurement", ipAddress: "203.0.113.9" };

let database: Database;
let db: Db;
let pt: Actor;
let client: Actor;

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
  pt = await makeUser(db, { role: "staff", disciplines: ["pt"] });
  client = await makeUser(db, { email: "client@example.test" });
  const mail = mailbox();
  await createInvitation(
    db,
    pt,
    { kind: "client", email: client.email, assignmentRole: "pt", scopes: ["training", "body"] },
    { sendMail: mail.sendMail, baseUrl: "https://studio.example" },
  );
  const consent = { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true as const, staffSharing: true };
  await acceptInvitation(db, client, { token: mail.lastToken(), consent }, META);
});

afterEach(async () => {
  await database.close();
});

const read = (actor: Actor, request: AccessRequest = BODY) =>
  withClientAccess(db, actor, client.id, request, async () => "data");

describe("withClientAccess", () => {
  it("lets the assigned professional read a covered scope and logs it", async () => {
    const result = await read(pt);

    const logs = await db.select().from(auditLog);
    expect(result).toBe("data");
    expect(logs).toHaveLength(1);
    expect(logs[0]).toMatchObject({
      actorId: pt.id,
      clientId: client.id,
      action: "read",
      resource: "body_measurement",
      ipAddress: "203.0.113.9",
    });
  });

  it("refuses a scope the assignment does not cover and logs the attempt", async () => {
    await expect(read(pt, { scope: "nutrition", resource: "food_log" })).rejects.toMatchObject({ code: "no_access" });

    const logs = await db.select().from(auditLog);
    expect(logs).toEqual([
      expect.objectContaining({ action: "denied", actorId: pt.id, clientId: client.id, resource: "food_log" }),
    ]);
  });

  it("logs a refused attempt on an id that is not a user, without linking it", async () => {
    await expect(
      withClientAccess(db, pt, "00000000-0000-4000-8000-000000000000", BODY, async () => "data"),
    ).rejects.toMatchObject({ status: 403 });

    const [log] = await db.select().from(auditLog);
    expect(log).toMatchObject({ action: "denied", clientId: null });
  });

  it("keeps the professional's name in the log after their account is deleted", async () => {
    await read(pt);
    await db.delete(user).where(eq(user.id, pt.id));

    const [log] = await db.select().from(auditLog);
    expect(log).toMatchObject({ actorId: null, actorName: pt.name, actorEmail: pt.email });
  });

  it("refuses a professional who does not follow the client", async () => {
    const stranger = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    await expect(read(stranger)).rejects.toMatchObject({ code: "no_access" });
  });

  it("gives an admin no access to health data without an assignment", async () => {
    const admin = await makeUser(db, { role: "admin" });

    await expect(read(admin)).rejects.toMatchObject({ code: "no_access" });
  });

  it("refuses other clients", async () => {
    const otherClient = await makeUser(db);

    await expect(read(otherClient)).rejects.toMatchObject({ status: 403 });
  });

  it("stops as soon as the client revokes health processing", async () => {
    await setConsent(
      db,
      client,
      { purpose: "health_processing", granted: false, policyVersion: PRIVACY_POLICY_VERSION },
      META,
    );

    await expect(read(pt)).rejects.toMatchObject({ status: 403 });
  });

  it("stops when the assignment ends", async () => {
    const [assignment] = await listCare(db, pt);
    const { endAssignment } = await import("./care");
    await endAssignment(db, pt, assignment.id, META);

    await expect(read(pt)).rejects.toMatchObject({ code: "no_access" });
  });

  it("lets clients read their own data without a log entry", async () => {
    expect(await read(client)).toBe("data");
    expect(await db.select().from(auditLog)).toEqual([]);
  });

  it("rolls back the log entry when the work fails", async () => {
    await expect(
      withClientAccess(db, pt, client.id, BODY, async () => {
        throw new Error("boom");
      }),
    ).rejects.toThrow("boom");

    expect(await db.select().from(auditLog)).toEqual([]);
  });
});
