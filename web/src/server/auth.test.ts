import { randomUUID } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { createDatabase, type Database } from "@/db/client";
import { bodyMeasurement } from "@/db/schema";
import { createAuth, type Auth } from "./auth";
import type { Mail } from "./mail";

const BASE_URL = "http://localhost:3000";
const PASSWORD = "correct-horse-battery";

let database: Database;
let auth: Auth;
let outbox: Mail[];

function buildAuth(rateLimit: boolean): Auth {
  return createAuth({
    db: database.db,
    secret: "test-secret-test-secret-test-secret-0",
    baseURL: BASE_URL,
    rateLimit,
    sendMail: async (mail) => {
      outbox.push(mail);
    },
  });
}

beforeEach(async () => {
  database = createDatabase("pglite://memory");
  await database.migrate();
  outbox = [];
  auth = buildAuth(false);
});

afterEach(async () => {
  await database.close();
});

function post(path: string, body: unknown, headers: Record<string, string> = {}) {
  return auth.handler(
    new Request(`${BASE_URL}/api/auth${path}`, {
      method: "POST",
      headers: { "content-type": "application/json", origin: BASE_URL, ...headers },
      body: JSON.stringify(body),
    }),
  );
}

async function signUp(email: string, extra: Record<string, unknown> = {}) {
  return post("/sign-up/email", { email, password: PASSWORD, name: "Test", ...extra });
}

// Better Auth sends mails as a background task after responding, so poll briefly.
async function nextMail(): Promise<Mail> {
  for (let attempt = 0; attempt < 50 && outbox.length === 0; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  const mail = outbox.at(-1);
  if (!mail) throw new Error("no mail was sent");
  return mail;
}

async function verifyLastMail() {
  const link = (await nextMail()).text;
  const token = new URL(link).searchParams.get("token") ?? "";
  await auth.api.verifyEmail({ query: { token } });
}

describe("sign-up", () => {
  it("gives every new account the client role", async () => {
    const res = await signUp("client@example.test");

    expect(res.status).toBe(200);
    const { user } = await res.json();
    expect(user.role).toBe("client");
  });

  it("ignores a role sent by the caller", async () => {
    await signUp("sneaky@example.test", { role: "admin" });

    const stored = await database.db.query.user.findFirst({
      where: (u, { eq }) => eq(u.email, "sneaky@example.test"),
    });
    expect(stored?.role).toBe("client");
  });

  it("rejects passwords shorter than 10 characters", async () => {
    const res = await post("/sign-up/email", {
      email: "short@example.test",
      password: "short1",
      name: "Test",
    });

    expect(res.status).toBe(400);
  });

  it("sends a verification link instead of signing in", async () => {
    const res = await signUp("new@example.test");

    const body = await res.json();
    const mail = await nextMail();
    expect(body.token).toBeNull();
    expect(mail.to).toBe("new@example.test");
    expect(mail.text).toContain("/api/auth/verify-email?token=");
  });
});

describe("sign-in", () => {
  it("refuses an unverified email", async () => {
    await signUp("unverified@example.test");

    const res = await post("/sign-in/email", { email: "unverified@example.test", password: PASSWORD });

    expect(res.status).toBe(403);
  });

  it("returns a bearer token the mobile app can use for API calls", async () => {
    await signUp("mobile@example.test");
    await verifyLastMail();

    const res = await post("/sign-in/email", { email: "mobile@example.test", password: PASSWORD });
    const bearer = res.headers.get("set-auth-token");
    const session = await auth.api.getSession({
      headers: new Headers({ authorization: `Bearer ${bearer}` }),
    });

    expect(res.status).toBe(200);
    expect(bearer).toBeTruthy();
    expect(session?.user.email).toBe("mobile@example.test");
  });

  it("rejects the raw database session token as a bearer", async () => {
    await signUp("leak@example.test");
    await verifyLastMail();
    await post("/sign-in/email", { email: "leak@example.test", password: PASSWORD });

    const stored = await database.db.query.session.findFirst();
    const session = await auth.api.getSession({
      headers: new Headers({ authorization: `Bearer ${stored?.token}` }),
    });

    expect(stored?.token).toBeTruthy();
    expect(session).toBeNull();
  });
});

describe("account deletion", () => {
  it("removes the user and everything stored about them", async () => {
    await signUp("leaving@example.test");
    await verifyLastMail();
    const signIn = await post("/sign-in/email", { email: "leaving@example.test", password: PASSWORD });
    const bearer = signIn.headers.get("set-auth-token") ?? "";
    const { user } = await signIn.json();
    await database.db.insert(bodyMeasurement).values({
      id: randomUUID(),
      userId: user.id,
      measuredOn: "2026-10-01",
      kind: "weight",
      value: 80,
    });

    const res = await post("/delete-user", { password: PASSWORD }, { authorization: `Bearer ${bearer}` });

    expect(res.status).toBe(200);
    expect(await database.db.query.user.findMany()).toEqual([]);
    expect(await database.db.select().from(bodyMeasurement)).toEqual([]);
  });

  it("requires the password", async () => {
    await signUp("stay@example.test");
    await verifyLastMail();
    const signIn = await post("/sign-in/email", { email: "stay@example.test", password: PASSWORD });
    const bearer = signIn.headers.get("set-auth-token") ?? "";

    const res = await post("/delete-user", { password: "not-my-password" }, { authorization: `Bearer ${bearer}` });

    expect(res.status).toBe(400);
    expect(await database.db.query.user.findMany()).toHaveLength(1);
  });
});

describe("rate limiting", () => {
  it("blocks repeated sign-in attempts from the same client", async () => {
    auth = buildAuth(true);
    const attempt = () =>
      post(
        "/sign-in/email",
        { email: "nobody@example.test", password: "wrong-password-123" },
        { "x-real-ip": "203.0.113.7" },
      );

    const statuses: number[] = [];
    for (let i = 0; i < 5; i++) statuses.push((await attempt()).status);

    expect(statuses.slice(0, 3)).toEqual([401, 401, 401]);
    expect(statuses.at(-1)).toBe(429);
  });

  it("does not open a fresh bucket for a spoofed X-Forwarded-For", async () => {
    auth = buildAuth(true);
    const statuses: number[] = [];
    for (let i = 0; i < 5; i++) {
      const res = await post(
        "/sign-in/email",
        { email: "nobody@example.test", password: "wrong-password-123" },
        { "x-forwarded-for": `198.51.100.${i}` },
      );
      statuses.push(res.status);
    }

    expect(statuses.at(-1)).toBe(429);
  });
});
