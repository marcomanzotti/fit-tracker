import { ok } from "@/server/http";
import { createProgram, listPrograms } from "@/server/programs";
import { route } from "@/server/route";
import { readBody, readQuery } from "@/server/validate";

// ?clientId=<uuid> lists that client's programs; without it, the templates.
export const GET = route(async ({ request, db, actor }) => ok(await listPrograms(db, await actor(), readQuery(request))));

export const POST = route(async ({ request, db, actor }) =>
  ok(await createProgram(db, await actor(), await readBody(request)), { status: 201 }),
);
