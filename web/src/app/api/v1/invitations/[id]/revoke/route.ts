import { revokeInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { idParam } from "@/server/validate";

export const POST = route<{ id: string }>(async ({ db, actor, params }) =>
  ok(await revokeInvitation(db, await actor(), idParam(params.id, "Invitation"))),
);
