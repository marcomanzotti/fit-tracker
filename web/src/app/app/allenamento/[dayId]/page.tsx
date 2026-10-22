import { notFound } from "next/navigation";
import { Suspense } from "react";
import { Loading } from "@/components/ui";
import { requirePage } from "@/server/page";
import { myProgram } from "@/server/programs";
import { WorkoutLogger, type LoggerExercise } from "./workout-logger";

type Params = { params: Promise<{ dayId: string }> };

export default function WorkoutPage({ params }: Params) {
  return (
    <Suspense fallback={<Loading />}>
      <WorkoutContent params={params} />
    </Suspense>
  );
}

const DEFAULT_REST_SEC = 90;

async function WorkoutContent({ params }: Params) {
  const { dayId } = await params;
  const { actor, db } = await requirePage("client");
  const program = await myProgram(db, actor);
  const day = program?.days.find((candidate) => candidate.id === dayId);
  if (!program || !day) notFound();

  // One row per set, pre-filled with the target and the suggested load.
  const exercises: LoggerExercise[] = day.blocks.flatMap((block) =>
    block.items.map((item) => ({
      itemId: item.itemId,
      exerciseId: item.exerciseId,
      name: item.exercise?.nameIt ?? "Esercizio",
      target: item.targetText,
      restSec: item.restSec ?? block.restAfterSec ?? DEFAULT_REST_SEC,
      timed: item.target.sets.some((group) => group.seconds !== undefined),
      sets: item.target.sets.flatMap((group, groupIndex) => {
        const suggested = group.load?.mode === "kg" ? group.load.value : item.suggestedKg[groupIndex];
        return Array.from({ length: group.count }, () => ({
          type: group.type,
          reps: group.reps ? String(group.reps.max) : "",
          seconds: group.seconds ? String(group.seconds) : "",
          loadKg: suggested ? String(suggested).replace(".", ",") : "",
        }));
      }),
    })),
  );

  return (
    <WorkoutLogger
      day={{ id: day.id, label: day.label }}
      programVersionId={program.versionId}
      week={program.week}
      today={program.today}
      exercises={exercises}
    />
  );
}
