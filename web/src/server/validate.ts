import { z } from "zod";
import { badRequest, HttpError, notFound } from "./http";

// Far above any legitimate request (a 500-mutation sync batch is ~100 KB).
const MAX_BODY_BYTES = 1_000_000;

export function parseWith<T>(schema: z.ZodType<T>, input: unknown): T {
  const parsed = schema.safeParse(input);
  if (!parsed.success) throw badRequest("validation_failed", z.prettifyError(parsed.error));
  return parsed.data;
}

// The JSON body as untrusted data; the service it goes to validates it.
export async function readBody(request: Request): Promise<unknown> {
  if (!(request.headers.get("content-type") ?? "").startsWith("application/json")) {
    throw new HttpError(415, "unsupported_media_type", "Send the body as application/json");
  }
  const tooLarge = () => new HttpError(413, "body_too_large", "Request body is too large");
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY_BYTES) throw tooLarge();
  const text = await request.text();
  if (Buffer.byteLength(text) > MAX_BODY_BYTES) throw tooLarge();
  try {
    return JSON.parse(text) as unknown;
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
