import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { Loading, PageTitle, Panel } from "@/components/ui";
import { ROLE_LABEL } from "@/lib/labels";
import { listCare } from "@/server/care";
import { listBodyMeasurements, listSessions } from "@/server/client-data";
import { HttpError } from "@/server/http";
import { requirePage } from "@/server/page";
import { listPrograms } from "@/server/programs";
import { NewProgramButton } from "./new-program-button";

export const metadata: Metadata = { title: "Cliente" };

type Params = { params: Promise<{ id: string }> };

export default function ClientPage({ params }: Params) {
  return (
    <Suspense fallback={<Loading />}>
      <ClientContent params={params} />
    </Suspense>
  );
}

const STATUS_LABEL: Record<string, string> = { draft: "Bozza", active: "Attiva", archived: "Archiviata" };
const dayFormat = new Intl.DateTimeFormat("it-IT", { weekday: "short", day: "numeric", month: "short" });
const formatDay = (day: string) => dayFormat.format(new Date(`${day}T12:00:00`));

// A section the professional may not be allowed to see (scope not shared):
// it says so instead of breaking the page.
async function ifShared<T>(read: Promise<T>): Promise<T | null> {
  try {
    return await read;
  } catch (error: unknown) {
    if (error instanceof HttpError && error.status === 403) return null;
    throw error;
  }
}

const HISTORY_DAYS = 90;
const daysAgo = (days: number) => new Date(Date.now() - days * 86_400_000).toISOString().slice(0, 10);

const NOT_SHARED = <p className="text-sm text-ash">Il cliente non condivide questi dati con te.</p>;

async function ClientContent({ params }: Params) {
  const { id } = await params;
  const { actor, db } = await requirePage("staff", "admin");
  const care = (await listCare(db, actor)).filter((entry) => entry.person.id === id);
  if (care.length === 0) notFound();
  const person = care[0].person;

  const since = daysAgo(HISTORY_DAYS);
  const [programs, sessions, measurements] = await Promise.all([
    ifShared(listPrograms(db, actor, { clientId: id })),
    ifShared(listSessions(db, actor, id, { from: since }, null)),
    ifShared(listBodyMeasurements(db, actor, id, { from: since }, null)),
  ]);
  const weights = (measurements ?? []).filter((m) => m.kind === "weight").slice(-8).reverse();

  return (
    <>
      <PageTitle aside={<p className="text-ash">{care.map((entry) => ROLE_LABEL[entry.role]).join(", ")}</p>}>
        {person.name}
      </PageTitle>
      <p className="-mt-4 mb-8 text-ash">{person.email}</p>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
        <Panel title="Schede" actions={programs && <NewProgramButton clientId={id} />}>
          {!programs ? (
            NOT_SHARED
          ) : programs.length === 0 ? (
            <p className="text-sm text-ash">Nessuna scheda. Creane una o assegna un template.</p>
          ) : (
            <ul className="divide-y divide-seam">
              {programs.map((program) => (
                <li key={program.id}>
                  <Link href={`/studio/schede/${program.id}`} className="flex items-baseline justify-between gap-4 py-3 hover:text-signal">
                    <span className="font-semibold">{program.title}</span>
                    <span className={program.status === "active" ? "text-sm text-go" : "text-sm text-ash"}>
                      {STATUS_LABEL[program.status] ?? program.status}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Panel>

        <Panel title="Peso">
          {!measurements ? (
            NOT_SHARED
          ) : weights.length === 0 ? (
            <p className="text-sm text-ash">Nessuna pesata negli ultimi 90 giorni.</p>
          ) : (
            <ol className="condensed flex flex-col gap-1">
              {weights.map((weight) => (
                <li key={weight.id} className="flex justify-between text-lg">
                  <span className="text-ash">{formatDay(weight.measuredOn)}</span>
                  <span>{weight.value.toLocaleString("it-IT")} kg</span>
                </li>
              ))}
            </ol>
          )}
        </Panel>

        <Panel title="Ultimi allenamenti" className="lg:col-span-2">
          {!sessions ? (
            NOT_SHARED
          ) : sessions.length === 0 ? (
            <p className="text-sm text-ash">Nessun allenamento registrato negli ultimi 90 giorni.</p>
          ) : (
            <ul className="divide-y divide-seam">
              {sessions.slice(0, 12).map((session) => {
                const sets = session.exercises.flatMap((exercise) => exercise.sets.filter((set) => set.done));
                const volume = sets.reduce((sum, set) => sum + (set.reps ?? 0) * (set.loadKg ?? 0), 0);
                return (
                  <li key={session.id} className="grid grid-cols-[7rem_1fr_auto] items-baseline gap-4 py-3">
                    <span className="text-sm text-ash">{formatDay(session.localDay)}</span>
                    <span className="font-medium">{session.title}</span>
                    <span className="condensed text-ash">
                      {sets.length} serie{volume > 0 && `, ${Math.round(volume).toLocaleString("it-IT")} kg sollevati`}
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </Panel>
      </div>
    </>
  );
}
