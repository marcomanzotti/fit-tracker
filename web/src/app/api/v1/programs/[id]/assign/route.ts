import { ok } from "@/server/http";
import { assignTemplate } from "@/server/programs";
import { route } from "@/server/route";
import { idParam, readBody } from "@/server/validate";

// { clientIds }: a draft copy of the template for each client.
export const POST = route<{ id: string }>(async ({ request, db, actor, params }) =>
  ok(await assignTemplate(db, await actor(), idParam(params.id, "Template"), await readBody(request)), { status: 201 }),
);
