import { describe, expect, it } from "vitest";
import { emptyDocument, programDocumentSchema, type ProgramDocument } from "./document";
import {
  addDay,
  addExercise,
  linkWithPrevious,
  moveBlock,
  pasteGrid,
  removeItem,
  rowsOf,
  setCell,
  setWeeks,
  toggleDeload,
  unlinkItem,
} from "./edit";
import { isDeloadWeek, resolveItem } from "./resolve";
import { formatPrescription, parsePrescription } from "./shorthand";

const SQUAT = "00000000-0000-4000-8000-000000000001";
const BENCH = "00000000-0000-4000-8000-000000000002";
const ROW = "00000000-0000-4000-8000-000000000003";

const cell = (text: string) => {
  const parsed = parsePrescription(text);
  if (!parsed.ok) throw new Error(parsed.error);
  return parsed.value;
};

function dayWithThree(): ProgramDocument {
  let doc = addDay(emptyDocument(4));
  const dayId = doc.days[0].id;
  for (const exercise of [SQUAT, BENCH, ROW]) doc = addExercise(doc, dayId, exercise);
  return doc;
}

const items = (doc: ProgramDocument) => rowsOf(doc.days[0]).map((row) => row.item);

describe("program edits", () => {
  it("build a valid document and never change the one they receive", () => {
    const before = emptyDocument(4);
    const withDay = addDay(before);
    const after = addExercise(withDay, withDay.days[0].id, SQUAT);

    expect(before.days).toEqual([]);
    expect(withDay.days[0].blocks).toEqual([]);
    expect(after.days[0].blocks).toHaveLength(1);
    expect(programDocumentSchema.safeParse(dayWithThree()).success).toBe(true);
  });

  it("names days A, B, C and labels supersets A1/A2", () => {
    let doc = dayWithThree();
    const [, second] = doc.days[0].blocks;
    doc = linkWithPrevious(doc, doc.days[0].id, second.id);

    expect(doc.days[0].label).toBe("Giorno A");
    expect(rowsOf(doc.days[0]).map((row) => row.label)).toEqual(["A1", "A2", "B"]);
    expect(doc.days[0].blocks[0].type).toBe("superset");
  });

  it("turns a superset back into singles when an exercise leaves it", () => {
    let doc = dayWithThree();
    doc = linkWithPrevious(doc, doc.days[0].id, doc.days[0].blocks[1].id);
    const bench = items(doc)[1];

    const unlinked = unlinkItem(doc, bench.id);
    const removed = removeItem(doc, bench.id);

    expect(rowsOf(unlinked.days[0]).map((row) => row.label)).toEqual(["A", "B", "C"]);
    expect(removed.days[0].blocks[0].type).toBe("single");
  });

  it("moves blocks up and down within the day", () => {
    const doc = dayWithThree();
    const moved = moveBlock(doc, doc.days[0].id, doc.days[0].blocks[2].id, -1);

    expect(items(moved).map((item) => item.exerciseId)).toEqual([SQUAT, ROW, BENCH]);
  });

  it("writes week 1 as the base and later weeks as overrides that can be cleared", () => {
    let doc = dayWithThree();
    const squat = items(doc)[0];

    doc = setCell(doc, squat.id, 1, cell("5x5@80kg"));
    doc = setCell(doc, squat.id, 3, cell("3x3@90kg"));
    const [edited] = items(doc);
    const cleared = items(setCell(doc, squat.id, 3, null))[0];

    expect(formatPrescription(edited.base)).toBe("5x5@80kg");
    expect(formatPrescription(resolveItem(edited, 3, []))).toBe("3x3@90kg");
    expect(formatPrescription(resolveItem(cleared, 3, []))).toBe("5x5@80kg");
  });

  it("drops overrides beyond the end when the program gets shorter", () => {
    let doc = dayWithThree();
    const squat = items(doc)[0];
    doc = setCell(doc, squat.id, 4, cell("1x1@100kg"));

    const shorter = setWeeks(doc, 3);

    expect(shorter.weeks).toBe(3);
    expect(items(shorter)[0].overrides).toEqual({});
  });

  it("toggles a deload week on and off", () => {
    const on = toggleDeload(dayWithThree(), 4);
    const off = toggleDeload(on, 4);

    expect(isDeloadWeek(4, on.phases)).toBe(true);
    expect(isDeloadWeek(3, on.phases)).toBe(false);
    expect(off.phases).toEqual([]);
  });

  it("pastes a block copied from Excel across weeks and rows, reporting bad cells", () => {
    const doc = dayWithThree();
    const [squat, bench, row] = items(doc);

    const { doc: pasted, errors } = pasteGrid(
      doc,
      doc.days[0].id,
      squat.id,
      1,
      "5x5@80kg\t5x5@82,5kg\t5x5@85kg\n4x8@60kg\tboh\n3x10@BW\n",
    );

    const after = items(pasted);
    expect(formatPrescription(after[0].base)).toBe("5x5@80kg");
    expect(formatPrescription(resolveItem(after[0], 3, []))).toBe("5x5@85kg");
    expect(after[1].id).toBe(bench.id);
    expect(formatPrescription(after[1].base)).toBe("4x8@60kg");
    expect(formatPrescription(after[2].base)).toBe("3x10@BW");
    expect(after[2].id).toBe(row.id);
    expect(errors).toEqual([expect.stringMatching(/^Settimana 2, riga 2:/)]);
  });
});
