import { randomUUID } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { PRIVACY_POLICY_VERSION } from "@/config";
import type { Database, Db } from "@/db/client";
import { freshDatabase, makeUser, META } from "@/test/harness";
import type { Actor } from "./actor";
import { setConsent } from "./consents";
import { pull, push } from "./sync";

let database: Database;
let db: Db;
let client: Actor;

beforeEach(async () => {
  database = await freshDatabase();
  db = database.db;
  client = await makeUser(db);
  await consentTo(client);
});

afterEach(async () => {
  await database.close();
});

async function consentTo(actor: Actor) {
  await setConsent(db, actor, { purpose: "health_processing", granted: true, policyVersion: PRIVACY_POLICY_VERSION }, META);
}

const weight = (value: number, measuredOn = "2026-10-20") => ({ measuredOn, kind: "weight", value });
const upsert = (id: string, data: unknown) => ({ entity: "body_measurement" as const, op: "upsert" as const, id, data });

describe("sync push", () => {
  it("stores new records with the id chosen by the device", async () => {
    const id = randomUUID();

    const results = await push(db, client, { mutations: [upsert(id, weight(82.4))] });
    const { changes } = await pull(db, client, {});

    expect(results).toEqual([{ id, status: "ok" }]);
    expect(changes).toEqual([
      expect.objectContaining({
        entity: "body_measurement",
        id,
        deleted: false,
        data: { measuredOn: "2026-10-20", kind: "weight", value: 82.4, source: "manual" },
      }),
    ]);
  });

  it("is idempotent: sending the same mutation twice keeps one record", async () => {
    const id = randomUUID();

    await push(db, client, { mutations: [upsert(id, weight(82))] });
    await push(db, client, { mutations: [upsert(id, weight(81.5))] });
    const { changes } = await pull(db, client, {});

    expect(changes).toHaveLength(1);
    expect(changes[0].data).toMatchObject({ value: 81.5 });
  });

  it("reports invalid data per mutation without dropping the valid ones", async () => {
    const good = randomUUID();
    const bad = randomUUID();

    const results = await push(db, client, {
      mutations: [upsert(good, weight(80)), upsert(bad, { measuredOn: "yesterday", kind: "weight", value: -1 })],
    });

    expect(results[0].status).toBe("ok");
    expect(results[1].status).toBe("invalid");
  });

  it("refuses to overwrite or delete another user's record", async () => {
    const id = randomUUID();
    await push(db, client, { mutations: [upsert(id, weight(80))] });
    const intruder = await makeUser(db);
    await consentTo(intruder);

    const results = await push(db, intruder, {
      mutations: [upsert(id, weight(50)), { entity: "body_measurement", op: "delete", id }],
    });
    const { changes } = await pull(db, client, {});

    expect(results.map((r) => r.status)).toEqual(["forbidden", "forbidden"]);
    expect(changes[0].data).toMatchObject({ value: 80 });
  });

  it("requires consent to health data processing", async () => {
    const newcomer = await makeUser(db);

    await expect(push(db, newcomer, { mutations: [upsert(randomUUID(), weight(70))] })).rejects.toMatchObject({
      code: "consent_required",
    });
  });
});

describe("sync pull", () => {
  it("returns deletions as tombstones after the cursor", async () => {
    const id = randomUUID();
    await push(db, client, { mutations: [upsert(id, weight(80))] });
    const first = await pull(db, client, {});

    await push(db, client, { mutations: [{ entity: "body_measurement", op: "delete", id }] });
    const second = await pull(db, client, { cursor: first.cursor });

    expect(second.changes).toEqual([expect.objectContaining({ id, deleted: true, data: null })]);
    expect(second.cursor).toBeGreaterThan(first.cursor);
  });

  it("pages through changes in rev order without gaps", async () => {
    const ids = Array.from({ length: 5 }, () => randomUUID());
    await push(db, client, { mutations: ids.map((id, i) => upsert(id, weight(70 + i, `2026-10-0${i + 1}`))) });

    const seen: string[] = [];
    let cursor = 0;
    let hasMore = true;
    while (hasMore) {
      const page = await pull(db, client, { cursor, limit: 2 });
      seen.push(...page.changes.map((change) => change.id));
      ({ cursor, hasMore } = page);
    }

    expect(seen).toEqual(ids);
  });

  it("only returns the caller's own data", async () => {
    await push(db, client, { mutations: [upsert(randomUUID(), weight(80))] });
    const other = await makeUser(db);

    const { changes } = await pull(db, other, {});

    expect(changes).toEqual([]);
  });

  it("never skips a change when pushes from two devices overlap", async () => {
    const batches = Array.from({ length: 6 }, (_, b) =>
      Array.from({ length: 5 }, (_, i) => upsert(randomUUID(), weight(60 + b + i / 10, `2026-09-${10 + b}`))),
    );
    let cursor = 0;
    const seen = new Set<string>();

    // Pulls run while the pushes are in flight; every pushed id must show up.
    await Promise.all([
      ...batches.map((mutations) => push(db, client, { mutations })),
      (async () => {
        for (let i = 0; i < 10; i++) {
          const page = await pull(db, client, { cursor });
          page.changes.forEach((change) => seen.add(change.id));
          cursor = page.cursor;
        }
      })(),
    ]);
    const rest = await pull(db, client, { cursor, limit: 1000 });
    rest.changes.forEach((change) => seen.add(change.id));

    expect(seen.size).toBe(30);
  });
});
