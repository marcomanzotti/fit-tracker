import { and, asc, desc, eq, isNull } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { auditLog, bodyMeasurement, careAssignment, clientProfile, consent, SEXES, user } from "@/db/schema";
import type { Actor } from "./actor";
import { listCare } from "./care";
import { consentState } from "./consents";
import { forbidden } from "./http";
import { parseWith } from "./validate";

export const profileInput = z.object({
  sex: z.enum(SEXES).nullable().optional(),
  birthDate: z.iso.date().nullable().optional(),
  heightCm: z.number().min(100).max(250).nullable().optional(),
  timezone: z
    .string()
    .refine((tz) => Intl.supportedValuesOf("timeZone").includes(tz), "Unknown time zone")
    .optional(),
});

// Everything the apps need after sign-in, in one call.
export async function getMe(db: Db, actor: Actor) {
  const [profile] =
    actor.role === "client" ? await db.select().from(clientProfile).where(eq(clientProfile.userId, actor.id)) : [];
  return {
    user: { id: actor.id, email: actor.email, name: actor.name, role: actor.role, twoFactorEnabled: actor.twoFactorEnabled },
    profile: profile ?? null,
    consents: await consentState(db, actor.id),
    care: await listCare(db, actor),
  };
}

export async function updateProfile(db: Db, actor: Actor, raw: unknown) {
  if (actor.role !== "client") throw forbidden();
  const input = parseWith(profileInput, raw);
  const [saved] = await db
    .insert(clientProfile)
    .values({ userId: actor.id, ...input })
    .onConflictDoUpdate({ target: clientProfile.userId, set: input })
    .returning();
  return saved;
}

// GDPR art. 15/20: a machine-readable copy of everything stored about the user,
// including who among the staff looked at their data and when.
export async function exportAccount(db: Db, actor: Actor) {
  const [account] = await db
    .select({ id: user.id, email: user.email, name: user.name, role: user.role, createdAt: user.createdAt })
    .from(user)
    .where(eq(user.id, actor.id));
  const staff = { name: user.name, email: user.email };
  return {
    exportedAt: new Date().toISOString(),
    account,
    profile: (await db.select().from(clientProfile).where(eq(clientProfile.userId, actor.id)))[0] ?? null,
    consents: await db
      .select({
        purpose: consent.purpose,
        refId: consent.refId,
        granted: consent.granted,
        scopes: consent.scopes,
        policyVersion: consent.policyVersion,
        ipAddress: consent.ipAddress,
        userAgent: consent.userAgent,
        at: consent.createdAt,
      })
      .from(consent)
      .where(eq(consent.userId, actor.id))
      .orderBy(asc(consent.seq)),
    care: await db
      .select({
        role: careAssignment.role,
        scopes: careAssignment.scopes,
        status: careAssignment.status,
        activatedAt: careAssignment.activatedAt,
        endedAt: careAssignment.endedAt,
        staff,
      })
      .from(careAssignment)
      .innerJoin(user, eq(user.id, careAssignment.staffId))
      .where(eq(careAssignment.clientId, actor.id)),
    bodyMeasurements: await db
      .select({
        measuredOn: bodyMeasurement.measuredOn,
        kind: bodyMeasurement.kind,
        value: bodyMeasurement.value,
        source: bodyMeasurement.source,
      })
      .from(bodyMeasurement)
      .where(and(eq(bodyMeasurement.userId, actor.id), isNull(bodyMeasurement.deletedAt)))
      .orderBy(asc(bodyMeasurement.measuredOn)),
    // From the copy kept in each row, so it survives the professional's account.
    accessLog: await db
      .select({
        at: auditLog.at,
        action: auditLog.action,
        resource: auditLog.resource,
        staff: { name: auditLog.actorName, email: auditLog.actorEmail },
      })
      .from(auditLog)
      .where(eq(auditLog.clientId, actor.id))
      .orderBy(desc(auditLog.at)),
  };
}
