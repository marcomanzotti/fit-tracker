import { z } from "zod";

const DEV_SECRET_PREFIX = "local-development";

const schema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    DATABASE_URL: z.string().min(1),
    BETTER_AUTH_SECRET: z.string().min(32, "must be at least 32 characters"),
    BETTER_AUTH_URL: z.url(),
    // Transactional mail provider (phase F6). Required in production so a deploy
    // without it fails at startup instead of leaving sign-ups unverifiable.
    SMTP_URL: z.url().optional(),
  })
  .superRefine((value, ctx) => {
    if (value.NODE_ENV !== "production") return;
    const issue = (path: string, message: string) => ctx.addIssue({ code: "custom", path: [path], message });
    if (!value.BETTER_AUTH_URL.startsWith("https://")) issue("BETTER_AUTH_URL", "must use https in production");
    if (value.DATABASE_URL.startsWith("pglite://")) issue("DATABASE_URL", "must be a real Postgres in production");
    if (value.BETTER_AUTH_SECRET.startsWith(DEV_SECRET_PREFIX)) issue("BETTER_AUTH_SECRET", "is the public development secret");
    if (!value.SMTP_URL) issue("SMTP_URL", "is required in production");
  });

export type Env = z.infer<typeof schema>;

let cached: Env | undefined;

// Read lazily so `next build` does not need production secrets; the first
// request fails fast with a clear message when a variable is missing.
export function env(): Env {
  if (cached) return cached;
  cached = parseEnv(process.env);
  return cached;
}

export function parseEnv(source: Record<string, string | undefined>): Env {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    throw new Error(`Invalid environment:\n${z.prettifyError(parsed.error)}`);
  }
  return parsed.data;
}
