import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { eq } from "drizzle-orm";
import { PRIVACY_POLICY_VERSION } from "@/config";
import { user } from "@/db/schema";

// The F1 acceptance flow over HTTP, through the real route handlers and real
// Better Auth sessions (bearer tokens, as the Android app will use them):
// admin -> invites a PT -> PT (with 2FA) invites a client -> client consents and
// syncs a weigh-in -> PT reads it -> the access shows up in the client's export.

// connection() only marks routes dynamic for Next; outside a Next request it throws.
vi.mock("next/server", async (importOriginal) => ({
  ...(await importOriginal<typeof import("next/server")>()),
  connection: async () => undefined,
}));

const BASE = "http://localhost:3000";
const PASSWORD = "correct-horse-battery";
const mails: string[] = [];

type Handler<P = Record<string, string>> = (request: Request, context: { params: Promise<P> }) => Promise<Response>;
type Call<P> = {
  method?: string;
  body?: unknown;
  bearer?: string;
  ip?: string;
  params?: P;
  origin?: string;
  contentType?: string;
};

let routes: Awaited<ReturnType<typeof loadRoutes>>;

async function loadRoutes() {
  vi.resetModules();
  vi.stubEnv("DATABASE_URL", "pglite://memory");
  vi.stubEnv("BETTER_AUTH_SECRET", "test-secret-test-secret-test-secret-0");
  vi.stubEnv("BETTER_AUTH_URL", BASE);
  return {
    auth: (await import("../auth/[...all]/route")) as unknown as Record<string, Handler>,
    me: await import("./me/route"),
    invitations: await import("./invitations/route"),
    preview: await import("./invitations/preview/route"),
    accept: await import("./invitations/accept/route"),
    revoke: await import("./invitations/[id]/revoke/route"),
    care: await import("./care/route"),
    push: await import("./sync/push/route"),
    body: await import("./clients/[clientId]/body-measurements/route"),
    exportData: await import("./me/export/route"),
    exercises: await import("./exercises/route"),
    runtime: await import("@/server/runtime"),
  };
}

async function call<P>(handler: Handler<P>, path: string, options: Call<P> = {}) {
  const headers: Record<string, string> = { origin: options.origin ?? BASE, "x-real-ip": options.ip ?? "198.51.100.1" };
  if (options.body !== undefined) headers["content-type"] = options.contentType ?? "application/json";
  if (options.bearer) headers.authorization = `Bearer ${options.bearer}`;
  const response = await handler(
    new Request(`${BASE}${path}`, {
      method: options.method ?? (options.body === undefined ? "GET" : "POST"),
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    }),
    { params: Promise.resolve(options.params ?? ({} as P)) },
  );
  return { status: response.status, json: await response.json(), headers: response.headers };
}

async function waitForMail(count: number) {
  for (let i = 0; i < 100 && mails.length < count; i++) await new Promise((r) => setTimeout(r, 10));
  return mails.at(-1) ?? "";
}

// Sign-up, email verification and sign-in, each user from its own IP.
async function register(email: string, name: string, ip: string) {
  await call(routes.auth.POST as Handler, "/api/auth/sign-up/email", { body: { email, password: PASSWORD, name }, ip });
  const link = await waitForMail(mails.length + 1);
  const token = new URL(link.match(/https?:\/\/\S+/)?.[0] ?? BASE).searchParams.get("token");
  await call(routes.auth.GET as Handler, `/api/auth/verify-email?token=${token}`, { ip });
  const signIn = await call(routes.auth.POST as Handler, "/api/auth/sign-in/email", { body: { email, password: PASSWORD }, ip });
  return { bearer: signIn.headers.get("set-auth-token") ?? "", id: signIn.json.user.id as string };
}

async function setUser(id: string, values: { role?: "admin"; twoFactorEnabled?: boolean }) {
  const { db } = await routes.runtime.getDatabase();
  await db.update(user).set(values).where(eq(user.id, id));
}

const invitationToken = () => mails.at(-1)?.split("/invito#")[1]?.trim() ?? "";

beforeAll(async () => {
  delete (globalThis as { __fitTracker?: unknown }).__fitTracker;
  vi.spyOn(console, "info").mockImplementation((message: string) => {
    mails.push(message);
  });
  routes = await loadRoutes();
});

