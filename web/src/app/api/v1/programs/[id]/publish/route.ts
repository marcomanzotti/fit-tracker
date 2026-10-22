import { ok } from "@/server/http";
import { publishProgram } from "@/server/programs";
import { route } from "@/server/route";
import { idParam, readBody } from "@/server/validate";

// { changeNote?, startDate? }: the client sees this version from now on.
export const POST = route<{ id: string }>(async ({ request, db, actor, params }) =>
  ok(await publishProgram(db, await actor(), idParam(params.id, "Program"), await readBody(request)), { status: 201 }),
);
