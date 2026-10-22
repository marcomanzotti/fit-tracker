import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// connection() only marks the route as dynamic for Next; outside a request it is a no-op here.
vi.mock("next/server", () => ({ connection: async () => undefined }));

async function loadRoute(databaseUrl: string) {
  vi.resetModules();
  vi.stubEnv("DATABASE_URL", databaseUrl);
  vi.stubEnv("BETTER_AUTH_SECRET", "test-secret-test-secret-test-secret-0");
  vi.stubEnv("BETTER_AUTH_URL", "http://localhost:3000");
  return import("./route");
}

beforeEach(() => {
  delete (globalThis as { __fitTracker?: unknown }).__fitTracker;
});

afterEach(async () => {
  const store = (globalThis as { __fitTracker?: { database?: Promise<{ close(): Promise<void> }> } }).__fitTracker;
  await store?.database?.then((db) => db.close()).catch(() => undefined);
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe("GET /api/v1/health", () => {
  it("reports the database as up", async () => {
    const { GET } = await loadRoute("pglite://memory");

    const res = await GET();

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ success: true, data: { database: "up" }, error: null });
  });

  it("answers 503 with the error envelope when the database is unreachable", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const { GET } = await loadRoute("postgres://nobody@127.0.0.1:1/none");

    const res = await GET();

    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({
      success: false,
      data: null,
      error: { code: "database_unavailable", message: "Database not reachable" },
    });
  });
});
