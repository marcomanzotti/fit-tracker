import { MAX_WEEKS, type Prescription, type ProgramBlock, type ProgramDay, type ProgramDocument, type ProgramItem, type Progression } from "./document";
import { parsePrescription } from "./shorthand";

// Every change the program editor makes, as pure functions: they return a new
// document and never touch the old one, so undo and autosave stay simple.

export const newId = () => crypto.randomUUID().replaceAll("-", "").slice(0, 10);

const DEFAULT_PRESCRIPTION: Prescription = { sets: [{ type: "work", count: 3, reps: { min: 10, max: 10 } }] };

function mapDays(doc: ProgramDocument, fn: (day: ProgramDay) => ProgramDay): ProgramDocument {
  return { ...doc, days: doc.days.map(fn) };
}

function mapItems(doc: ProgramDocument, fn: (item: ProgramItem) => ProgramItem): ProgramDocument {
  return mapDays(doc, (day) => ({
    ...day,
    blocks: day.blocks.map((block) => ({ ...block, items: block.items.map(fn) })),
  }));
}

// Blocks left with no items disappear; a superset left with one item is a single.
function tidy(blocks: ProgramBlock[]): ProgramBlock[] {
  return blocks
    .filter((block) => block.items.length > 0)
    .map((block) => (block.items.length === 1 && block.type !== "single" ? { ...block, type: "single", rounds: undefined } : block));
}

// ---- Days ------------------------------------------------------------------

export function addDay(doc: ProgramDocument, label = `Giorno ${String.fromCharCode(65 + doc.days.length)}`): ProgramDocument {
  return { ...doc, days: [...doc.days, { id: newId(), label, blocks: [] }] };
}

export function renameDay(doc: ProgramDocument, dayId: string, label: string): ProgramDocument {
  return mapDays(doc, (day) => (day.id === dayId ? { ...day, label } : day));
}

export function removeDay(doc: ProgramDocument, dayId: string): ProgramDocument {
  return { ...doc, days: doc.days.filter((day) => day.id !== dayId) };
}

// Shrinking drops the overrides and phases past the new end.
export function setWeeks(doc: ProgramDocument, weeks: number): ProgramDocument {
  const length = Math.min(MAX_WEEKS, Math.max(1, Math.round(weeks)));
  const shrunk = mapItems({ ...doc, weeks: length }, (item) => ({
    ...item,
    overrides: Object.fromEntries(Object.entries(item.overrides).filter(([week]) => Number(week) <= length)),
  }));
  const phases = doc.phases
    .filter((phase) => phase.fromWeek <= length)
    .map((phase) => ({ ...phase, toWeek: Math.min(phase.toWeek, length) }));
  return { ...shrunk, phases };
}

// A deload week, toggled from the week's column header. Each deload week is its
// own phase, so toggling one never reshapes the others.
export function toggleDeload(doc: ProgramDocument, week: number): ProgramDocument {
  const covering = doc.phases.filter((phase) => phase.deload && week >= phase.fromWeek && week <= phase.toWeek);
  if (covering.length > 0) return { ...doc, phases: doc.phases.filter((phase) => !covering.includes(phase)) };
  return { ...doc, phases: [...doc.phases, { id: newId(), name: "Scarico", fromWeek: week, toWeek: week, deload: true }] };
}

// ---- Exercises -------------------------------------------------------------

export function addExercise(
  doc: ProgramDocument,
  dayId: string,
  exerciseId: string,
  base: Prescription = DEFAULT_PRESCRIPTION,
): ProgramDocument {
  const item: ProgramItem = { id: newId(), exerciseId, base, progression: { rule: "none" }, overrides: {} };
  const block: ProgramBlock = { id: newId(), type: "single", items: [item] };
  return mapDays(doc, (day) => (day.id === dayId ? { ...day, blocks: [...day.blocks, block] } : day));
}

export function removeItem(doc: ProgramDocument, itemId: string): ProgramDocument {
  return mapDays(doc, (day) => ({
    ...day,
    blocks: tidy(day.blocks.map((block) => ({ ...block, items: block.items.filter((item) => item.id !== itemId) }))),
  }));
}

export function moveBlock(doc: ProgramDocument, dayId: string, blockId: string, delta: -1 | 1): ProgramDocument {
  return mapDays(doc, (day) => {
    if (day.id !== dayId) return day;
    const from = day.blocks.findIndex((block) => block.id === blockId);
    const to = from + delta;
    if (from < 0 || to < 0 || to >= day.blocks.length) return day;
    const blocks = [...day.blocks];
    [blocks[from], blocks[to]] = [blocks[to], blocks[from]];
    return { ...day, blocks };
  });
}

