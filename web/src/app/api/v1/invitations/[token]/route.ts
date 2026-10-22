import { previewInvitation } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";

// Public: the acceptance page shows who invited whom before sign-in.
export const GET = route<{ token: string }>(async ({ db, params }) => ok(await previewInvitation(db, params.token)));
