"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { Button, Loading, Notice } from "@/components/ui";
import type { SetType } from "@/lib/program/document";
import { pushMutations } from "@/lib/sync-queue";

type LoggerSet = { type: SetType; reps: string; seconds: string; loadKg: string; done?: boolean };

export type LoggerExercise = {
  itemId: string;
  exerciseId: string;
  name: string;
  target: string;
  restSec: number;
  timed: boolean;
  sets: LoggerSet[];
};

type Props = {
  day: { id: string; label: string };
  programVersionId: string;
  week: number;
  today: string;
  exercises: LoggerExercise[];
};

type Draft = { startedAt: string; exercises: LoggerExercise[] };

const toNumber = (value: string) => {
  const parsed = Number(value.replace(",", "."));
  return value.trim() && Number.isFinite(parsed) ? parsed : null;
};

const draftKey = (dayId: string, today: string) => `fittracker.workout.${today}.${dayId}`;

function loadDraft(key: string): Draft | null {
  try {
    return JSON.parse(localStorage.getItem(key) ?? "null") as Draft | null;
  } catch {
    return null;
  }
}

function storeDraft(key: string, draft: Draft | null): void {
  try {
    if (draft) localStorage.setItem(key, JSON.stringify(draft));
    else localStorage.removeItem(key);
  } catch {
    // Storage unavailable: the workout just is not kept across reloads.
  }
}

const noSubscription = () => () => {};

// The logger starts from the draft kept on this phone, which only the browser
// has: it mounts after hydration, so server and browser HTML always match.
export function WorkoutLogger(props: Props) {
  const inBrowser = useSyncExternalStore(noSubscription, () => true, () => false);
  return inBrowser ? <LoggerBody {...props} /> : <Loading />;
}

