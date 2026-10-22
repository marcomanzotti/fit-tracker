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
