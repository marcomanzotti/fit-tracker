import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const BASE_ENV = {
  BETTER_AUTH_SECRET: "test-secret-test-secret-test-secret-0",
  BETTER_AUTH_URL: "http://localhost:3000",
};

type RuntimeModule = typeof import("./runtime");

// Each test loads a fresh copy of the modules (and of the env cache) with its
// own DATABASE_URL; the singletons live on globalThis, so they are cleared too.
async function loadRuntime(databaseUrl: string): Promise<RuntimeModule> {
  vi.resetModules();
  vi.stubEnv("DATABASE_URL", databaseUrl);
  for (const [key, value] of Object.entries(BASE_ENV)) vi.stubEnv(key, value);
  return import("./runtime");
}

beforeEach(() => {
  delete (globalThis as { __fitTracker?: unknown }).__fitTracker;
});

afterEach(async () => {
  const store = (globalThis as { __fitTracker?: { database?: Promise<{ close(): Promise<void> }> } }).__fitTracker;
  await store?.database?.then((db) => db.close()).catch(() => undefined);
  vi.unstubAllEnvs();
});

describe("runtime", () => {
  it("opens one migrated database and reuses it", async () => {
    const runtime = await loadRuntime("pglite://memory");

    const [first, second] = await Promise.all([runtime.getDatabase(), runtime.getDatabase()]);
    const users = await first.db.query.user.findMany();

    expect(first).toBe(second);
    expect(users).toEqual([]);
  });

  it("builds auth on top of the shared database", async () => {
    const runtime = await loadRuntime("pglite://memory");

    const auth = await runtime.getAuth();

    expect(await runtime.getAuth()).toBe(auth);
  });

  it("does not cache a failed start, so the next request retries", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const runtime = await loadRuntime("postgres://nobody@127.0.0.1:1/none");

    const first = runtime.getDatabase();
    await expect(first).rejects.toThrow();
    const second = runtime.getDatabase();
    await expect(second).rejects.toThrow();

    expect(second).not.toBe(first);
  });
});
