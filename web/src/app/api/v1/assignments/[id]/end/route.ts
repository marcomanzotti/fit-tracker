import { endAssignment } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { idParam, requestMeta } from "@/server/validate";

export const POST = route<{ id: string }>(async ({ request, db, actor, params }) =>
  ok(await endAssignment(db, await actor(), idParam(params.id, "Assignment"), requestMeta(request.headers))),
);
