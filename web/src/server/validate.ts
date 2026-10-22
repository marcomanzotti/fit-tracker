import { z } from "zod";
import { badRequest, notFound } from "./http";

export function parseWith<T>(schema: z.ZodType<T>, input: unknown): T {
  const parsed = schema.safeParse(input);
  if (!parsed.success) throw badRequest("validation_failed", z.prettifyError(parsed.error));
  return parsed.data;
}

// The JSON body as untrusted data; the service it goes to validates it.
export async function readBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw badRequest("invalid_json", "Request body is not valid JSON");
  }
}

export function readQuery(request: Request): Record<string, string> {
  return Object.fromEntries(new URL(request.url).searchParams);
}

// Ids in the URL: anything that is not a UUID cannot exist, so it is a 404
// rather than a database error.
export function idParam(value: string, what = "Resource"): string {
  if (!z.uuid().safeParse(value).success) throw notFound(what);
  return value;
}

// Request metadata kept as evidence for consents and in the access log.
export type RequestMeta = { ipAddress: string | null; userAgent: string | null };

export function requestMeta(headers: Headers): RequestMeta {
  return { ipAddress: headers.get("x-real-ip"), userAgent: headers.get("user-agent") };
}
