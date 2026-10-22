"use client";

import { useState, type ClipboardEvent, type KeyboardEvent } from "react";
import type { ProgramDay, ProgramDocument, ProgramItem, Progression } from "@/lib/program/document";
import {
  linkWithPrevious,
  moveBlock,
  pasteGrid,
  removeItem,
  rowsOf,
  setCell,
  setProgression,
  toggleDeload,
  unlinkItem,
} from "@/lib/program/edit";
import { isDeloadWeek, isOverridden, resolveItem } from "@/lib/program/resolve";
import { formatPrescription, parsePrescription } from "@/lib/program/shorthand";

export type ProgressCell = { planned: string; completion: number | null; done: { reps: number | null; loadKg: number | null }[] };
export type ProgressMap = Record<string, ProgressCell[]>;

type GridProps = {
  doc: ProgramDocument;
  day: ProgramDay;
  names: Record<string, string>;
  currentWeek: number | null;
  progress: ProgressMap | null;
  onChange: (doc: ProgramDocument) => void;
  onPasteErrors: (errors: string[]) => void;
};

// The spreadsheet: one row per exercise, one column per week. Week 1 is what the
// PT writes; later weeks show what the progression rule gives (grey) unless the
// PT typed over them (amber tick). Enter moves down, Excel blocks can be pasted.
export function ProgramGrid({ doc, day, names, currentWeek, progress, onChange, onPasteErrors }: GridProps) {
  const rows = rowsOf(day);
  const weeks = Array.from({ length: doc.weeks }, (_, index) => index + 1);

  function focusCell(row: number, week: number) {
    document.querySelector<HTMLInputElement>(`[data-cell="${row}:${week}"]`)?.focus();
  }

  if (rows.length === 0) {
    return <p className="py-10 text-ash">Nessun esercizio in questo giorno. Cercane uno qui sopra per iniziare.</p>;
  }

  return (
    <div className="overflow-x-auto rounded-[var(--radius-panel)] border border-seam">
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b border-seam bg-graphite text-left text-ash">
            <th scope="col" className="sticky left-0 z-10 min-w-64 bg-graphite px-3 py-2 font-medium">
              Esercizio
            </th>
            <th scope="col" className="min-w-36 px-3 py-2 font-medium">
              Progressione
            </th>
            {weeks.map((week) => {
              const deload = isDeloadWeek(week, doc.phases);
              return (
                <th
                  key={week}
                  scope="col"
                  className={`group/week min-w-36 px-2 py-2 font-medium ${week === currentWeek ? "border-b-2 border-signal text-chalk" : ""}`}
                >
                  <span className="flex items-center justify-between gap-2">
                    <span>Sett. {week}</span>
                    {!progress && (
                      <button
                        type="button"
                        onClick={() => onChange(toggleDeload(doc, week))}
                        aria-pressed={deload}
                        title={deload ? "Togli lo scarico" : "Rendi settimana di scarico"}
                        className={`rounded px-1.5 text-xs ${
                          deload
                            ? "bg-teal/20 text-teal"
                            : "text-ash/60 opacity-0 group-hover/week:opacity-100 hover:text-chalk focus:opacity-100"
                        }`}
                      >
                        {deload ? "Scarico" : "Rendi scarico"}
                      </button>
                    )}
                  </span>
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {rows.map(({ block, item, label, isFirstInBlock, isLastInBlock }, rowIndex) => (
            <tr key={item.id} className={`group ${isLastInBlock ? "border-b border-seam" : ""}`}>
              <th scope="row" className="sticky left-0 z-10 bg-ink px-3 py-2 text-left align-top font-normal">
                <div className="flex gap-3">
                  <span
                    className={`condensed w-7 shrink-0 pt-0.5 text-base font-bold ${block.items.length > 1 ? "text-amber" : "text-ash"}`}
                  >
                    {label}
                  </span>
                  <div className="min-w-0">
                    <p className="font-medium text-chalk">{names[item.exerciseId] ?? "Esercizio"}</p>
                    {!progress && (
                      <RowActions
                        onUp={isFirstInBlock ? () => onChange(moveBlock(doc, day.id, block.id, -1)) : undefined}
                        onDown={isFirstInBlock ? () => onChange(moveBlock(doc, day.id, block.id, 1)) : undefined}
                        onLink={isFirstInBlock && rowIndex > 0 ? () => onChange(linkWithPrevious(doc, day.id, block.id)) : undefined}
                        onUnlink={block.items.length > 1 ? () => onChange(unlinkItem(doc, item.id)) : undefined}
                        onRemove={() => onChange(removeItem(doc, item.id))}
                      />
                    )}
                  </div>
                </div>
              </th>
              <td className="px-3 py-2 align-top">
                {progress ? (
                  <span className="text-ash">{describeProgression(item.progression)}</span>
                ) : (
                  <ProgressionControl value={item.progression} onChange={(next) => onChange(setProgression(doc, item.id, next))} />
                )}
              </td>
              {weeks.map((week) =>
                progress ? (
                  <ProgressCellView key={week} cell={progress[item.id]?.[week - 1]} isCurrent={week === currentWeek} />
                ) : (
                  <td key={week} className={`px-1 py-1 align-top ${week === currentWeek ? "bg-signal/5" : ""}`}>
                    <PrescriptionCell
                      item={item}
                      week={week}
                      doc={doc}
                      cellId={`${rowIndex}:${week}`}
                      onCommit={(value) => onChange(setCell(doc, item.id, week, value))}
                      onPaste={(text) => {
                        const result = pasteGrid(doc, day.id, item.id, week, text);
                        onChange(result.doc);
                        onPasteErrors(result.errors);
                      }}
                      onEnter={(backwards) => focusCell(rowIndex + (backwards ? -1 : 1), week)}
                    />
                  </td>
                ),
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

type CellProps = {
  item: ProgramItem;
  week: number;
  doc: ProgramDocument;
  cellId: string;
  onCommit: (value: ReturnType<typeof resolveItem> | null) => void;
  onPaste: (text: string) => void;
  onEnter: (backwards: boolean) => void;
};

function PrescriptionCell({ item, week, doc, cellId, onCommit, onPaste, onEnter }: CellProps) {
  const shown = formatPrescription(resolveItem(item, week, doc.phases));
  const overridden = week > 1 && isOverridden(item, week);
  const derived = week > 1 && !overridden;
  const [text, setText] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function commit() {
    if (text === null) return;
    const value = text.trim();
    setText(null);
    if (value === shown) return setError(null);
    if (!value) {
      setError(null);
      // Emptying a later week removes the override; week 1 cannot be empty.
      if (week > 1) onCommit(null);
      return;
    }
    const parsed = parsePrescription(value);
    if (!parsed.ok) {
      setText(value);
      return setError(parsed.error);
    }
    setError(null);
    onCommit(parsed.value);
  }

  function handleKey(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Enter") {
      event.preventDefault();
      commit();
      onEnter(event.shiftKey);
    } else if (event.key === "Escape") {
      setText(null);
      setError(null);
    }
  }

  function handlePaste(event: ClipboardEvent<HTMLInputElement>) {
    const pasted = event.clipboardData.getData("text/plain");
    if (!/[\t\n]/.test(pasted)) return;
    event.preventDefault();
    setText(null);
    onPaste(pasted);
  }

  const errorId = `cell-error-${cellId}`;
  return (
    <div className="relative">
      {overridden && <span aria-hidden className="absolute top-1 bottom-1 left-0 w-0.5 rounded bg-amber" />}
      <input
        data-cell={cellId}
        aria-label={`Settimana ${week}`}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? errorId : undefined}
        title={error ?? (overridden ? "Modificata a mano: svuota per tornare alla progressione" : undefined)}
        value={text ?? shown}
        // Grow with long cells (top set + back-off) instead of cutting them off.
        style={{ width: `max(100%, ${(text ?? shown).length + 4}ch)` }}
        onChange={(event) => setText(event.target.value)}
        onFocus={(event) => event.target.select()}
        onBlur={commit}
        onKeyDown={handleKey}
        onPaste={handlePaste}
        spellCheck={false}
        className={`condensed w-full rounded-[6px] border bg-transparent px-2 py-1.5 text-base focus:bg-graphite focus:outline-none ${
          error ? "border-alert" : "border-transparent focus:border-signal"
        } ${derived && text === null ? "text-ash" : "text-chalk"}`}
      />
      {error && (
        <p id={errorId} role="alert" className="mt-1 px-2 text-xs text-alert">
          {error}
        </p>
      )}
    </div>
  );
}

function describeProgression(progression: Progression): string {
  if (progression.rule === "load") return `${progression.step > 0 ? "+" : ""}${String(progression.step).replace(".", ",")} kg/sett.`;
  if (progression.rule === "reps") return `${progression.step > 0 ? "+" : ""}${progression.step} rip./sett.`;
  return "Uguale";
}

function ProgressionControl({ value, onChange }: { value: Progression; onChange: (next: Progression) => void }) {
  const step = value.rule === "none" ? null : value.step;
  return (
    <div className="flex items-center gap-1.5">
      <select
        aria-label="Regola di progressione"
        value={value.rule}
        onChange={(event) => {
          const rule = event.target.value;
          if (rule === "load") onChange({ rule: "load", step: 2.5 });
          else if (rule === "reps") onChange({ rule: "reps", step: 1 });
          else onChange({ rule: "none" });
        }}
        className="rounded-[6px] border border-seam bg-graphite px-1.5 py-1 text-sm"
      >
        <option value="none">Uguale</option>
        <option value="load">+ kg</option>
        <option value="reps">+ rip.</option>
      </select>
      {step !== null && (
        <input
          aria-label="Aumento per settimana"
          type="number"
          inputMode="decimal"
          step={value.rule === "load" ? 0.5 : 1}
          value={step}
          onChange={(event) => {
            const next = Number(event.target.value);
            if (!Number.isFinite(next)) return;
            onChange(value.rule === "reps" ? { rule: "reps", step: Math.round(next) } : { rule: "load", step: next });
          }}
          className="condensed w-14 rounded-[6px] border border-seam bg-graphite px-1.5 py-1 text-base"
        />
      )}
    </div>
  );
}

type RowActionsProps = {
  onUp?: () => void;
  onDown?: () => void;
  onLink?: () => void;
  onUnlink?: () => void;
  onRemove: () => void;
};

// Shown on hover or keyboard focus, so the grid stays quiet while reading.
function RowActions({ onUp, onDown, onLink, onUnlink, onRemove }: RowActionsProps) {
  const actions = [
    { label: "Su", run: onUp },
    { label: "Giù", run: onDown },
    { label: "Unisci", run: onLink },
    { label: "Separa", run: onUnlink },
    { label: "Togli", run: onRemove, danger: true },
  ].filter((action) => action.run);
  return (
    <div className="mt-1 flex gap-x-2.5 whitespace-nowrap opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100">
      {actions.map((action) => (
        <button
          key={action.label}
          type="button"
          onClick={action.run}
          className={`text-xs ${action.danger ? "text-ash hover:text-alert" : "text-ash hover:text-chalk"}`}
        >
          {action.label}
        </button>
      ))}
    </div>
  );
}

function ProgressCellView({ cell, isCurrent }: { cell?: ProgressCell; isCurrent: boolean }) {
  if (!cell) return <td className="px-3 py-2" />;
  const completion = cell.completion;
  let tone = "text-ash";
  if (completion !== null && completion >= 1) tone = "text-go";
  else if (completion !== null && completion > 0) tone = "text-amber";
  const best = cell.done.reduce<{ reps: number | null; loadKg: number | null } | null>(
    (top, set) => ((set.loadKg ?? 0) > (top?.loadKg ?? -1) ? set : top),
    null,
  );
  return (
    <td className={`px-3 py-2 align-top ${isCurrent ? "bg-signal/5" : ""}`}>
      <p className="condensed text-base text-ash">{cell.planned}</p>
      <p className={`condensed text-base ${tone}`}>
        {cell.done.length === 0
          ? "Non fatto"
          : `${cell.done.length} serie${best?.loadKg ? `, max ${String(best.loadKg).replace(".", ",")} kg × ${best.reps ?? "?"}` : ""}`}
      </p>
    </td>
  );
}
