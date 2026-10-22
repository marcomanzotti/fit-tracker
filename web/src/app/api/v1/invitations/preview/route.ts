import { previewInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody } from "@/server/validate";

// Public: { token } -> who invited whom, shown before sign-in. The token comes in
// the body, never in a URL, so it does not end up in access logs.
export const POST = route(async ({ request, db }) => ok(await previewInvitation(db, await readBody(request))));