afterAll(async () => {
  const { close } = await routes.runtime.getDatabase();
  await close();
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe("studio onboarding and staff access over HTTP", () => {
  const state = { admin: "", pt: "", ptId: "", client: "", clientId: "" };

  it("lets the admin invite a professional", async () => {
    const admin = await register("admin@example.test", "Admin", "198.51.100.10");
    await setUser(admin.id, { role: "admin", twoFactorEnabled: true });
    state.admin = admin.bearer;

    const res = await call(routes.invitations.POST, "/api/v1/invitations", {
      bearer: state.admin,
      body: { kind: "staff", email: "pt@example.test", disciplines: ["pt"] },
    });

    expect(res.status).toBe(201);
    expect(res.json.success).toBe(true);
  });

  it("makes the professional staff on acceptance and requires 2FA before staff work", async () => {
    const token = invitationToken();
    const pt = await register("pt@example.test", "Paola PT", "198.51.100.11");
    Object.assign(state, { pt: pt.bearer, ptId: pt.id });

    const accepted = await call(routes.accept.POST, "/api/v1/invitations/accept", { bearer: pt.bearer, body: { token } });
    const without2fa = await call(routes.invitations.POST, "/api/v1/invitations", {
      bearer: pt.bearer,
      body: { kind: "client", email: "luca@example.test", assignmentRole: "pt" },
    });

    expect(accepted.status).toBe(200);
    expect(without2fa.status).toBe(403);
    expect(without2fa.json.error.code).toBe("two_factor_required");
  });

  it("lets the professional invite a client, who joins with consent", async () => {
    await setUser(state.ptId, { twoFactorEnabled: true });
    await call(routes.invitations.POST, "/api/v1/invitations", {
      bearer: state.pt,
      body: { kind: "client", email: "luca@example.test", assignmentRole: "pt" },
    });
    const token = invitationToken();
    const preview = await call(routes.preview.POST, "/api/v1/invitations/preview", { body: { token } });
    const client = await register("luca@example.test", "Luca", "198.51.100.12");
    Object.assign(state, { client: client.bearer, clientId: client.id });

    const accepted = await call(routes.accept.POST, "/api/v1/invitations/accept", {
      bearer: client.bearer,
      body: { token, consent: { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true, staffSharing: true } },
    });
    const care = await call(routes.care.GET, "/api/v1/care", { bearer: client.bearer });

    expect(preview.json.data).toMatchObject({ inviterName: "Paola PT", status: "valid" });
    expect(accepted.json.data.assignmentId).toEqual(expect.any(String));
    expect(care.json.data[0]).toMatchObject({ role: "pt", status: "active", person: { name: "Paola PT" } });
  });

  it("syncs the client's weigh-in and shows it to the professional", async () => {
    const pushed = await call(routes.push.POST, "/api/v1/sync/push", {
      bearer: state.client,
      body: {
        mutations: [
          { entity: "body_measurement", op: "upsert", id: randomUUID(), data: { measuredOn: "2026-10-21", kind: "weight", value: 82 } },
        ],
      },
    });
    const read = await call(routes.body.GET, `/api/v1/clients/${state.clientId}/body-measurements`, {
      bearer: state.pt,
      params: { clientId: state.clientId },
    });

    expect(pushed.json.data.results[0].status).toBe("ok");
    expect(read.status).toBe(200);
    expect(read.json.data).toEqual([expect.objectContaining({ kind: "weight", value: 82, measuredOn: "2026-10-21" })]);
  });

  it("lists the professional's access in the client's data export", async () => {
    const exported = await call(routes.exportData.GET, "/api/v1/me/export", { bearer: state.client });

    expect(exported.headers.get("content-disposition")).toMatch(/attachment; filename="fittracker-export-/);
    expect(exported.json.data.accessLog).toEqual([
      expect.objectContaining({ resource: "body_measurement", staff: { name: "Paola PT", email: "pt@example.test" } }),
    ]);
  });

  it("keeps the admin and other people out of the client's health data", async () => {
    const asAdmin = await call(routes.body.GET, `/api/v1/clients/${state.clientId}/body-measurements`, {
      bearer: state.admin,
      params: { clientId: state.clientId },
    });
    const asClient = await call(routes.body.GET, `/api/v1/clients/${state.ptId}/body-measurements`, {
      bearer: state.client,
      params: { clientId: state.ptId },
    });

    expect(asAdmin.status).toBe(403);
    expect(asClient.status).toBe(403);
  });

  it("answers with the error envelope for anonymous calls and malformed ids", async () => {
    const anonymous = await call(routes.me.GET, "/api/v1/me");
    const badId = await call(routes.body.GET, "/api/v1/clients/not-a-uuid/body-measurements", {
      bearer: state.pt,
      params: { clientId: "not-a-uuid" },
    });

    expect(anonymous).toMatchObject({ status: 401, json: { success: false, error: { code: "unauthorized" } } });
    expect(badId).toMatchObject({ status: 404, json: { error: { code: "not_found" } } });
  });

  it("lets the inviter list and revoke a pending invitation", async () => {
    await call(routes.invitations.POST, "/api/v1/invitations", {
      bearer: state.pt,
      body: { kind: "client", email: "typo@example.test", assignmentRole: "pt" },
    });
    const token = invitationToken();
    const pending = await call(routes.invitations.GET, "/api/v1/invitations", { bearer: state.pt });
    const id = pending.json.data.find((i: { email: string }) => i.email === "typo@example.test").id;

    const revoked = await call(routes.revoke.POST, `/api/v1/invitations/${id}/revoke`, { bearer: state.pt, params: { id } });
    const preview = await call(routes.preview.POST, "/api/v1/invitations/preview", { body: { token } });

    expect(revoked.status).toBe(200);
    expect(preview.json.data.status).toBe("revoked");
  });

  it("refuses cookie-style calls from another site and non-JSON bodies", async () => {
    const crossSite = await call(routes.preview.POST, "/api/v1/invitations/preview", {
      body: { token: "x".repeat(40) },
      origin: "https://evil.example",
    });
    const notJson = await call(routes.push.POST, "/api/v1/sync/push", {
      bearer: state.client,
      body: { mutations: [] },
      contentType: "text/plain",
    });

    expect(crossSite).toMatchObject({ status: 403, json: { error: { code: "bad_origin" } } });
    expect(notJson.status).toBe(415);
  });

  it("searches the exercise library for signed-in users", async () => {
    const res = await call(routes.exercises.GET, "/api/v1/exercises?q=stacco%20rumeno", { bearer: state.client });

    expect(res.json.data[0].nameIt).toBe("Stacco rumeno");
  });
});
