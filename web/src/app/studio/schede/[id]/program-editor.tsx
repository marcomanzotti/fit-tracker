"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Button, Notice } from "@/components/ui";
import { api, ApiError } from "@/lib/api";
import type { ProgramDocument } from "@/lib/program/document";
import { addDay, addExercise, removeDay, renameDay, setWeeks } from "@/lib/program/edit";
import { ExercisePicker } from "./exercise-picker";
import { ProgramGrid, type ProgressMap } from "./program-grid";

type EditorProgram = {
  id: string;
  title: string;
  status: string;
  clientId: string | null;
  clientName: string | null;
  draft: ProgramDocument;
  revision: number;
  latestVersion: number | null;
  currentWeek: number | null;
};

type SaveState = { kind: "saved" } | { kind: "dirty" } | { kind: "saving" } | { kind: "error"; message: string; conflict: boolean };

type ProgressResponse = {
  days: { items: { itemId: string; weeks: { planned: string; completion: number | null; done: { reps: number | null; loadKg: number | null }[] }[] }[] }[];
};

const AUTOSAVE_DELAY_MS = 800;
const SAVE_LABEL: Record<SaveState["kind"], string> = {
  saved: "Salvata",
  dirty: "Modifiche non salvate",
  saving: "Salvo…",
  error: "Non salvata",
};

