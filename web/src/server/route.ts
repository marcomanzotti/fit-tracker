import "server-only";
import { connection } from "next/server";
import type { Db } from "@/db/client";
import { requireActor, type Actor } from "./actor";
import type { Auth } from "./auth";
import { env } from "./env";
import { errorResponse } from "./http";
import { sendMail, type SendMail } from "./mail";
import { getAuth, getDatabase } from "./runtime";

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
