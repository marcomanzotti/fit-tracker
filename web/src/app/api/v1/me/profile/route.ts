import { updateProfile } from "@/server/account";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody } from "@/server/validate";

export const PATCH = route(async ({ request, db, actor }) =>
  ok(await updateProfile(db, await actor(), await readBody(request))),
);