// Logging a workout in the gym: big inputs, one row per set, tap to tick a set
// off and the rest timer starts. Kept on the phone until it is sent.
function LoggerBody({ day, programVersionId, week, today, exercises: initial }: Props) {
  const router = useRouter();
  const key = draftKey(day.id, today);
  const [draft, setDraft] = useState<Draft>(
    () => loadDraft(key) ?? { startedAt: new Date().toISOString(), exercises: initial },
  );
  const [rest, setRest] = useState<{ endsAt: number; total: number } | null>(null);
  const [now, setNow] = useState(0);
  const [status, setStatus] = useState<{ tone: "info" | "error"; text: string } | null>(null);
  const [saving, setSaving] = useState(false);

  // The phone keeps the workout so a reload or a dropped tab loses nothing.
  useEffect(() => storeDraft(key, draft), [key, draft]);

  // Ticks the rest countdown once a second while it runs.
  useEffect(() => {
    if (!rest) return;
    const timer = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(timer);
  }, [rest]);

  const remaining = rest ? Math.max(0, Math.ceil((rest.endsAt - now) / 1000)) : 0;

  function updateSet(exerciseIndex: number, setIndex: number, patch: Partial<LoggerSet>) {
    setDraft((current) => ({
      ...current,
      exercises: current.exercises.map((exercise, i) =>
        i !== exerciseIndex
          ? exercise
          : { ...exercise, sets: exercise.sets.map((set, j) => (j === setIndex ? { ...set, ...patch } : set)) },
      ),
    }));
  }

  function toggleDone(exerciseIndex: number, setIndex: number) {
    const set = draft.exercises[exerciseIndex].sets[setIndex];
    updateSet(exerciseIndex, setIndex, { done: !set.done });
    if (!set.done) {
      const total = draft.exercises[exerciseIndex].restSec;
      const start = Date.now();
      setNow(start);
      setRest({ endsAt: start + total * 1000, total });
    }
  }

  function addSet(exerciseIndex: number) {
    setDraft((current) => ({
      ...current,
      exercises: current.exercises.map((exercise, i) => {
        if (i !== exerciseIndex) return exercise;
        const last = exercise.sets.at(-1);
        return { ...exercise, sets: [...exercise.sets, { type: "work", reps: last?.reps ?? "", seconds: last?.seconds ?? "", loadKg: last?.loadKg ?? "" }] };
      }),
    }));
  }

  async function finish() {
    setSaving(true);
    setStatus(null);
    const endedAt = new Date();
    const startedAt = draft.startedAt ? new Date(draft.startedAt) : endedAt;
    const session = {
      localDay: today,
      startedAt: startedAt.toISOString(),
      endedAt: endedAt.toISOString(),
      title: day.label,
      programVersionId,
      dayId: day.id,
      week,
      durationSec: Math.round((endedAt.getTime() - startedAt.getTime()) / 1000),
      source: "program",
      exercises: draft.exercises.map((exercise) => ({
        id: crypto.randomUUID(),
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        itemId: exercise.itemId,
        target: exercise.target,
        sets: exercise.sets.map((set) => ({
          id: crypto.randomUUID(),
          type: set.type,
          reps: toNumber(set.reps),
          seconds: toNumber(set.seconds),
          loadKg: toNumber(set.loadKg),
          done: set.done === true,
        })),
      })),
    };
    try {
      const outcome = await pushMutations([{ entity: "workout_session", op: "upsert", id: crypto.randomUUID(), data: session }]);
      if (typeof outcome === "object") throw new Error(outcome.rejected.join("; "));
      storeDraft(key, null);
      router.replace(outcome === "queued" ? "/app?inviato=dopo" : "/app?inviato=1");
    } catch (failure: unknown) {
      setStatus({ tone: "error", text: failure instanceof Error ? failure.message : "Allenamento non salvato." });
      setSaving(false);
    }
  }

  const doneCount = draft.exercises.reduce((sum, exercise) => sum + exercise.sets.filter((set) => set.done).length, 0);

  return (
    <div className="flex flex-col gap-6">
      <header>
        <p className="text-sm text-ash">Settimana {week}</p>
        <h1 className="condensed text-4xl font-bold leading-none">{day.label}</h1>
      </header>

      {draft.exercises.map((exercise, exerciseIndex) => (
        <section key={exercise.itemId} aria-labelledby={`exercise-${exercise.itemId}`} className="flex flex-col gap-2">
          <div className="flex items-baseline justify-between gap-3">
            <h2 id={`exercise-${exercise.itemId}`} className="text-lg font-semibold">
              {exercise.name}
            </h2>
            <span className="condensed text-lg text-ash">{exercise.target}</span>
          </div>
          <ol className="flex flex-col gap-1.5">
            {exercise.sets.map((set, setIndex) => (
              <li key={setIndex} className={`grid grid-cols-[2rem_1fr_1fr_3.5rem] items-center gap-2 rounded-[var(--radius-control)] px-1 ${set.done ? "bg-go/10" : ""}`}>
                <span className="condensed text-center text-ash">
                  {set.type === "warmup" ? "R" : exercise.sets.slice(0, setIndex + 1).filter((s) => s.type !== "warmup").length}
                </span>
                <SetInput
                  label={`kg, serie ${setIndex + 1}`}
                  suffix="kg"
                  value={set.loadKg}
                  onChange={(loadKg) => updateSet(exerciseIndex, setIndex, { loadKg })}
                />
                {exercise.timed ? (
                  <SetInput label={`secondi, serie ${setIndex + 1}`} suffix="s" value={set.seconds} onChange={(seconds) => updateSet(exerciseIndex, setIndex, { seconds })} />
                ) : (
                  <SetInput label={`ripetizioni, serie ${setIndex + 1}`} suffix="rip" value={set.reps} onChange={(reps) => updateSet(exerciseIndex, setIndex, { reps })} />
                )}
                <button
                  type="button"
                  aria-pressed={set.done === true}
                  aria-label={`Serie ${setIndex + 1} fatta`}
                  onClick={() => toggleDone(exerciseIndex, setIndex)}
                  className="flex h-12 items-center justify-center rounded-[var(--radius-control)] border border-seam text-xl aria-pressed:border-go aria-pressed:bg-go aria-pressed:text-ink"
                >
                  ✓
                </button>
              </li>
            ))}
          </ol>
          <button type="button" onClick={() => addSet(exerciseIndex)} className="self-start text-sm text-ash hover:text-chalk">
            Aggiungi una serie
          </button>
        </section>
      ))}

      {status && <Notice tone={status.tone}>{status.text}</Notice>}

      <div className="sticky bottom-20 flex flex-col gap-2">
        {rest && remaining > 0 && (
          <div role="timer" aria-live="off" className="flex items-center justify-between rounded-[var(--radius-control)] border border-seam bg-steel px-4 py-3">
            <span className="text-ash">Recupero</span>
            <span className="condensed text-3xl font-bold">
              {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, "0")}
            </span>
            <button type="button" onClick={() => setRest(null)} className="text-sm text-ash hover:text-chalk">
              Salta
            </button>
          </div>
        )}
        <Button variant="primary" onClick={finish} disabled={saving || doneCount === 0} className="min-h-14 text-base">
          {saving ? "Salvo…" : doneCount === 0 ? "Spunta le serie fatte" : `Finisci (${doneCount} serie)`}
        </Button>
      </div>
    </div>
  );
}

function SetInput({ label, suffix, value, onChange }: { label: string; suffix: string; value: string; onChange: (value: string) => void }) {
  return (
    <label className="relative">
      <span className="sr-only">{label}</span>
      <input
        inputMode="decimal"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="condensed h-12 w-full rounded-[var(--radius-control)] border border-seam bg-graphite px-3 pr-10 text-xl focus:border-signal focus:outline-none"
      />
      <span className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-sm text-ash">{suffix}</span>
    </label>
  );
}
