import type { ProgramDocument, ProgramItem, ProgramPhase, Prescription, SetGroup } from "./document";

// Turns the document into concrete targets for a given week (ADR-0003). The
// server sends resolved weeks to the apps, so no prescription logic lives there.

const PROGRESSING: SetGroup["type"][] = ["work", "amrap", "backoff"];
const DELOAD_VOLUME = 0.6;
const DELOAD_INTENSITY = 0.9;
const KG_STEP = 0.5;
// Epley is reliable up to ~12 reps; beyond that a set says little about the 1RM.
const MAX_REPS_FOR_E1RM = 12;

const roundTo = (value: number, step: number) => Math.round(value / step) * step;

export function isDeloadWeek(week: number, phases: ProgramPhase[]): boolean {
  return phases.some((phase) => phase.deload && week >= phase.fromWeek && week <= phase.toWeek);
}

// Training weeks before `week`, not counting deloads: progression pauses during
// a deload and resumes from where it was.
function progressionSteps(week: number, phases: ProgramPhase[]): number {
  let steps = 0;
  for (let w = 1; w < week; w++) if (!isDeloadWeek(w, phases)) steps++;
  return steps;
}

function progress(group: SetGroup, item: ProgramItem, steps: number): SetGroup {
  const rule = item.progression;
  if (rule.rule === "none" || steps === 0 || !PROGRESSING.includes(group.type)) return group;
  if (rule.rule === "reps" && group.reps) {
    const shift = rule.step * steps;
    return { ...group, reps: { min: Math.max(0, group.reps.min + shift), max: Math.max(0, group.reps.max + shift) } };
  }
  if (rule.rule === "load" && group.load && (group.load.mode === "kg" || group.load.mode === "pct1rm")) {
    const value = Math.max(0, roundTo((group.load.value ?? 0) + rule.step * steps, KG_STEP));
    return { ...group, load: { ...group.load, value } };
  }
  return group;
}

function deload(group: SetGroup): SetGroup {
  const count = Math.max(1, Math.round(group.count * DELOAD_VOLUME));
  const load = group.load;
  if (!load || load.value === undefined || load.mode === "bw") return { ...group, count };
  if (load.mode === "rpe") return { ...group, count, load: { ...load, value: Math.max(1, load.value - 1) } };
  if (load.mode === "rir") return { ...group, count, load: { ...load, value: Math.min(10, load.value + 1) } };
  return { ...group, count, load: { ...load, value: roundTo(load.value * DELOAD_INTENSITY, KG_STEP) } };
}

// A PT's override for the week wins as typed; otherwise week 1 plus the rule,
// lightened in deload weeks.
export function resolveItem(item: ProgramItem, week: number, phases: ProgramPhase[]): Prescription {
  const override = item.overrides[String(week)];
  if (override) return override;
  const steps = progressionSteps(week, phases);
  const sets = item.base.sets.map((group) => progress(group, item, steps));
  return { sets: isDeloadWeek(week, phases) ? sets.map(deload) : sets };
}

export function isOverridden(item: ProgramItem, week: number): boolean {
  return item.overrides[String(week)] !== undefined;
}

// Epley estimated 1RM of one set, or null when the set cannot estimate it.
export function estimateOneRepMax(loadKg: number, reps: number): number | null {
  if (loadKg <= 0 || reps < 1 || reps > MAX_REPS_FOR_E1RM) return null;
  return reps === 1 ? loadKg : loadKg * (1 + reps / 30);
}

// Suggested kg for a set group from the client's e1RM: % of 1RM directly, RPE
// and RIR through Epley with the reps left in the tank. Null when unknown.
export function suggestedKg(group: SetGroup, e1rm: number | null): number | null {
  const load = group.load;
  if (!load || load.value === undefined) return null;
  if (load.mode === "kg") return load.value;
  if (!e1rm || load.mode === "bw") return null;
  if (load.mode === "pct1rm") return roundTo((e1rm * load.value) / 100, KG_STEP);
  const reps = group.reps?.max;
  if (!reps) return null;
  const inReserve = load.mode === "rir" ? load.value : 10 - load.value;
  return roundTo(e1rm / (1 + (reps + inReserve) / 30), KG_STEP);
}

// Program week for a calendar day, 1-based, clamped to the program length.
export function weekOf(doc: Pick<ProgramDocument, "weeks">, startDate: string, day: string): number {
  const days = (Date.parse(`${day}T00:00:00Z`) - Date.parse(`${startDate}T00:00:00Z`)) / 86_400_000;
  return Math.min(doc.weeks, Math.max(1, Math.floor(days / 7) + 1));
}
