import { listBodyMeasurements } from "@/server/client-data";
import { ok } from "@/server/http";
import { route } from "@/server/route";
import { idParam, readQuery, requestMeta } from "@/server/validate";

// ?from=yyyy-mm-dd&to=yyyy-mm-dd. Staff access is checked and logged.
export const GET = route<{ clientId: string }>(async ({ request, db, actor, params }) =>
  ok(
    await listBodyMeasurements(
      db,
      await actor(),
      idParam(params.clientId, "Client"),
      readQuery(request),
      requestMeta(request.headers).ipAddress,
    ),
  ),
);
