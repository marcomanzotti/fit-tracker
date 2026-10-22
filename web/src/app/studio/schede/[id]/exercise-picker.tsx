"use client";

import { useEffect, useState } from "react";
import { Input } from "@/components/ui";
import { api } from "@/lib/api";
import { MUSCLE_LABEL } from "@/lib/labels";

type Exercise = { id: string; nameIt: string; category: string };

const SEARCH_DELAY_MS = 200;

// Search the studio library (Italian or English names, typos welcome) and add.
export function ExercisePicker({ onPick }: { onPick: (exercise: Exercise) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Exercise[]>([]);
  const [error, setError] = useState<string | null>(null);

  // Debounced search against the API: an external system, so an effect.
  useEffect(() => {
    const term = query.trim();
    if (term.length < 2) return;
    const timer = setTimeout(() => {
      api<Exercise[]>(`/api/v1/exercises?q=${encodeURIComponent(term)}&limit=8`)
        .then((found) => {
          setResults(found);
          setError(null);
        })
        .catch((failure: Error) => setError(failure.message));
    }, SEARCH_DELAY_MS);
    return () => clearTimeout(timer);
  }, [query]);

  const visible = query.trim().length >= 2 ? results : [];

  return (
    <div className="relative w-full max-w-md">
      <label htmlFor="exercise-search" className="sr-only">
        Aggiungi un esercizio
      </label>
      <Input
        id="exercise-search"
        placeholder="Aggiungi esercizio: panca, squat, lat machine…"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        autoComplete="off"
      />
      {error && <p className="mt-2 text-sm text-alert">{error}</p>}
      {visible.length > 0 && (
        <ul className="absolute z-20 mt-1 w-full overflow-hidden rounded-[var(--radius-control)] border border-seam-strong bg-steel">
          {visible.map((exercise) => (
            <li key={exercise.id}>
              <button
                type="button"
                onClick={() => {
                  onPick(exercise);
                  setQuery("");
                  setResults([]);
                }}
                className="flex w-full items-baseline justify-between gap-4 px-3 py-2.5 text-left hover:bg-seam focus:bg-seam focus:outline-none"
              >
                <span>{exercise.nameIt}</span>
                <span className="text-xs text-ash">{MUSCLE_LABEL[exercise.category] ?? exercise.category}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
