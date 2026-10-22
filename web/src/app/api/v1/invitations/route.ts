import { createInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody } from "@/server/validate";

export const POST = route(async ({ request, db, actor, mail }) =>
  ok(await createInvitation(db, await actor(), await readBody(request), mail), { status: 201 }),
);
