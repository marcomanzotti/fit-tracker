import type { Metadata } from "next";
import { Suspense } from "react";
import { Loading } from "@/components/ui";
import { listBodyMeasurements } from "@/server/client-data";
import { requirePage } from "@/server/page";
import { localDay } from "@/server/programs";
import { WeightForm } from "./weight-form";

export const metadata: Metadata = { title: "Corpo" };

export default function BodyPage() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="condensed text-4xl font-bold leading-none">Corpo</h1>
      <Suspense fallback={<Loading />}>
        <BodyContent />
      </Suspense>
    </div>
  );
}

const dayFormat = new Intl.DateTimeFormat("it-IT", { weekday: "short", day: "numeric", month: "short" });

async function BodyContent() {
  const { actor, db } = await requirePage("client");
  const measurements = await listBodyMeasurements(db, actor, actor.id, {}, null);
  const weights = measurements.filter((m) => m.kind === "weight").reverse();
  const latest = weights[0];
  const previous = weights[1];
  const change = latest && previous ? latest.value - previous.value : null;

  return (
    <>
      {latest && (
        <p className="flex items-baseline gap-3">
          <span className="condensed text-6xl font-bold leading-none">{latest.value.toLocaleString("it-IT")}</span>
          <span className="text-ash">kg</span>
          {change !== null && change !== 0 && (
            <span className="condensed text-xl text-ash">
              {change > 0 ? "+" : "−"}
              {Math.abs(change).toLocaleString("it-IT", { maximumFractionDigits: 1 })} dalla volta prima
            </span>
          )}
        </p>
      )}
      <WeightForm today={localDay("Europe/Rome")} />
      {weights.length > 0 ? (
        <ol className="divide-y divide-seam border-y border-seam">
          {weights.slice(0, 30).map((weight) => (
            <li key={weight.id} className="flex justify-between py-3">
              <span className="text-ash">{dayFormat.format(new Date(`${weight.measuredOn}T12:00:00`))}</span>
              <span className="condensed text-lg">{weight.value.toLocaleString("it-IT")} kg</span>
            </li>
          ))}
        </ol>
      ) : (
        <p className="text-ash">Pesati al mattino, dopo il bagno e prima di colazione: è il valore più confrontabile.</p>
      )}
    </>
  );
}
