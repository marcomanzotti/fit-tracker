import { and, eq, sql } from "drizzle-orm";
import type { Db } from "@/db/client";
import { auditLog, careAssignment, type Scope } from "@/db/schema";
import { isStaffRole, type Actor } from "./actor";
import { currentConsent } from "./consents";
import { forbidden } from "./http";

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
// Admins are treated like staff: being admin alone gives no access to health data.
export async function withClientAccess<T>(
  db: Db,
  actor: Actor,
  clientId: string,
  request: AccessRequest,
  work: (db: Db) => Promise<T>,
): Promise<T> {
  if (actor.id === clientId) return work(db);
  if (!isStaffRole(actor.role)) throw forbidden();

  return db.transaction(async (tx) => {
    const [assignment] = await tx
      .select({ id: careAssignment.id })
      .from(careAssignment)
      .where(
        and(
          eq(careAssignment.clientId, clientId),
          eq(careAssignment.staffId, actor.id),
          eq(careAssignment.status, "active"),
          sql`${request.scope} = any(${careAssignment.scopes})`,
        ),
      )
      .limit(1);
    if (!assignment) throw forbidden("no_access", "You do not follow this client for this data");
    if (!(await currentConsent(tx, clientId, "health_processing"))) {
      throw forbidden("consent_missing", "The client has not consented to health data processing");
    }

    await tx.insert(auditLog).values({
      actorId: actor.id,
      clientId,
      action: request.action ?? "read",
      resource: request.resource,
      resourceId: request.resourceId ?? null,
      ipAddress: request.ipAddress ?? null,
    });
    return work(tx);
  });
}