export function ProgramEditor({ program, exerciseNames }: { program: EditorProgram; exerciseNames: Record<string, string> }) {
  const [doc, setDoc] = useState(program.draft);
  const [title, setTitle] = useState(program.title);
  const [names, setNames] = useState(exerciseNames);
  const [dayId, setDayId] = useState<string | null>(program.draft.days[0]?.id ?? null);
  const [save, setSave] = useState<SaveState>({ kind: "saved" });
  const [pasteErrors, setPasteErrors] = useState<string[]>([]);
  const [mode, setMode] = useState<"plan" | "progress">("plan");
  const [progress, setProgress] = useState<ProgressMap | null>(null);
  const [published, setPublished] = useState<number | null>(program.latestVersion);
  const [publishing, setPublishing] = useState(false);
  const [notice, setNotice] = useState<{ tone: "success" | "error"; text: string } | null>(null);

  const revision = useRef(program.revision);
  // Saves run one after another, so two never race with the same revision.
  const queue = useRef<Promise<void>>(Promise.resolve());
  const loaded = useRef(true);

  function change(next: ProgramDocument) {
    setDoc(next);
    setSave({ kind: "dirty" });
  }

  // Autosave: the server is an external system, so this is an effect.
  useEffect(() => {
    if (loaded.current) {
      loaded.current = false;
      return;
    }
    const timer = setTimeout(() => {
      queue.current = queue.current.then(async () => {
        setSave({ kind: "saving" });
        try {
          const saved = await api<{ draftRevision: number }>(`/api/v1/programs/${program.id}/draft`, {
            method: "PUT",
            body: { draft: doc, revision: revision.current, title: title.trim() || undefined },
          });
          revision.current = saved.draftRevision;
          setSave({ kind: "saved" });
        } catch (failure: unknown) {
          const conflict = failure instanceof ApiError && failure.code === "edited_elsewhere";
          setSave({ kind: "error", message: failure instanceof Error ? failure.message : "Salvataggio non riuscito.", conflict });
        }
      });
    }, AUTOSAVE_DELAY_MS);
    return () => clearTimeout(timer);
  }, [doc, title, program.id]);

  // Leaving with unsaved edits asks first.
  useEffect(() => {
    if (save.kind === "saved") return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [save.kind]);

  async function showProgress() {
    setMode("progress");
    try {
      const response = await api<ProgressResponse>(`/api/v1/programs/${program.id}/progress`);
      const map: ProgressMap = {};
      for (const day of response.days) for (const item of day.items) map[item.itemId] = item.weeks;
      setProgress(map);
    } catch (failure: unknown) {
      setMode("plan");
      setNotice({ tone: "error", text: failure instanceof Error ? failure.message : "Dati non disponibili." });
    }
  }

  async function publish(note: string) {
    setPublishing(true);
    setNotice(null);
    await queue.current;
    try {
      const version = await api<{ version: number }>(`/api/v1/programs/${program.id}/publish`, {
        body: { changeNote: note.trim() || undefined },
      });
      setPublished(version.version);
      setNotice({ tone: "success", text: `Pubblicata la versione ${version.version}: ${program.clientName ?? "il cliente"} la vede da adesso.` });
    } catch (failure: unknown) {
      setNotice({ tone: "error", text: failure instanceof Error ? failure.message : "Pubblicazione non riuscita." });
    } finally {
      setPublishing(false);
    }
  }

  const day = doc.days.find((candidate) => candidate.id === dayId) ?? doc.days[0] ?? null;
  const isTemplate = !program.clientId;

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0 flex-1">
          <p className="mb-1 text-sm text-ash">
            {isTemplate ? (
              <Link href="/studio/template" className="hover:text-chalk">Template</Link>
            ) : (
              <Link href={`/studio/clienti/${program.clientId}`} className="hover:text-chalk">{program.clientName ?? "Cliente"}</Link>
            )}
            {published && ` — pubblicata v${published}`}
          </p>
          <label htmlFor="program-title" className="sr-only">Titolo della scheda</label>
          <input
            id="program-title"
            value={title}
            onChange={(event) => {
              setTitle(event.target.value);
              setSave({ kind: "dirty" });
            }}
            className="condensed w-full bg-transparent text-4xl font-bold leading-none tracking-tight focus:outline-none"
          />
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <span role="status" className={save.kind === "error" ? "text-sm text-alert" : "text-sm text-ash"}>
            {SAVE_LABEL[save.kind]}
          </span>
          <label className="flex items-center gap-2 text-sm text-ash">
            Settimane
            <input
              type="number"
              min={1}
              max={52}
              value={doc.weeks}
              onChange={(event) => change(setWeeks(doc, Number(event.target.value)))}
              className="condensed w-16 rounded-[var(--radius-control)] border border-seam bg-graphite px-2 py-1.5 text-base text-chalk"
            />
          </label>
          {!isTemplate && <PublishButton busy={publishing} disabled={save.kind === "error"} onPublish={publish} />}
        </div>
      </header>

      {save.kind === "error" && (
        <Notice tone="error">
          {save.message} {save.conflict && <button type="button" className="underline" onClick={() => window.location.reload()}>Ricarica</button>}
        </Notice>
      )}
      {notice && <Notice tone={notice.tone}>{notice.text}</Notice>}
      {pasteErrors.length > 0 && (
        <Notice tone="error">
          Alcune celle incollate non sono state riconosciute: {pasteErrors.slice(0, 3).join("; ")}
          {pasteErrors.length > 3 && ` e altre ${pasteErrors.length - 3}`}.
        </Notice>
      )}

      <nav aria-label="Giorni" className="flex flex-wrap items-center gap-2">
        {doc.days.map((candidate) => (
          <button
            key={candidate.id}
            type="button"
            aria-current={candidate.id === day?.id ? "true" : undefined}
            onClick={() => setDayId(candidate.id)}
            className="rounded-[var(--radius-control)] border border-seam px-3 py-2 text-sm aria-[current=true]:border-signal aria-[current=true]:text-chalk text-ash hover:text-chalk"
          >
            {candidate.label}
          </button>
        ))}
        <Button
          onClick={() => {
            const next = addDay(doc);
            change(next);
            setDayId(next.days.at(-1)?.id ?? null);
          }}
        >
          Aggiungi giorno
        </Button>
        {!isTemplate && (
          <div className="ml-auto flex rounded-[var(--radius-control)] border border-seam p-0.5 text-sm">
            <button type="button" aria-pressed={mode === "plan"} onClick={() => setMode("plan")} className="rounded-[6px] px-3 py-1.5 aria-pressed:bg-steel">
              Piano
            </button>
            <button type="button" aria-pressed={mode === "progress"} onClick={showProgress} className="rounded-[6px] px-3 py-1.5 aria-pressed:bg-steel">
              Previsto vs fatto
            </button>
          </div>
        )}
      </nav>

      {day ? (
        <section aria-label={day.label} className="flex flex-col gap-4">
          {mode === "plan" && (
            <div className="flex flex-wrap items-center gap-3">
              <label htmlFor="day-label" className="sr-only">Nome del giorno</label>
              <input
                id="day-label"
                value={day.label}
                onChange={(event) => change(renameDay(doc, day.id, event.target.value))}
                className="rounded-[var(--radius-control)] border border-seam bg-graphite px-3 py-2 font-semibold"
              />
              <ExercisePicker
                onPick={(exercise) => {
                  setNames({ ...names, [exercise.id]: exercise.nameIt });
                  change(addExercise(doc, day.id, exercise.id));
                }}
              />
              <button
                type="button"
                onClick={() => {
                  const next = removeDay(doc, day.id);
                  change(next);
                  setDayId(next.days[0]?.id ?? null);
                }}
                className="ml-auto text-sm text-ash hover:text-alert"
              >
                Togli il giorno
              </button>
            </div>
          )}
          {mode === "progress" && !progress ? (
            <p className="text-ash">Carico i risultati…</p>
          ) : (
            <ProgramGrid
              doc={doc}
              day={day}
              names={names}
              currentWeek={program.currentWeek}
              progress={mode === "progress" ? progress : null}
              onChange={change}
              onPasteErrors={setPasteErrors}
            />
          )}
          {mode === "plan" && (
            <p className="text-sm text-ash">
              Scrivi come su Excel: 4x8-10@RIR2, 3x5@75%, 5x5@RPE8, 3x30s, w:2x5@40kg + 1x3@100kg. Svuota una settimana per
              tornare alla progressione. Puoi incollare un blocco copiato da Excel.
            </p>
          )}
        </section>
      ) : (
        <p className="text-ash">Aggiungi il primo giorno della scheda.</p>
      )}
    </div>
  );
}

function PublishButton({ busy, disabled, onPublish }: { busy: boolean; disabled: boolean; onPublish: (note: string) => void }) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState("");
  if (!open) {
    return (
      <Button variant="primary" onClick={() => setOpen(true)} disabled={disabled}>
        Pubblica
      </Button>
    );
  }
  return (
    <form
      className="flex items-center gap-2"
      onSubmit={(event) => {
        event.preventDefault();
        onPublish(note);
        setOpen(false);
        setNote("");
      }}
    >
      <label htmlFor="change-note" className="sr-only">Cosa è cambiato</label>
      <input
        id="change-note"
        value={note}
        onChange={(event) => setNote(event.target.value)}
        placeholder="Cosa è cambiato (facoltativo)"
        className="min-h-11 rounded-[var(--radius-control)] border border-seam bg-graphite px-3 text-sm"
        autoFocus
      />
      <Button variant="primary" type="submit" disabled={busy}>
        {busy ? "Pubblico…" : "Conferma"}
      </Button>
      <Button type="button" onClick={() => setOpen(false)}>
        Annulla
      </Button>
    </form>
  );
}
