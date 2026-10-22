import "server-only";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import type { Db } from "@/db/client";
import type { Role } from "@/db/schema";
import { isStaffRole, requireActor, type Actor } from "./actor";
import { HttpError } from "./http";
import { getAuth, getDatabase } from "./runtime";

// Session handling for server-rendered pages: who is here, or where to send them.
// Pages call services directly with the actor (same rules as the API).

export const homeFor = (role: Role) => (isStaffRole(role) ? "/studio" : "/app");

// The signed-in user even without 2FA (the security page needs it to enable 2FA).
// Request headers are read first in both helpers: that marks the page as
// per-request, so Next never prerenders it (and never opens the database) at build.
export async function sessionUser() {
  const requestHeaders = await headers();
  const auth = await getAuth();
  const session = await auth.api.getSession({ headers: requestHeaders });
  return session?.user ?? null;
}

export async function requirePage(...roles: Role[]): Promise<{ actor: Actor; db: Db }> {
  const requestHeaders = await headers();
  const [{ db }, auth] = await Promise.all([getDatabase(), getAuth()]);
  let actor: Actor;
  try {
    actor = await requireActor(auth, requestHeaders);
  } catch (error: unknown) {
    if (error instanceof HttpError && error.code === "two_factor_required") redirect("/studio/sicurezza");
    redirect("/accedi");
  }
  if (roles.length > 0 && !roles.includes(actor.role)) redirect(homeFor(actor.role));
  return { actor, db };
}
