import { ok } from "@/server/http";
import { getProgram } from "@/server/programs";
import { route } from "@/server/route";
import { idParam } from "@/server/validate";

// Draft, revision and version history, for the editor.
export const GET = route<{ id: string }>(async ({ db, actor, params }) =>
  ok(await getProgram(db, await actor(), idParam(params.id, "Program"))),
);