// Superset: the block joins the one above it (A1/A2...).
export function linkWithPrevious(doc: ProgramDocument, dayId: string, blockId: string): ProgramDocument {
  return mapDays(doc, (day) => {
    if (day.id !== dayId) return day;
    const index = day.blocks.findIndex((block) => block.id === blockId);
    if (index <= 0) return day;
    const previous = day.blocks[index - 1];
    const merged: ProgramBlock = {
      ...previous,
      type: previous.type === "single" ? "superset" : previous.type,
      items: [...previous.items, ...day.blocks[index].items],
    };
    return { ...day, blocks: [...day.blocks.slice(0, index - 1), merged, ...day.blocks.slice(index + 1)] };
  });
}

// Takes an exercise out of its superset into its own block right after it.
export function unlinkItem(doc: ProgramDocument, itemId: string): ProgramDocument {
  return mapDays(doc, (day) => ({
    ...day,
    blocks: tidy(
      day.blocks.flatMap((block) => {
        const item = block.items.find((candidate) => candidate.id === itemId);
        if (!item || block.items.length === 1) return [block];
        const rest = { ...block, items: block.items.filter((candidate) => candidate.id !== itemId) };
        return [rest, { id: newId(), type: "single" as const, items: [item] }];
      }),
    ),
  }));
}

// ---- Cells -----------------------------------------------------------------

// Week 1 is the base prescription; any other week becomes a typed override.
// Clearing an override (null) goes back to what the progression rule computes.
export function setCell(doc: ProgramDocument, itemId: string, week: number, value: Prescription | null): ProgramDocument {
  return mapItems(doc, (item) => {
    if (item.id !== itemId) return item;
    if (week === 1) return value ? { ...item, base: value } : item;
    const overrides = Object.fromEntries(Object.entries(item.overrides).filter(([key]) => key !== String(week)));
    return { ...item, overrides: value ? { ...overrides, [String(week)]: value } : overrides };
  });
}

export function setProgression(doc: ProgramDocument, itemId: string, progression: Progression): ProgramDocument {
  return mapItems(doc, (item) => (item.id === itemId ? { ...item, progression } : item));
}

export function setItemDetails(
  doc: ProgramDocument,
  itemId: string,
  details: Partial<Pick<ProgramItem, "notes" | "restSec" | "tempo">>,
): ProgramDocument {
  return mapItems(doc, (item) => (item.id === itemId ? { ...item, ...details } : item));
}

export type PasteResult = { doc: ProgramDocument; errors: string[] };

// A block copied from Excel (tab-separated rows) pasted at a cell: rows go down
// the exercises of the day, columns across the weeks. Cells that do not parse
// are skipped and reported.
export function pasteGrid(doc: ProgramDocument, dayId: string, itemId: string, week: number, text: string): PasteResult {
  const day = doc.days.find((candidate) => candidate.id === dayId);
  const rows = day?.blocks.flatMap((block) => block.items) ?? [];
  const start = rows.findIndex((item) => item.id === itemId);
  if (start < 0) return { doc, errors: [] };

  const errors: string[] = [];
  let next = doc;
  const lines = text.replace(/\r/g, "").replace(/\n$/, "").split("\n");
  lines.forEach((line, rowOffset) => {
    const item = rows[start + rowOffset];
    if (!item) return;
    line.split("\t").forEach((cell, columnOffset) => {
      const targetWeek = week + columnOffset;
      if (targetWeek > doc.weeks || !cell.trim()) return;
      const parsed = parsePrescription(cell);
      if (parsed.ok) next = setCell(next, item.id, targetWeek, parsed.value);
      else errors.push(`Settimana ${targetWeek}, riga ${rowOffset + 1}: ${parsed.error}`);
    });
  });
  return { doc: next, errors };
}

// Rows as the grid shows them, with superset labels (A1, A2, B, ...).
export function rowsOf(day: ProgramDay) {
  return day.blocks.flatMap((block, blockIndex) => {
    const letter = String.fromCharCode(65 + blockIndex);
    return block.items.map((item, itemIndex) => ({
      block,
      item,
      label: block.items.length > 1 ? `${letter}${itemIndex + 1}` : letter,
      isFirstInBlock: itemIndex === 0,
      isLastInBlock: itemIndex === block.items.length - 1,
    }));
  });
}
