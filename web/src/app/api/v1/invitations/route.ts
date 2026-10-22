import { createInvitation, listInvitations } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody } from "@/server/validate";

// Pending invitations sent by the caller (all of them for an admin).
export const GET = route(async ({ db, actor }) => ok(await listInvitations(db, await actor())));

export const POST = route(async ({ request, db, actor, mail }) =>
  ok(await createInvitation(db, await actor(), await readBody(request), mail), { status: 201 }),
);
