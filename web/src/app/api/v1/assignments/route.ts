import { createAssignment } from "@/server/care";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody } from "@/server/validate";

// Admin pairs a client with a professional (pending until the client accepts).
export const POST = route(async ({ request, db, actor }) =>
  ok(await createAssignment(db, await actor(), await readBody(request)), { status: 201 }),
);
