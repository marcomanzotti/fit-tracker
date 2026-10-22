import Link from "next/link";
import { Suspense } from "react";
import { Loading, Notice } from "@/components/ui";
import { requirePage } from "@/server/page";
import { myProgram } from "@/server/programs";

type Search = { searchParams: Promise<{ inviato?: string }> };

export default function TodayPage({ searchParams }: Search) {
  return (
    <Suspense fallback={<Loading />}>
      <TodayContent searchParams={searchParams} />
    </Suspense>
  );
}

const SENT_MESSAGE: Record<string, string> = {
  "1": "Allenamento salvato: il tuo professionista lo vede già.",
  dopo: "Sei offline: l'allenamento è salvato sul telefono e partirà appena torni online.",
};

// ISO weekday (1 = Monday) of a yyyy-mm-dd day.
const weekdayOf = (day: string) => ((new Date(`${day}T12:00:00Z`).getUTCDay() + 6) % 7) + 1;
const kg = (value: number) => `${value.toLocaleString("it-IT")} kg`;

async function TodayContent({ searchParams }: Search) {
  const { inviato } = await searchParams;
  const { actor, db } = await requirePage("client");
  const sent = inviato ? SENT_MESSAGE[inviato] : undefined;
  const program = await myProgram(db, actor);

  if (!program) {
    return (
      <section className="flex flex-col gap-3 pt-8">
        <h1 className="condensed text-4xl font-bold leading-none">Ciao {actor.name.split(" ")[0]}</h1>
        <p className="text-ash">
          Il tuo professionista non ha ancora pubblicato una scheda. Appena lo fa, la trovi qui, settimana per settimana.
        </p>
      </section>
    );
  }

  const todayWeekday = weekdayOf(program.today);

  return (
    <div className="flex flex-col gap-6">
      <header>
        <p className="text-sm text-ash">
          {program.title}, settimana {program.week} di {program.weeks}
        </p>
        <h1 className="condensed text-4xl font-bold leading-none">Oggi</h1>
      </header>
      {sent && <Notice tone="success">{sent}</Notice>}
      <ol className="flex flex-col gap-4">
        {program.days.map((day) => {
          const isToday = day.weekday === todayWeekday;
          const items = day.blocks.flatMap((block) => block.items);
          return (
            <li
              key={day.id}
              className={`rounded-[var(--radius-panel)] border p-4 ${isToday ? "border-signal" : "border-seam"} bg-graphite`}
            >
              <div className="mb-3 flex items-baseline justify-between gap-3">
                <h2 className="text-xl font-semibold">{day.label}</h2>
                {isToday && <span className="text-sm text-signal">Previsto oggi</span>}
              </div>
              <ul className="mb-4 flex flex-col gap-1.5">
                {items.map((item) => {
                  const suggestion = item.suggestedKg.find((value) => value !== null);
                  return (
                    <li key={item.itemId} className="flex items-baseline justify-between gap-3">
                      <span className="min-w-0">{item.exercise?.nameIt ?? "Esercizio"}</span>
                      <span className="condensed shrink-0 text-right text-lg text-ash">
                        {item.targetText}
                        {suggestion && !item.targetText.includes("kg") ? ` ≈ ${kg(suggestion)}` : ""}
                      </span>
                    </li>
                  );
                })}
              </ul>
              <Link
                href={`/app/allenamento/${day.id}`}
                className={`flex min-h-12 items-center justify-center rounded-[var(--radius-control)] text-base font-semibold ${
                  isToday ? "bg-signal text-ink" : "border border-seam bg-steel"
                }`}
              >
                Inizia {day.label}
              </Link>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
