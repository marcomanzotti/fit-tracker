import { ok } from "@/server/http";
import { route } from "@/server/route";
import { push } from "@/server/sync";
import { readBody } from "@/server/validate";

// { mutations: [{ entity, op, id, data }] }; answers one status per mutation.
export const POST = route(async ({ request, db, actor }) =>
  ok({ results: await push(db, await actor(), await readBody(request)) }),
);
