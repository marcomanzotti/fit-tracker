import { acceptInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody, requestMeta } from "@/server/validate";

// { token, consent? }: joins the studio as staff or as a followed client.
export const POST = route(async ({ request, db, actor }) =>
  ok(await acceptInvitation(db, await actor(), await readBody(request), requestMeta(request.headers))),
);
