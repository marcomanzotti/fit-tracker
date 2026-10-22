import { ok } from "@/server/http";
import { archiveProgram } from "@/server/programs";
import { route } from "@/server/route";
import { idParam } from "@/server/validate";

export const POST = route<{ id: string }>(async ({ db, actor, params }) =>
  ok(await archiveProgram(db, await actor(), idParam(params.id, "Program"))),
);
