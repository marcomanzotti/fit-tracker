import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Database, Db } from "@/db/client";
import { careAssignment, consent, invitation, staffProfile, user } from "@/db/schema";
import { freshDatabase, makeUser, mailbox, META } from "@/test/harness";
import type { Actor } from "./actor";
import {
  acceptInvitation,
  createAssignment,
  createInvitation,
  endAssignment,
  listCare,
  previewInvitation,
  respondToAssignment,
  revokeInvitation,
} from "./care";
import { consentState, currentConsent, setConsent } from "./consents";

const CONSENT = { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true as const, staffSharing: true };

let database: Database;
let db: Db;
let mail: ReturnType<typeof mailbox>;
let admin: Actor;
let pt: Actor;

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
  mail = mailbox();
  admin = await makeUser(db, { role: "admin", name: "Admin" });
  pt = await makeUser(db, { role: "staff", name: "Paola PT", disciplines: ["pt"] });
});

afterEach(async () => {
  await database.close();
});

const deps = () => ({ sendMail: mail.sendMail, baseUrl: "https://studio.example" });

async function inviteClient(by: Actor, email: string) {
  await createInvitation(db, by, { kind: "client", email, assignmentRole: "pt" }, deps());
  return mail.lastToken();
}

describe("staff invitations", () => {
  it("lets an admin bring in a professional, who becomes staff on acceptance", async () => {
    await createInvitation(db, admin, { kind: "staff", email: "Nina@Example.test", disciplines: ["nutrition"] }, deps());
    const nina = await makeUser(db, { email: "nina@example.test" });

    await acceptInvitation(db, nina, { token: mail.lastToken() }, META);

    const [stored] = await db.select({ role: user.role }).from(user).where(eq(user.id, nina.id));
    const [profile] = await db.select().from(staffProfile).where(eq(staffProfile.userId, nina.id));
    expect(mail.outbox[0].to).toBe("nina@example.test");
    expect(stored.role).toBe("staff");
    expect(profile.disciplines).toEqual(["nutrition"]);
  });

  it("refuses staff invitations from anyone but an admin", async () => {
    await expect(
      createInvitation(db, pt, { kind: "staff", email: "x@example.test", disciplines: ["pt"] }, deps()),
    ).rejects.toMatchObject({ status: 403 });
  });

  it("stores only a hash of the token", async () => {
    await createInvitation(db, admin, { kind: "staff", email: "h@example.test", disciplines: ["pt"] }, deps());

    const [row] = await db.select({ tokenHash: invitation.tokenHash }).from(invitation);
    expect(row.tokenHash).not.toBe(mail.lastToken());
    expect(row.tokenHash).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe("client invitations", () => {
  it("creates an active assignment with the client's consents", async () => {
    const token = await inviteClient(pt, "luca@example.test");
    const luca = await makeUser(db, { email: "luca@example.test" });

    const result = await acceptInvitation(db, luca, { token: token, consent: CONSENT }, META);

    const [assignment] = await db.select().from(careAssignment).where(eq(careAssignment.clientId, luca.id));
    expect(result.assignmentId).toBe(assignment.id);
    expect(assignment).toMatchObject({ staffId: pt.id, role: "pt", status: "active" });
    expect(assignment.scopes).toEqual(["training", "body", "sleep", "vitals", "notes"]);
    expect(await currentConsent(db, luca.id, "health_processing")).toBe(true);
    expect(await currentConsent(db, luca.id, "staff_sharing", assignment.id)).toBe(true);
  });

  it("previews who invited the person before they sign in", async () => {
    const token = await inviteClient(pt, "anna@example.test");

    const preview = await previewInvitation(db, { token });

    expect(preview).toMatchObject({ inviterName: "Paola PT", assignmentRole: "pt", status: "valid" });
  });

  it("requires the consents before joining", async () => {
    const token = await inviteClient(pt, "noconsent@example.test");
    const client = await makeUser(db, { email: "noconsent@example.test" });

    await expect(acceptInvitation(db, client, { token: token }, META)).rejects.toMatchObject({
      status: 400,
      code: "consent_required",
    });
  });

  it("refuses consent given on an outdated privacy notice", async () => {
    const token = await inviteClient(pt, "old@example.test");
    const client = await makeUser(db, { email: "old@example.test" });

    await expect(
      acceptInvitation(db, client, { token: token, consent: { ...CONSENT, policyVersion: "2020-01-01" } }, META),
    ).rejects.toMatchObject({ code: "policy_outdated" });
  });

  it("only works for the invited email address", async () => {
    const token = await inviteClient(pt, "right@example.test");
    const someoneElse = await makeUser(db, { email: "wrong@example.test" });

    await expect(acceptInvitation(db, someoneElse, { token: token, consent: CONSENT }, META)).rejects.toMatchObject({
      code: "email_mismatch",
    });
  });

  it("can be used only once", async () => {
    const token = await inviteClient(pt, "once@example.test");
    const client = await makeUser(db, { email: "once@example.test" });
    await acceptInvitation(db, client, { token: token, consent: CONSENT }, META);

    await expect(acceptInvitation(db, client, { token: token, consent: CONSENT }, META)).rejects.toMatchObject({
      status: 410,
      code: "invitation_accepted",
    });
  });

  it("expires", async () => {
    const token = await inviteClient(pt, "late@example.test");
    await db.update(invitation).set({ expiresAt: new Date(Date.now() - 1000) });
    const client = await makeUser(db, { email: "late@example.test" });

    await expect(acceptInvitation(db, client, { token: token, consent: CONSENT }, META)).rejects.toMatchObject({
      code: "invitation_expired",
    });
  });

  it("lets a professional invite only in a role they have", async () => {
    await expect(
      createInvitation(db, pt, { kind: "client", email: "c@example.test", assignmentRole: "nutrition" }, deps()),
    ).rejects.toMatchObject({ code: "discipline_mismatch" });
  });

  it("is not available to clients", async () => {
    const client = await makeUser(db);

    await expect(
      createInvitation(db, client, { kind: "client", email: "friend@example.test" }, deps()),
    ).rejects.toMatchObject({ status: 403 });
  });
});

describe("invitation safeguards", () => {
  it("refuses scopes outside the professional's role", async () => {
    const physio = await makeUser(db, { role: "staff", disciplines: ["physio"] });

    await expect(
      createInvitation(
        db,
        physio,
        { kind: "client", email: "p@example.test", assignmentRole: "physio", scopes: ["nutrition"] },
        deps(),
      ),
    ).rejects.toMatchObject({ code: "scope_not_allowed" });
  });

  it("caps invitations to the same address per day", async () => {
    for (let i = 0; i < 3; i++) await inviteClient(pt, "spam@example.test");

    await expect(inviteClient(pt, "spam@example.test")).rejects.toMatchObject({ status: 429 });
  });

  it("erases the email from the invitation once accepted", async () => {
    const token = await inviteClient(pt, "erase@example.test");
    const client = await makeUser(db, { email: "erase@example.test" });

    await acceptInvitation(db, client, { token, consent: CONSENT }, META);

    const [row] = await db.select({ email: invitation.email }).from(invitation);
    expect(row.email).toBeNull();
  });

  it("can be revoked by the inviter, after which the link no longer works", async () => {
    const created = await createInvitation(db, pt, { kind: "client", email: "rev@example.test", assignmentRole: "pt" }, deps());
    const token = mail.lastToken();
    const client = await makeUser(db, { email: "rev@example.test" });

    await revokeInvitation(db, pt, created.id);

    await expect(acceptInvitation(db, client, { token, consent: CONSENT }, META)).rejects.toMatchObject({
      code: "invitation_revoked",
    });
  });

  it("cannot be revoked by an unrelated professional", async () => {
    const created = await createInvitation(db, pt, { kind: "client", email: "mine@example.test", assignmentRole: "pt" }, deps());
    const other = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    await expect(revokeInvitation(db, other, created.id)).rejects.toMatchObject({ status: 404 });
  });

  it("never demotes an admin who accepts a staff invitation", async () => {
    const owner = await makeUser(db, { role: "admin", email: "owner@example.test" });
    await createInvitation(db, admin, { kind: "staff", email: "owner@example.test", disciplines: ["pt"] }, deps());

    await acceptInvitation(db, owner, { token: mail.lastToken() }, META);

    const [stored] = await db.select({ role: user.role }).from(user).where(eq(user.id, owner.id));
    expect(stored.role).toBe("admin");
  });

  it("accepts only once even when two requests race", async () => {
    const token = await inviteClient(pt, "race@example.test");
    const client = await makeUser(db, { email: "race@example.test" });

    const results = await Promise.allSettled([
      acceptInvitation(db, client, { token, consent: CONSENT }, META),
      acceptInvitation(db, client, { token, consent: CONSENT }, META),
    ]);

    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(await db.select().from(careAssignment).where(eq(careAssignment.clientId, client.id))).toHaveLength(1);
  });
});

describe("assignments", () => {
  async function joinedClient() {
    const token = await inviteClient(pt, "base@example.test");
    const client = await makeUser(db, { email: "base@example.test" });
    await acceptInvitation(db, client, { token: token, consent: CONSENT }, META);
    return client;
  }

  it("stay pending until the client accepts", async () => {
    const client = await joinedClient();
    const nutritionist = await makeUser(db, { role: "staff", disciplines: ["nutrition"] });

    const created = await createAssignment(db, admin, { clientId: client.id, staffId: nutritionist.id, role: "nutrition" });
    const accepted = await respondToAssignment(
      db,
      client,
      created.id,
      { accept: true, policyVersion: PRIVACY_POLICY_VERSION },
      META,
    );

    expect(created.status).toBe("pending");
    expect(created.scopes).toEqual(["nutrition", "body", "notes"]);
    expect(accepted.status).toBe("active");
    expect(await currentConsent(db, client.id, "staff_sharing", created.id)).toBe(true);
  });

  it("cannot be created twice for the same client, professional and role", async () => {
    const client = await joinedClient();

    await expect(createAssignment(db, admin, { clientId: client.id, staffId: pt.id, role: "pt" })).rejects.toMatchObject(
      { code: "assignment_exists" },
    );
  });

  it("end when the client withdraws, recording the revoked sharing consent", async () => {
    const client = await joinedClient();
    const [assignment] = await listCare(db, client);

    await endAssignment(db, client, assignment.id, META);

    expect(await listCare(db, client)).toEqual([]);
    expect(await currentConsent(db, client.id, "staff_sharing", assignment.id)).toBe(false);
  });

  it("all end when the client revokes consent to health processing", async () => {
    const client = await joinedClient();

    const state = await setConsent(
      db,
      client,
      { purpose: "health_processing", granted: false, policyVersion: PRIVACY_POLICY_VERSION },
      META,
    );

    expect(state.health_processing?.granted).toBe(false);
    expect(await listCare(db, pt)).toEqual([]);
  });

  it("are listed from both sides with names only", async () => {
    const client = await joinedClient();

    const [fromClient] = await listCare(db, client);
    const [fromStaff] = await listCare(db, pt);

    expect(fromClient.person).toMatchObject({ id: pt.id, name: "Paola PT" });
    expect(fromStaff.person).toMatchObject({ id: client.id, email: "base@example.test" });
  });

  it("cannot be ended by an unrelated professional", async () => {
    const client = await joinedClient();
    const [assignment] = await listCare(db, client);
    const other = await makeUser(db, { role: "staff", disciplines: ["pt"] });

    await expect(endAssignment(db, other, assignment.id, META)).rejects.toMatchObject({ status: 404 });
  });
});

describe("consent state", () => {
  it("reports the latest decision per purpose", async () => {
    const client = await makeUser(db);
    const version = PRIVACY_POLICY_VERSION;
    await setConsent(db, client, { purpose: "marketing", granted: true, policyVersion: version }, META);
    await setConsent(db, client, { purpose: "marketing", granted: false, policyVersion: version }, META);

    const state = await consentState(db, client.id);

    expect(state.marketing?.granted).toBe(false);
    expect(state.marketing?.outdated).toBe(false);
    expect(state.health_processing).toBeUndefined();
  });

  it("marks consents given on an older privacy notice as outdated", async () => {
    const client = await makeUser(db);
    await setConsent(db, client, { purpose: "marketing", granted: true, policyVersion: PRIVACY_POLICY_VERSION }, META);
    await db.update(consent).set({ policyVersion: "2020-01-01" });

    const state = await consentState(db, client.id);

    expect(state.marketing).toMatchObject({ granted: true, outdated: true });
  });
});
