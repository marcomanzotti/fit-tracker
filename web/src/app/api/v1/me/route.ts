import { getMe } from "@/server/account";
import { ok } from "@/server/http";
import { route } from "@/server/route";

// The signed-in user, profile, consents and care team.
export const GET = route(async ({ db, actor }) => ok(await getMe(db, await actor())));
