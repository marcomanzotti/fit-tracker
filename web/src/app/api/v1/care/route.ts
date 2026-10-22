import { listCare } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";

// A client's professionals, or a professional's clients.
export const GET = route(async ({ db, actor }) => ok(await listCare(db, await actor())));
