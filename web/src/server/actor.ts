import { ROLES, type Role } from "@/db/schema";
import type { Auth } from "./auth";
import { forbidden, unauthorized } from "./http";

// Who is making the request, as the services see it.
export type Actor = {
  id: string;
  email: string;
  name: string;
  role: Role;
  twoFactorEnabled: boolean;
};

export const isStaffRole = (role: Role) => role === "staff" || role === "admin";

// Resolves the session (cookie on the web, bearer token on Android). Staff and
// admins reach client health data, so they must have 2FA on for any /api/v1 call;
// enabling it happens through the Better Auth endpoints under /api/auth.
export async function requireActor(auth: Auth, headers: Headers): Promise<Actor> {
  const session = await auth.api.getSession({ headers });
  if (!session) throw unauthorized();
  const { id, email, name, role, twoFactorEnabled } = session.user;
  if (!ROLES.includes(role as Role)) throw forbidden();
  const actor: Actor = { id, email, name, role: role as Role, twoFactorEnabled: twoFactorEnabled === true };
  if (isStaffRole(actor.role) && !actor.twoFactorEnabled) {
    throw forbidden("two_factor_required", "Enable two-factor authentication to use staff features");
  }
  return actor;
}

export function requireRole(actor: Actor, ...roles: Role[]): void {
  if (!roles.includes(actor.role)) throw forbidden();
}
