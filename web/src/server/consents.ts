import { and, desc, eq, inArray, isNull } from "drizzle-orm";
import { z } from "zod";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Db } from "@/db/client";
import { careAssignment, consent, type ConsentPurpose } from "@/db/schema";
import type { Actor } from "./actor";
import { conflict } from "./http";
import { parseWith, type RequestMeta } from "./validate";

// Purposes the user switches on and off directly. staff_sharing follows each
// care assignment and research each study, so they are recorded elsewhere.
export const consentInput = z.object({
  purpose: z.enum(["health_processing", "aggregate_insights", "marketing"]),
  granted: z.boolean(),
  policyVersion: z.string().min(1),
});

// `outdated`: given on an older privacy notice. It still counts (the notice change
// may be minor) but the apps ask the user to review and confirm again.
export type ConsentState = Partial<
  Record<ConsentPurpose, { granted: boolean; policyVersion: string; outdated: boolean; at: Date }>
>;

export async function currentConsent(
  db: Db,
  userId: string,
  purpose: ConsentPurpose,
  refId: string | null = null,
): Promise<boolean> {
  const [row] = await db
    .select({ granted: consent.granted })
    .from(consent)
    .where(
      and(
        eq(consent.userId, userId),
        eq(consent.purpose, purpose),
        refId ? eq(consent.refId, refId) : isNull(consent.refId),
      ),
    )
    .orderBy(desc(consent.seq))
    .limit(1);
  return row?.granted === true;
}

export async function recordConsent(
  db: Db,
  userId: string,
  entry: { purpose: ConsentPurpose; granted: boolean; refId?: string; scopes?: string[] },
  meta: RequestMeta,
): Promise<void> {
  await db.insert(consent).values({
    userId,
    purpose: entry.purpose,
    granted: entry.granted,
    refId: entry.refId ?? null,
    scopes: entry.scopes ?? null,
    policyVersion: PRIVACY_POLICY_VERSION,
    ipAddress: meta.ipAddress,
    userAgent: meta.userAgent,
  });
}

// The UI sends the policy version it showed; granting on a stale text is refused.
export function assertCurrentPolicy(policyVersion: string): void {
  if (policyVersion !== PRIVACY_POLICY_VERSION) {
    throw conflict("policy_outdated", "The privacy notice changed: reload and review it");
  }
}

export async function setConsent(db: Db, actor: Actor, raw: unknown, meta: RequestMeta): Promise<ConsentState> {
  const input = parseWith(consentInput, raw);
  if (input.granted) assertCurrentPolicy(input.policyVersion);
  await db.transaction(async (tx) => {
    await recordConsent(tx, actor.id, input, meta);
    // Without consent to process health data no professional may keep reading it.
    if (input.purpose === "health_processing" && !input.granted) {
      await endAllCare(tx, actor, meta);
    }
  });
  return consentState(db, actor.id);
}

async function endAllCare(db: Db, actor: Actor, meta: RequestMeta): Promise<void> {
  const ended = await db
    .update(careAssignment)
    .set({ status: "ended", endedAt: new Date(), endedBy: actor.id })
    .where(and(eq(careAssignment.clientId, actor.id), inArray(careAssignment.status, ["pending", "active"])))
    .returning({ id: careAssignment.id });
  for (const { id } of ended) {
    await recordConsent(db, actor.id, { purpose: "staff_sharing", granted: false, refId: id }, meta);
  }
}

export async function consentState(db: Db, userId: string): Promise<ConsentState> {
  const rows = await db
    .selectDistinctOn([consent.purpose], {
      purpose: consent.purpose,
      granted: consent.granted,
      policyVersion: consent.policyVersion,
      at: consent.createdAt,
    })
    .from(consent)
    .where(and(eq(consent.userId, userId), isNull(consent.refId)))
    .orderBy(consent.purpose, desc(consent.seq));
  return Object.fromEntries(
    rows.map((row) => [
      row.purpose,
      {
        granted: row.granted,
        policyVersion: row.policyVersion,
        outdated: row.policyVersion !== PRIVACY_POLICY_VERSION,
        at: row.at,
      },
    ]),
  );
}
