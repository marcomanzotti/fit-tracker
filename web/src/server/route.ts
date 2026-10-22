import "server-only";
import { connection } from "next/server";
import type { Db } from "@/db/client";
import { requireActor, type Actor } from "./actor";
import type { Auth } from "./auth";
import { env } from "./env";
import { errorResponse, forbidden, HttpError } from "./http";
import { sendMail, type SendMail } from "./mail";
import { createRateLimiter } from "./rate-limit";
import { getAuth, getDatabase } from "./runtime";

const REQUESTS_PER_MINUTE = 300;
const allowRequest = createRateLimiter(REQUESTS_PER_MINUTE, 60_000);
const SAFE_METHODS = new Set(["GET", "HEAD"]);

// Cheap checks before any database work:
// - a per-IP request budget (X-Real-IP is set by Caddy; Better Auth limits /api/auth);
// - CSRF: a browser call authenticated by cookie must come from our own origin.
//   The Android app authenticates with a bearer header, which browsers never add
//   on their own, so those calls are exempt.
function guard(request: Request): void {
  if (!allowRequest(request.headers.get("x-real-ip") ?? "unknown")) {
    throw new HttpError(429, "rate_limited", "Too many requests, slow down");
  }
  if (SAFE_METHODS.has(request.method) || request.headers.has("authorization")) return;
  if (request.headers.get("origin") !== new URL(env().BETTER_AUTH_URL).origin) {
    throw forbidden("bad_origin", "Cross-site request refused");
  }
}

type RouteContext<P> = {
  request: Request;
  params: P;
  db: Db;
  auth: Auth;
  // Resolves and checks the session; routes that need a user call it first.
  actor: () => Promise<Actor>;
  // For services that email links (invitations).
  mail: { sendMail: SendMail; baseUrl: string };
};

// Every /api/v1 handler goes through here: shared database and auth, and one
// place that turns thrown errors into the response envelope. connection() first:
// with Cache Components a GET handler that has not read the request yet would be
// prerendered at build time, touching the database and caching personal data.
export function route<P = Record<string, never>>(handler: (ctx: RouteContext<P>) => Promise<Response>) {
  return async (request: Request, context: { params: Promise<P> }): Promise<Response> => {
    // Outside the try: during prerendering it rejects on purpose and Next must see it.
    await connection();
    try {
      guard(request);
      const [{ db }, auth] = await Promise.all([getDatabase(), getAuth()]);
      const params = await context.params;
      return await handler({
        request,
        params,
        db,
        auth,
        actor: () => requireActor(auth, request.headers),
        mail: { sendMail, baseUrl: env().BETTER_AUTH_URL },
      });
    } catch (error: unknown) {
      return errorResponse(error);
    }
  };
}
