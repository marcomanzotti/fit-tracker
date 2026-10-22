import { and, eq, sql } from "drizzle-orm";
import type { Db } from "@/db/client";
import { auditLog, careAssignment, user, type AuditAction, type Scope } from "@/db/schema";
import { isStaffRole, type Actor } from "./actor";
import { currentConsent } from "./consents";
import { forbidden, HttpError } from "./http";

export type AccessRequest = {
  scope: Scope;
  // What is touched, for the access log (e.g. "body_measurement").
  resource: string;
  resourceId?: string;
  action?: "read" | "write";
  ipAddress?: string | null;
};

// The only way staff code reaches a client's data (ADR-0005). A client always
// reaches their own data. A professional needs an active assignment that covers
// the scope and the client's consent to health processing; the access is logged
// in the same transaction as the work, so nothing is read without a log entry.
// Refused attempts are logged too (outside the rolled-back transaction), so
// probing clients one does not follow leaves a trace. Admins are treated like
// staff: being admin alone gives no access to health data.
export async function withClientAccess<T>(
  db: Db,
  actor: Actor,
  clientId: string,
  request: AccessRequest,
  work: (db: Db) => Promise<T>,
): Promise<T> {
  if (actor.id === clientId) return work(db);
  try {
    if (!isStaffRole(actor.role)) throw forbidden();
    return await db.transaction(async (tx) => {
      await assertAccess(tx, actor, clientId, request.scope);
      await tx.insert(auditLog).values(auditRow(actor, clientId, request, request.action ?? "read"));
      return work(tx);
    });
  } catch (error: unknown) {
    if (error instanceof HttpError && error.status === 403) {
      await logDenied(db, actor, clientId, request);
    }
    throw error;
  }
}

async function assertAccess(tx: Db, actor: Actor, clientId: string, scope: Scope): Promise<void> {
  const [assignment] = await tx
    .select({ id: careAssignment.id })
    .from(careAssignment)
    .where(
      and(
        eq(careAssignment.clientId, clientId),
        eq(careAssignment.staffId, actor.id),
        eq(careAssignment.status, "active"),
        sql`${scope} = any(${careAssignment.scopes})`,
      ),
    )
    .limit(1);
  if (!assignment) throw forbidden("no_access", "You do not follow this client for this data");
  if (!(await currentConsent(tx, clientId, "health_processing"))) {
    throw forbidden("consent_missing", "The client has not consented to health data processing");
  }
}

function auditRow(actor: Actor, clientId: string | null, request: AccessRequest, action: AuditAction) {
  return {
    actorId: actor.id,
    actorName: actor.name,
    actorEmail: actor.email,
    clientId,
    action,
    resource: request.resource,
    resourceId: request.resourceId ?? null,
    ipAddress: request.ipAddress ?? null,
  };
}

async function logDenied(db: Db, actor: Actor, clientId: string, request: AccessRequest): Promise<void> {
  // The target may not exist (a guessed id); keep the attempt, without the link.
  const [target] = await db.select({ id: user.id }).from(user).where(eq(user.id, clientId));
  await db.insert(auditLog).values(auditRow(actor, target ? clientId : null, request, "denied"));
}
