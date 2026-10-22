import { acceptInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody, requestMeta } from "@/server/validate";

export const POST = route<{ token: string }>(async ({ request, db, actor, params }) =>
  ok(await acceptInvitation(db, await actor(), params.token, await readBody(request), requestMeta(request.headers))),
);
