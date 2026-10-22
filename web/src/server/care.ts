import { createHash, randomBytes } from "node:crypto";
import { and, eq, inArray, ne, or } from "drizzle-orm";
import { z } from "zod";
import { APP, INVITATION_TTL_DAYS } from "@/config";
import type { Db } from "@/db/client";
import {
  careAssignment,
  clientProfile,
  DISCIPLINES,
  invitation,
  SCOPES,
  staffProfile,
  user,
  type Discipline,
  type Scope,
} from "@/db/schema";
import { isStaffRole, requireRole, type Actor } from "./actor";
import { assertCurrentPolicy, currentConsent, recordConsent } from "./consents";
import { badRequest, conflict, forbidden, HttpError, notFound } from "./http";
import type { SendMail } from "./mail";
import { parseWith, type RequestMeta } from "./validate";

// What each professional sees by default; the inviter can narrow or widen it and
// the client sees the exact list before consenting.
export const DEFAULT_SCOPES: Record<Discipline, Scope[]> = {
  pt: ["training", "body", "sleep", "vitals", "notes"],
  nutrition: ["nutrition", "body", "notes"],
  physio: ["training", "body", "sleep", "vitals", "notes"],
};

const DAY_MS = 86_400_000;
const email = z.email().transform((value) => value.toLowerCase());
const disciplines = z.array(z.enum(DISCIPLINES)).min(1);
const scopes = z.array(z.enum(SCOPES)).min(1);

export const invitationInput = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("staff"), email, disciplines }),
  z.object({ kind: z.literal("admin"), email, disciplines: disciplines.optional() }),
  z.object({
    kind: z.literal("client"),
    email,
    assignmentRole: z.enum(DISCIPLINES).optional(),
    scopes: scopes.optional(),
  }),
]);

export const acceptInput = z.object({
  // Required for client invitations: the consents shown on the acceptance page.
  consent: z
    .object({
      policyVersion: z.string().min(1),
      healthProcessing: z.literal(true),
      staffSharing: z.boolean().optional(),
    })
    .optional(),
});

export const assignmentInput = z.object({
  clientId: z.uuid(),
  staffId: z.uuid(),
  role: z.enum(DISCIPLINES),
  scopes: scopes.optional(),
});

export const respondInput = z.object({ accept: z.boolean(), policyVersion: z.string().min(1) });

type MailDeps = { sendMail: SendMail; baseUrl: string };

const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

async function disciplinesOf(db: Db, userId: string): Promise<Discipline[]> {
  const [profile] = await db
    .select({ disciplines: staffProfile.disciplines })
    .from(staffProfile)
    .where(eq(staffProfile.userId, userId));
  return (profile?.disciplines ?? []) as Discipline[];
}

// ---- Invitations ----------------------------------------------------------

// Services validate their own input, so every caller (routes, tests, future jobs)
// goes through the same rules.
export async function createInvitation(db: Db, actor: Actor, raw: unknown, deps: MailDeps) {
  const input = parseWith(invitationInput, raw);
  if (input.kind !== "client") requireRole(actor, "admin");
  if (input.kind === "client") {
    if (!isStaffRole(actor.role)) throw forbidden();
    if (actor.role === "staff" && !input.assignmentRole) {
      throw badRequest("assignment_role_required", "Choose the role you will have with this client");
    }
    if (input.assignmentRole && !(await disciplinesOf(db, actor.id)).includes(input.assignmentRole)) {
      throw forbidden("discipline_mismatch", "You cannot follow clients with this role");
    }
  }

  const token = randomBytes(32).toString("base64url");
  const assignmentRole = input.kind === "client" ? input.assignmentRole : undefined;
  const [created] = await db
    .insert(invitation)
    .values({
      email: input.email,
      kind: input.kind,
      disciplines: input.kind === "client" ? null : (input.disciplines ?? null),
      assignmentRole: assignmentRole ?? null,
      scopes: assignmentRole ? ((input.kind === "client" && input.scopes) || DEFAULT_SCOPES[assignmentRole]) : null,
      invitedBy: actor.id,
      tokenHash: hashToken(token),
      expiresAt: new Date(Date.now() + INVITATION_TTL_DAYS * DAY_MS),
    })
    .returning({ id: invitation.id, email: invitation.email, kind: invitation.kind, expiresAt: invitation.expiresAt });

  await deps.sendMail({
    to: input.email,
    subject: `${APP.name}: ${actor.name} ti ha invitato`,
    text: `${actor.name} ti ha invitato su ${APP.name}. Apri il link entro ${INVITATION_TTL_DAYS} giorni:\n${deps.baseUrl}/invito/${token}`,
  });
  return created;
}

type InvitationRow = typeof invitation.$inferSelect;

