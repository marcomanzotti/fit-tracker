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

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) return fail(error.status, error.code, error.message);
  console.error("unhandled API error", error);
  return fail(500, "internal_error", "Something went wrong");
}
