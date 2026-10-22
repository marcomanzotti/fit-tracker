import { ok } from "@/server/http";
import { myProgram } from "@/server/programs";
import { route } from "@/server/route";

// The client's active program resolved for this week (null when none).
export const GET = route(async ({ db, actor }) => ok(await myProgram(db, await actor())));
