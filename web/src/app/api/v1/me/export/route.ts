import { exportAccount } from "@/server/account";
import { ok } from "@/server/http";
import { route } from "@/server/route";

// GDPR data export, downloaded as a JSON file.
export const GET = route(async ({ db, actor }) => {
  const data = await exportAccount(db, await actor());
  const day = data.exportedAt.slice(0, 10);
  return ok(data, { headers: { "Content-Disposition": `attachment; filename="fittracker-export-${day}.json"` } });
});
