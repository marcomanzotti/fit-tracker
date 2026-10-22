import { setConsent } from "@/server/consents";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody, requestMeta } from "@/server/validate";

// Grant or revoke a consent; answers with the resulting consent state.
export const POST = route(async ({ request, db, actor }) =>
  ok(await setConsent(db, await actor(), await readBody(request), requestMeta(request.headers))),
);
