import { describe, expect, it } from "vitest";
import { parseEnv } from "./env";

const PRODUCTION = {
  NODE_ENV: "production",
  DATABASE_URL: "postgres://fit:secret@db:5432/fit",
  BETTER_AUTH_SECRET: "a".repeat(48),
  BETTER_AUTH_URL: "https://studio.example",
  SMTP_URL: "smtp://user:pass@smtp.example:587",
};

describe("parseEnv", () => {
  it("accepts a complete production environment", () => {
    expect(parseEnv(PRODUCTION).BETTER_AUTH_URL).toBe("https://studio.example");
  });

  it.each([
    ["BETTER_AUTH_URL", "http://studio.example", /https/],
    ["DATABASE_URL", "pglite://.data/prod", /real Postgres/],
    ["BETTER_AUTH_SECRET", "local-development-only-secret-not-used-in-prod", /development secret/],
    ["SMTP_URL", undefined, /SMTP_URL/],
  ])("rejects %s=%s in production", (key, value, message) => {
    expect(() => parseEnv({ ...PRODUCTION, [key]: value })).toThrow(message);
  });

  it("allows the embedded database and plain http in development", () => {
    const dev = parseEnv({
      ...PRODUCTION,
      NODE_ENV: "development",
      DATABASE_URL: "pglite://.data/dev",
      BETTER_AUTH_URL: "http://localhost:3000",
      SMTP_URL: undefined,
    });

    expect(dev.DATABASE_URL).toBe("pglite://.data/dev");
  });

  it("rejects a short secret", () => {
    expect(() => parseEnv({ ...PRODUCTION, BETTER_AUTH_SECRET: "short" })).toThrow(/32 characters/);
  });
});
