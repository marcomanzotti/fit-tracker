import { respondToAssignment } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { idParam, readBody, requestMeta } from "@/server/validate";

// The client accepts or declines a professional proposed by the admin.
export const POST = route<{ id: string }>(async ({ request, db, actor, params }) =>
  ok(
    await respondToAssignment(
      db,
      await actor(),
      idParam(params.id, "Assignment"),
      await readBody(request),
      requestMeta(request.headers),
    ),
  ),
);
