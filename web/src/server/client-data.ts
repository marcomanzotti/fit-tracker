import { and, asc, desc, eq, gte, isNull, lte } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "@/db/client";
import { bodyMeasurement, workoutSession } from "@/db/schema";
import { withClientAccess } from "./access";
import type { Actor } from "./actor";
import { readSessions } from "./sessions";
import { parseWith } from "./validate";

// A client's data as the client or one of their professionals reads it. Every
// function goes through withClientAccess with the scope the data belongs to.

export const rangeInput = z.object({
  from: z.iso.date().optional(),
  to: z.iso.date().optional(),
});

const MAX_SESSIONS = 200;

export async function listBodyMeasurements(
  db: Db,
  actor: Actor,
  clientId: string,
  raw: unknown,
  ipAddress: string | null,
) {
  const { from, to } = parseWith(rangeInput, raw);
  return withClientAccess(db, actor, clientId, { scope: "body", resource: "body_measurement", ipAddress }, (tx) =>
    tx
      .select({
        id: bodyMeasurement.id,
        measuredOn: bodyMeasurement.measuredOn,
        kind: bodyMeasurement.kind,
        value: bodyMeasurement.value,
        source: bodyMeasurement.source,
      })
      .from(bodyMeasurement)
      .where(
        and(
          eq(bodyMeasurement.userId, clientId),
          isNull(bodyMeasurement.deletedAt),
          from ? gte(bodyMeasurement.measuredOn, from) : undefined,
          to ? lte(bodyMeasurement.measuredOn, to) : undefined,
        ),
      )
      .orderBy(asc(bodyMeasurement.measuredOn)),
  );
}

// Logged workouts with exercises and sets, newest first.
export async function listSessions(
  db: Db,
  actor: Actor,
  clientId: string,
  raw: unknown,
  ipAddress: string | null,
) {
  const { from, to } = parseWith(rangeInput, raw);
  return withClientAccess(db, actor, clientId, { scope: "training", resource: "workout_session", ipAddress }, async (tx) => {
    const rows = await tx
      .select({ id: workoutSession.id })
      .from(workoutSession)
      .where(
        and(
          eq(workoutSession.userId, clientId),
          isNull(workoutSession.deletedAt),
          from ? gte(workoutSession.localDay, from) : undefined,
          to ? lte(workoutSession.localDay, to) : undefined,
        ),
      )
      .orderBy(desc(workoutSession.localDay))
      .limit(MAX_SESSIONS);
    return readSessions(
      tx,
      rows.map((row) => row.id),
    );
  });
}
