import { createExercise, searchExercises } from "@/server/exercises";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { readBody, readQuery } from "@/server/validate";

// ?q=panca&category=chest&limit=20, for any signed-in user.
export const GET = route(async ({ request, db, actor }) => {
  await actor();
  return ok(await searchExercises(db, readQuery(request)));
});

export const POST = route(async ({ request, db, actor }) =>
  ok(await createExercise(db, await actor(), await readBody(request)), { status: 201 }),
);
