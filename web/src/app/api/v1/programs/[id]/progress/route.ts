import { ok } from "@/server/http";
import { programProgress } from "@/server/programs";
import { route } from "@/server/route";
import { idParam } from "@/server/validate";

// Planned vs done per item and week.
export const GET = route<{ id: string }>(async ({ db, actor, params }) =>
  ok(await programProgress(db, await actor(), idParam(params.id, "Program"))),
);
