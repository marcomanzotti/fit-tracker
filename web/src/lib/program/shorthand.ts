import { prescriptionSchema, type Prescription, type SetGroup, type SetType } from "./document";

// The spreadsheet-cell language of the program editor, so a PT types what they
// would write in Excel:
//   4x8-10@RIR2     4 sets of 8-10 reps, 2 reps in reserve
//   3x5@75%         % of 1RM          5x5@RPE8      RPE
//   4x10@22,5       kg (unit optional, comma or dot)   3xAMRAP@BW   bodyweight
//   3x30s           timed sets
//   w:2x5@40kg + 1x3@100kg + b:3x8@80kg   warm-up, top set, back-off
// Prefixes: w: or r: warm-up (riscaldamento), b: back-off, d: drop set.

export type ParseResult = { ok: true; value: Prescription } | { ok: false; error: string };

const PREFIXES: Record<string, SetType> = { w: "warmup", r: "warmup", b: "backoff", d: "drop" };
const PREFIX_OF: Partial<Record<SetType, string>> = { warmup: "w:", backoff: "b:", drop: "d:" };
const PART = /^(?:([wrbd])\s*:\s*)?(\d{1,2})\s*[x×]\s*(amrap|max|\d{1,3}(?:\s*-\s*\d{1,3})?|\d{1,4}\s*s)(?:\s*@\s*(.+))?$/i;
const EXAMPLE = "es. 4x8-10@RIR2, 3x5@75%, 3x30s";

const toNumber = (text: string) => Number(text.replace(",", "."));

function parseLoad(text: string): SetGroup["load"] | string {
  const value = text.trim();
  let match: RegExpMatchArray | null;
  if ((match = value.match(/^(\d+(?:[.,]\d+)?)\s*%$/))) return { mode: "pct1rm", value: toNumber(match[1]) };
  if ((match = value.match(/^rpe\s*(\d+(?:[.,]5)?)$/i))) return { mode: "rpe", value: toNumber(match[1]) };
  if ((match = value.match(/^rir\s*(\d+)$/i))) return { mode: "rir", value: toNumber(match[1]) };
  if (/^(bw|pc|corpo\s*libero)$/i.test(value)) return { mode: "bw" };
  if ((match = value.match(/^(\d+(?:[.,]\d+)?)\s*(kg)?$/i))) return { mode: "kg", value: toNumber(match[1]) };
  return `Carico "${value}" non riconosciuto (kg, %, RPE, RIR o BW)`;
}

function parsePart(text: string): SetGroup | string {
  const match = text.trim().match(PART);
  if (!match) return `"${text.trim()}" non è valido (${EXAMPLE})`;
  const [, prefix, count, repsText, loadText] = match;
  const group: SetGroup = { type: prefix ? PREFIXES[prefix.toLowerCase()] : "work", count: Number(count) };

  const reps = repsText.replace(/\s/g, "").toLowerCase();
  if (reps === "amrap" || reps === "max") {
    group.type = "amrap";
  } else if (reps.endsWith("s")) {
    group.seconds = Number(reps.slice(0, -1));
  } else {
    const [min, max = min] = reps.split("-").map(Number);
    group.reps = { min, max };
  }

  if (loadText) {
    const load = parseLoad(loadText);
    if (typeof load === "string") return load;
    group.load = load;
  }
  return group;
}

export function parsePrescription(text: string): ParseResult {
  if (!text.trim()) return { ok: false, error: `Scrivi serie e ripetizioni (${EXAMPLE})` };
  const sets: SetGroup[] = [];
  for (const part of text.split("+")) {
    const parsed = parsePart(part);
    if (typeof parsed === "string") return { ok: false, error: parsed };
    sets.push(parsed);
  }
  const checked = prescriptionSchema.safeParse({ sets });
  if (!checked.success) return { ok: false, error: "Valori fuori scala (serie 1-20, ripetizioni 0-100, RPE 1-10)" };
  return { ok: true, value: checked.data };
}

const formatNumber = (value: number) => String(value).replace(".", ",");

function formatLoad(load: SetGroup["load"]): string {
  if (!load) return "";
  switch (load.mode) {
    case "kg":
      return `@${formatNumber(load.value ?? 0)}kg`;
    case "pct1rm":
      return `@${formatNumber(load.value ?? 0)}%`;
    case "rpe":
      return `@RPE${formatNumber(load.value ?? 0)}`;
    case "rir":
      return `@RIR${load.value ?? 0}`;
    case "bw":
      return "@BW";
  }
}

function formatGroup(group: SetGroup): string {
  const prefix = PREFIX_OF[group.type] ?? "";
  let reps = "AMRAP";
  if (group.seconds) reps = `${group.seconds}s`;
  else if (group.reps) reps = group.reps.min === group.reps.max ? `${group.reps.min}` : `${group.reps.min}-${group.reps.max}`;
  return `${prefix}${group.count}x${reps}${formatLoad(group.load)}`;
}

// The inverse of parsePrescription: what the editor shows in a cell.
export function formatPrescription(prescription: Prescription): string {
  return prescription.sets.map(formatGroup).join(" + ");
}
