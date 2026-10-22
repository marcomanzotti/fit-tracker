import { ok } from "@/server/http";
import { saveDraft } from "@/server/programs";
import { route } from "@/server/route";
import { idParam, readBody } from "@/server/validate";

// { draft, revision }: 409 edited_elsewhere when someone saved in between.
export const PUT = route<{ id: string }>(async ({ request, db, actor, params }) =>
  ok(await saveDraft(db, await actor(), idParam(params.id, "Program"), await readBody(request))),
);
