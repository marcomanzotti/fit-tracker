// One response envelope for every /api/v1 endpoint, so the web client and the
// Android app parse success and failure the same way.
export type ApiError = { code: string; message: string };
export type ApiResponse<T> =
  | { success: true; data: T; error: null }
  | { success: false; data: null; error: ApiError };

export function ok<T>(data: T, init?: ResponseInit): Response {
  const body: ApiResponse<T> = { success: true, data, error: null };
  return Response.json(body, init);
}

export function fail(status: number, code: string, message: string): Response {
  const body: ApiResponse<never> = { success: false, data: null, error: { code, message } };
  return Response.json(body, { status });
}

// Thrown anywhere in a request; the route wrapper turns it into `fail(...)`.
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export const unauthorized = () => new HttpError(401, "unauthorized", "Sign in required");
export const forbidden = (code = "forbidden", message = "Not allowed") => new HttpError(403, code, message);
export const notFound = (what = "Resource") => new HttpError(404, "not_found", `${what} not found`);
export const conflict = (code: string, message: string) => new HttpError(409, code, message);
export const badRequest = (code: string, message: string) => new HttpError(400, code, message);

// Postgres SQLSTATE of a driver error; Drizzle wraps it in `cause`.
export function pgErrorCode(error: unknown): string | undefined {
  for (let current: unknown = error; current instanceof Error; current = current.cause) {
    const code = (current as { code?: unknown }).code;
    if (typeof code === "string" && /^[0-9A-Z]{5}$/.test(code)) return code;
  }
  return undefined;
}

// Class 22 (bad data) and 23 (constraint violation): the request, not the server.
export const isDataError = (code: string) => code.startsWith("22") || code.startsWith("23");

const UNIQUE_VIOLATION = "23505";
const LOCK_NOT_AVAILABLE = "55P03";

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) return fail(error.status, error.code, error.message);
  const code = pgErrorCode(error);
  // Two requests racing to create the same thing: the loser gets a clean 409.
  if (code === UNIQUE_VIOLATION) return fail(409, "conflict", "This already exists");
  if (code === LOCK_NOT_AVAILABLE) return fail(503, "busy", "Busy, try again in a moment");
  // Log the SQLSTATE and message only: Drizzle errors carry the query parameters,
  // which can be health data.
  console.error("unhandled API error", code ?? "", error instanceof Error ? error.message.split("\nparams:")[0] : error);
  return fail(500, "internal_error", "Something went wrong");
}
