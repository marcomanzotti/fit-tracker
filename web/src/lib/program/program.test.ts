import { describe, expect, it } from "vitest";
import { emptyDocument, programDocumentSchema, type ProgramItem } from "./document";
import { estimateOneRepMax, isDeloadWeek, resolveItem, suggestedKg, weekOf } from "./resolve";
import { formatPrescription, parsePrescription } from "./shorthand";

const parse = (text: string) => {
  const result = parsePrescription(text);
  if (!result.ok) throw new Error(result.error);
  return result.value;
};

describe("parsePrescription", () => {
  it.each([
    ["4x8-10@RIR2", [{ type: "work", count: 4, reps: { min: 8, max: 10 }, load: { mode: "rir", value: 2 } }]],
    ["3x5@75%", [{ type: "work", count: 3, reps: { min: 5, max: 5 }, load: { mode: "pct1rm", value: 75 } }]],
    ["5 x 5 @ RPE 8,5", [{ type: "work", count: 5, reps: { min: 5, max: 5 }, load: { mode: "rpe", value: 8.5 } }]],
    ["4x10@22,5", [{ type: "work", count: 4, reps: { min: 10, max: 10 }, load: { mode: "kg", value: 22.5 } }]],
    ["3xAMRAP@BW", [{ type: "amrap", count: 3, load: { mode: "bw" } }]],
    ["3x30s", [{ type: "work", count: 3, seconds: 30 }]],
  ])("reads %s", (text, sets) => {
    expect(parse(text).sets).toEqual(sets);
  });

  it("reads warm-up, top set and back-off in one cell", () => {
    const { sets } = parse("w:2x5@40kg + 1x3@100kg + b:3x8@80kg");

    expect(sets.map((s) => s.type)).toEqual(["warmup", "work", "backoff"]);
    expect(sets.map((s) => s.load?.value)).toEqual([40, 100, 80]);
  });

  it.each([
    ["", /Scrivi serie/],
    ["tante", /non è valido/],
    ["4x8@pesante", /non riconosciuto/],
    ["50x8", /fuori scala/],
    ["4x10-8", /fuori scala/],
  ])("explains what is wrong with %j", (text, message) => {
    const result = parsePrescription(text);

    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(message);
  });

  it("round-trips through formatPrescription", () => {
    for (const text of ["4x8-10@RIR2", "3x5@75%", "4x10@22,5kg", "3xAMRAP@BW", "3x30s", "w:2x5@40kg + 1x3@100kg"]) {
      const once = formatPrescription(parse(text));
      expect(formatPrescription(parse(once))).toBe(once);
    }
    expect(formatPrescription(parse("4x10@22.5"))).toBe("4x10@22,5kg");
  });
});

const item = (overrides: Partial<ProgramItem> = {}): ProgramItem => ({
  id: "a1",
  exerciseId: "00000000-0000-4000-8000-000000000001",
  base: parse("4x8@80kg"),
  progression: { rule: "none" },
  overrides: {},
  ...overrides,
});

const deloadWeek4 = [{ id: "d", name: "Scarico", fromWeek: 4, toWeek: 4, deload: true }];

describe("resolveItem", () => {
  it("repeats week 1 without a progression rule", () => {
    expect(formatPrescription(resolveItem(item(), 3, []))).toBe("4x8@80kg");
  });

  it("adds load every week with a load rule", () => {
    const progressing = item({ progression: { rule: "load", step: 2.5 } });

    expect([1, 2, 3].map((w) => formatPrescription(resolveItem(progressing, w, [])))).toEqual([
      "4x8@80kg",
      "4x8@82,5kg",
      "4x8@85kg",
    ]);
  });

  it("adds reps every week with a reps rule", () => {
    const progressing = item({ base: parse("3x8-10@RIR2"), progression: { rule: "reps", step: 1 } });

    expect(formatPrescription(resolveItem(progressing, 3, []))).toBe("3x10-12@RIR2");
  });

  it("lightens deload weeks and resumes the progression after them", () => {
    const progressing = item({ progression: { rule: "load", step: 2.5 } });

    // Week 4 would be 87,5 kg: the deload keeps 60% of the sets at 90% of the load.
    expect(formatPrescription(resolveItem(progressing, 4, deloadWeek4))).toBe("2x8@79kg");
    expect(formatPrescription(resolveItem(progressing, 5, deloadWeek4))).toBe("4x8@87,5kg");
  });

  it("leaves warm-up sets alone and lets an override win as typed", () => {
    const withWarmup = item({
      base: parse("w:2x5@40kg + 4x8@80kg"),
      progression: { rule: "load", step: 5 },
      overrides: { "2": parse("5x5@90kg") },
    });

    expect(formatPrescription(resolveItem(withWarmup, 3, []))).toBe("w:2x5@40kg + 4x8@90kg");
    expect(formatPrescription(resolveItem(withWarmup, 2, []))).toBe("5x5@90kg");
  });

  it("knows deload weeks", () => {
    expect([3, 4].map((w) => isDeloadWeek(w, deloadWeek4))).toEqual([false, true]);
  });
});

describe("loads", () => {
  it("estimates 1RM with Epley and ignores unreliable sets", () => {
    expect(estimateOneRepMax(100, 1)).toBe(100);
    expect(estimateOneRepMax(100, 6)).toBeCloseTo(120);
    expect(estimateOneRepMax(100, 20)).toBeNull();
  });

  it("suggests kg from % of 1RM, RPE and RIR", () => {
    const [pct] = parse("3x5@75%").sets;
    const [rir] = parse("3x5@RIR2").sets;
    const [rpe] = parse("3x5@RPE8").sets;

    expect(suggestedKg(pct, 140)).toBe(105);
    // 140 / (1 + (5 reps + 2 in reserve) / 30)
    expect(suggestedKg(rir, 140)).toBe(113.5);
    expect(suggestedKg(rpe, 140)).toBe(suggestedKg(rir, 140));
    expect(suggestedKg(pct, null)).toBeNull();
  });
});

describe("weekOf", () => {
  it("counts weeks from the start date and stays within the program", () => {
    const doc = emptyDocument(8);

    expect(weekOf(doc, "2026-10-05", "2026-10-05")).toBe(1);
    expect(weekOf(doc, "2026-10-05", "2026-10-19")).toBe(3);
    expect(weekOf(doc, "2026-10-05", "2027-03-01")).toBe(8);
    expect(weekOf(doc, "2026-10-05", "2026-09-01")).toBe(1);
  });
});

describe("programDocumentSchema", () => {
  it("rejects phases and overrides outside the program, and duplicate ids", () => {
    const day = { id: "d1", label: "Spinta", blocks: [{ id: "b1", type: "single", items: [item({ overrides: { "9": parse("3x5") } })] }] };
    const result = programDocumentSchema.safeParse({
      schemaVersion: 1,
      weeks: 4,
      phases: [{ id: "p", name: "Forza", fromWeek: 3, toWeek: 6 }],
      days: [day, { ...day, id: "d2" }],
    });

    expect(result.success).toBe(false);
    const messages = result.error?.issues.map((issue) => issue.message).join("\n");
    expect(messages).toMatch(/outside the program/);
    expect(messages).toMatch(/week 9/);
    expect(messages).toMatch(/duplicate item id/);
  });
});