function invitationStatus(row: InvitationRow): "valid" | "accepted" | "revoked" | "expired" {
  if (row.acceptedAt) return "accepted";
  if (row.revokedAt) return "revoked";
  if (row.expiresAt.getTime() < Date.now()) return "expired";
  return "valid";
}

// What the acceptance page shows before the user signs in.
export async function previewInvitation(db: Db, token: string) {
  const [row] = await db
    .select({ invitation, inviterName: user.name })
    .from(invitation)
    .innerJoin(user, eq(user.id, invitation.invitedBy))
    .where(eq(invitation.tokenHash, hashToken(token)));
  if (!row) throw notFound("Invitation");
  const { invitation: inv, inviterName } = row;
  return {
    kind: inv.kind,
    email: inv.email,
    inviterName,
    assignmentRole: inv.assignmentRole,
    scopes: inv.scopes,
    status: invitationStatus(inv),
    expiresAt: inv.expiresAt,
  };
}

export async function acceptInvitation(db: Db, actor: Actor, token: string, raw: unknown, meta: RequestMeta) {
  const input = parseWith(acceptInput, raw);
  return db.transaction(async (tx) => {
    const [inv] = await tx
      .select()
      .from(invitation)
      .where(eq(invitation.tokenHash, hashToken(token)))
      .for("update");
    if (!inv) throw notFound("Invitation");
    const status = invitationStatus(inv);
    if (status !== "valid") throw new HttpError(410, `invitation_${status}`, `This invitation is ${status}`);
    if (actor.email.toLowerCase() !== inv.email) {
      throw forbidden("email_mismatch", "This invitation was sent to a different email address");
    }

    const assignmentId =
      inv.kind === "client" ? await joinAsClient(tx, actor, inv, input, meta) : await joinAsStaff(tx, actor, inv);
    await tx.update(invitation).set({ acceptedAt: new Date(), acceptedBy: actor.id }).where(eq(invitation.id, inv.id));
    return { kind: inv.kind, assignmentId };
  });
}

async function joinAsStaff(tx: Db, actor: Actor, inv: InvitationRow): Promise<null> {
  const [openCare] = await tx
    .select({ id: careAssignment.id })
    .from(careAssignment)
    .where(and(eq(careAssignment.clientId, actor.id), ne(careAssignment.status, "ended")))
    .limit(1);
  if (openCare) throw conflict("followed_as_client", "End your care as a client before joining the staff");

  await tx.update(user).set({ role: inv.kind }).where(eq(user.id, actor.id));
  if (inv.disciplines?.length) {
    await tx
      .insert(staffProfile)
      .values({ userId: actor.id, disciplines: inv.disciplines })
      .onConflictDoUpdate({ target: staffProfile.userId, set: { disciplines: inv.disciplines } });
  }
  return null;
}

async function joinAsClient(
  tx: Db,
  actor: Actor,
  inv: InvitationRow,
  input: z.infer<typeof acceptInput>,
  meta: RequestMeta,
): Promise<string | null> {
  if (actor.role !== "client") throw conflict("staff_cannot_be_client", "Staff accounts cannot join as clients");
  const consent = input.consent;
  if (!consent || (inv.assignmentRole && consent.staffSharing !== true)) {
    throw badRequest("consent_required", "Accept the processing of your data to continue");
  }
  assertCurrentPolicy(consent.policyVersion);

  await recordConsent(tx, actor.id, { purpose: "health_processing", granted: true }, meta);
  await tx.insert(clientProfile).values({ userId: actor.id }).onConflictDoNothing();
  if (!inv.assignmentRole) return null;

  const assignmentId = await activateAssignment(tx, {
    clientId: actor.id,
    staffId: inv.invitedBy,
    role: inv.assignmentRole as Discipline,
    scopes: (inv.scopes ?? DEFAULT_SCOPES[inv.assignmentRole as Discipline]) as Scope[],
    createdBy: inv.invitedBy,
  });
  await recordConsent(tx, actor.id, { purpose: "staff_sharing", granted: true, refId: assignmentId }, meta);
  return assignmentId;
}

// Opens (or reactivates) the single non-ended assignment for client + staff + role.
async function activateAssignment(
  tx: Db,
  value: { clientId: string; staffId: string; role: Discipline; scopes: Scope[]; createdBy: string },
): Promise<string> {
  const now = new Date();
  const [existing] = await tx
    .select({ id: careAssignment.id })
    .from(careAssignment)
    .where(
      and(
        eq(careAssignment.clientId, value.clientId),
        eq(careAssignment.staffId, value.staffId),
        eq(careAssignment.role, value.role),
        ne(careAssignment.status, "ended"),
      ),
    );
  if (existing) {
    await tx
      .update(careAssignment)
      .set({ status: "active", scopes: value.scopes, activatedAt: now })
      .where(eq(careAssignment.id, existing.id));
    return existing.id;
  }
  const [created] = await tx
    .insert(careAssignment)
    .values({ ...value, status: "active", activatedAt: now })
    .returning({ id: careAssignment.id });
  return created.id;
}

