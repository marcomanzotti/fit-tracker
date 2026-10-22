import { ok } from "@/server/http";
import { route } from "@/server/route";
import { pull } from "@/server/sync";
import { readQuery } from "@/server/validate";

// ?cursor=<last rev seen>&limit=500 (ADR-0002).
export const GET = route(async ({ request, db, actor }) => ok(await pull(db, await actor(), readQuery(request))));
