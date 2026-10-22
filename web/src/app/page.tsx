import Image from "next/image";
import Link from "next/link";
import { APP } from "@/config";

// The public home: what the service is, and the way in. The visual is the real
// thing a client gets, a week of their program as the studio writes it.
const SAMPLE_WEEK = [
  { label: "A", name: "Squat con bilanciere", cells: ["5x5@75%", "5x5@77,5%", "5x5@80%", "3x5@70%"] },
  { label: "B1", name: "Panca piana con manubri", cells: ["4x8@RIR2", "4x8@RIR2", "4x8@RIR1", "2x8@RIR3"] },
  { label: "B2", name: "Rematore con bilanciere", cells: ["4x10@60kg", "4x10@62,5kg", "4x10@65kg", "2x10@58,5kg"] },
];

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-16 px-5 py-10 md:py-16">
      <header className="flex items-center justify-between">
        <span className="flex items-center gap-3">
          <Image src="/icon-192.png" alt="" width={36} height={36} className="rounded-[9px]" priority />
          <span className="condensed text-2xl font-bold">{APP.name}</span>
        </span>
        <Link href="/accedi" className="rounded-[var(--radius-control)] border border-seam px-4 py-2 text-sm font-semibold hover:bg-steel">
          Accedi
        </Link>
      </header>

      <section className="flex max-w-2xl flex-col gap-5">
        <h1 className="condensed text-5xl leading-[0.95] font-bold tracking-tight md:text-7xl">
          La tua scheda, aggiornata dal tuo studio, sempre in tasca.
        </h1>
        <p className="text-lg text-ash">
          Il personal trainer scrive la scheda, tu registri ogni serie in palestra, lui vede cosa hai fatto e la adatta. Con
          nutrizionista e fisioterapista nello stesso posto, se lo studio li ha.
        </p>
        <p className="text-ash">
          Hai ricevuto un invito? Apri il link nella mail. Altrimenti{" "}
          <Link href="/registrati" className="text-chalk underline underline-offset-4">
            crea un account
          </Link>
          .
        </p>
      </section>

      <figure className="overflow-x-auto rounded-[var(--radius-panel)] border border-seam">
        <table className="w-full min-w-[40rem] border-collapse text-left">
          <thead>
            <tr className="border-b border-seam bg-graphite text-sm text-ash">
              <th className="px-4 py-3 font-medium">Giorno A</th>
              {["Sett. 1", "Sett. 2", "Sett. 3", "Scarico"].map((week, index) => (
                <th key={week} className={`px-4 py-3 font-medium ${index === 1 ? "border-b-2 border-signal text-chalk" : ""}`}>
                  {week}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {SAMPLE_WEEK.map((row) => (
              <tr key={row.label} className="border-b border-seam last:border-b-0">
                <th className="px-4 py-3 font-normal">
                  <span className={`condensed mr-3 font-bold ${row.label.length > 1 ? "text-amber" : "text-ash"}`}>{row.label}</span>
                  {row.name}
                </th>
                {row.cells.map((cell, index) => (
                  <td key={cell} className={`condensed px-4 py-3 text-lg ${index === 0 ? "text-chalk" : "text-ash"} ${index === 1 ? "bg-signal/5" : ""}`}>
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        <figcaption className="border-t border-seam px-4 py-3 text-sm text-ash">
          Una scheda come la scrive il PT: la progressione si calcola da sola, la settimana in corso è in evidenza.
        </figcaption>
      </figure>

      <footer className="text-sm text-ash">
        <Link href="/privacy" className="hover:text-chalk">
          Informativa privacy
        </Link>
      </footer>
    </main>
  );
}