// ---- Assignments ----------------------------------------------------------

// The admin pairs an existing client with a professional; it stays pending until
// the client accepts (and so consents to sharing these scopes).
export async function createAssignment(db: Db, actor: Actor, raw: unknown) {
  const input = parseWith(assignmentInput, raw);
  requireRole(actor, "admin");
  const people = await db
    .select({ id: user.id, role: user.role })
    .from(user)
    .where(inArray(user.id, [input.clientId, input.staffId]));
  const client = people.find((p) => p.id === input.clientId);
  const staff = people.find((p) => p.id === input.staffId);
  if (client?.role !== "client") throw badRequest("not_a_client", "The selected person is not a client");
  if (!staff || staff.role === "client") throw badRequest("not_staff", "The selected person is not staff");
  if (!(await disciplinesOf(db, input.staffId)).includes(input.role)) {
    throw badRequest("discipline_mismatch", "This professional does not have that role");
  }

  const [created] = await db
    .insert(careAssignment)
    .values({
      clientId: input.clientId,
      staffId: input.staffId,
      role: input.role,
      scopes: input.scopes ?? DEFAULT_SCOPES[input.role],
      createdBy: actor.id,
    })
    .onConflictDoNothing()
    .returning();
  if (!created) throw conflict("assignment_exists", "This professional already follows the client in this role");
  return created;
}

export async function respondToAssignment(
  db: Db,
  actor: Actor,
  assignmentId: string,
  raw: unknown,
  meta: RequestMeta,
) {
  const input = parseWith(respondInput, raw);
  return db.transaction(async (tx) => {
    const [assignment] = await tx
      .select()
      .from(careAssignment)
      .where(
        and(
          eq(careAssignment.id, assignmentId),
          eq(careAssignment.clientId, actor.id),
          eq(careAssignment.status, "pending"),
        ),
      )
      .for("update");
    if (!assignment) throw notFound("Pending assignment");

    if (input.accept) {
      assertCurrentPolicy(input.policyVersion);
      if (!(await currentConsent(tx, actor.id, "health_processing"))) {
        throw conflict("consent_required", "Consent to health data processing first");
      }
    }
    const [updated] = await tx
      .update(careAssignment)
      .set(
        input.accept
          ? { status: "active", activatedAt: new Date() }
          : { status: "ended", endedAt: new Date(), endedBy: actor.id },
      )
      .where(eq(careAssignment.id, assignmentId))
      .returning();
    await recordConsent(tx, actor.id, { purpose: "staff_sharing", granted: input.accept, refId: assignmentId }, meta);
    return updated;
  });
}

// The client, the professional or an admin can end a care relationship.
export async function endAssignment(db: Db, actor: Actor, assignmentId: string, meta: RequestMeta) {
  return db.transaction(async (tx) => {
    const [assignment] = await tx
      .select()
      .from(careAssignment)
      .where(and(eq(careAssignment.id, assignmentId), ne(careAssignment.status, "ended")))
      .for("update");
    const allowed =
      assignment &&
      (assignment.clientId === actor.id || assignment.staffId === actor.id || actor.role === "admin");
    if (!allowed) throw notFound("Assignment");

    const [ended] = await tx
      .update(careAssignment)
      .set({ status: "ended", endedAt: new Date(), endedBy: actor.id })
      .where(eq(careAssignment.id, assignmentId))
      .returning();
    if (assignment.clientId === actor.id) {
      await recordConsent(tx, actor.id, { purpose: "staff_sharing", granted: false, refId: assignmentId }, meta);
    }
    return ended;
  });
}

// Open relationships seen from either side: a client's professionals, or a
// professional's clients. Names and emails only; no health data.
export async function listCare(db: Db, actor: Actor) {
  const asClient = actor.role === "client";
  const other = asClient ? careAssignment.staffId : careAssignment.clientId;
  return db
    .select({
      id: careAssignment.id,
      role: careAssignment.role,
      scopes: careAssignment.scopes,
      status: careAssignment.status,
      activatedAt: careAssignment.activatedAt,
      person: { id: user.id, name: user.name, email: user.email },
    })
    .from(careAssignment)
    .innerJoin(user, eq(user.id, other))
    .where(
      and(
        asClient ? eq(careAssignment.clientId, actor.id) : eq(careAssignment.staffId, actor.id),
        or(eq(careAssignment.status, "active"), eq(careAssignment.status, "pending")),
      ),
    )
    .orderBy(user.name);
}
