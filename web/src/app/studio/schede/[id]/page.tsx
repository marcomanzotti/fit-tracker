import type { Metadata } from "next";
import { inArray } from "drizzle-orm";
import { Suspense } from "react";
import { Loading } from "@/components/ui";
import { exercise } from "@/db/schema";
import { exerciseIdsOf } from "@/lib/program/document";
import { weekOf } from "@/lib/program/resolve";
import { listCare } from "@/server/care";
import { requirePage } from "@/server/page";
import { getProgram, localDay } from "@/server/programs";
import { idParam } from "@/server/validate";
import { ProgramEditor } from "./program-editor";

export const metadata: Metadata = { title: "Scheda" };

type Params = { params: Promise<{ id: string }> };

export default function ProgramPage({ params }: Params) {
  return (
    <Suspense fallback={<Loading label="Apro la scheda" />}>
      <ProgramContent params={params} />
    </Suspense>
  );
}

async function ProgramContent({ params }: Params) {
  const { id } = await params;
  const { actor, db } = await requirePage("staff", "admin");
  const program = await getProgram(db, actor, idParam(id, "Program"));

  const ids = exerciseIdsOf(program.draft);
  const names =
    ids.length === 0
      ? []
      : await db.select({ id: exercise.id, nameIt: exercise.nameIt }).from(exercise).where(inArray(exercise.id, ids));
  const client = program.clientId
    ? (await listCare(db, actor)).find((entry) => entry.person.id === program.clientId)?.person
    : undefined;
  // The column the client is in this week, for active programs.
  const currentWeek =
    program.status === "active" && program.startDate
      ? weekOf(program.draft, program.startDate, localDay("Europe/Rome"))
      : null;

  return (
    <ProgramEditor
      program={{
        id: program.id,
        title: program.title,
        status: program.status,
        clientId: program.clientId,
        clientName: client?.name ?? null,
        draft: program.draft,
        revision: program.draftRevision,
        latestVersion: program.versions[0]?.version ?? null,
        currentWeek,
      }}
      exerciseNames={Object.fromEntries(names.map((row) => [row.id, row.nameIt]))}
    />
  );
}
