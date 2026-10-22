import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { nextCookies } from "better-auth/next-js";
import { bearer, twoFactor } from "better-auth/plugins";
import { APP } from "@/config";
import type { Db } from "@/db/client";
import * as schema from "@/db/schema";
import type { SendMail } from "./mail";

const MIN_PASSWORD_LENGTH = 10;

type AuthOptions = {
  db: Db;
  secret: string;
  baseURL: string;
  sendMail: SendMail;
  // Better Auth keeps rate-limit counters in one process-wide map, so tests that
  // create many accounts turn it off; it is always on in the running app.
  rateLimit?: boolean;
};

export function createAuth({ db, secret, baseURL, sendMail, rateLimit = true }: AuthOptions) {
  return betterAuth({
    appName: APP.name,
    secret,
    baseURL,
    database: drizzleAdapter(db, { provider: "pg", schema }),
    advanced: {
      database: { generateId: "uuid" },
      // In production Caddy sets X-Real-IP to the connecting address (overwriting
      // any client value) and the app port is never published, so this header is
      // the only trusted source of the client IP for rate limiting.
      ipAddress: { ipAddressHeaders: ["x-real-ip"] },
    },
    rateLimit: { enabled: rateLimit },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      minPasswordLength: MIN_PASSWORD_LENGTH,
      revokeSessionsOnPasswordReset: true,
      sendResetPassword: ({ user, url }) =>
        sendMail({ to: user.email, subject: `${APP.name}: reimposta la password`, text: url }),
    },
    emailVerification: {
      sendOnSignUp: true,
      // false: a verification link opened by someone else must not sign them in
      // to the sender's account (login CSRF).
      autoSignInAfterVerification: false,
      sendVerificationEmail: ({ user, url }) =>
        sendMail({ to: user.email, subject: `${APP.name}: conferma la tua email`, text: url }),
    },
    user: {
      additionalFields: {
        // input: false = never accepted from sign-up or profile updates; only the
        // server (staff invitations, phase F1) assigns staff and admin roles.
        role: { type: "string", required: true, defaultValue: "client", input: false },
      },
    },
    plugins: [
      twoFactor({ issuer: APP.name }),
      // Only signed tokens (the `set-auth-token` value) are accepted, so a leaked
      // session table cannot be replayed as bearer tokens.
      bearer({ requireSignature: true }),
      nextCookies(),
    ],
  });
}

export type Auth = ReturnType<typeof createAuth>;
