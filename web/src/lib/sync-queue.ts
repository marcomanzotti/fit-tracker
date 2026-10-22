import { api, ApiError } from "./api";

// Sends synced records (workouts, weigh-ins) to /api/v1/sync/push. In the gym the
// connection drops: when the request cannot reach the server, the mutations wait
// in this browser and go out on the next try (ADR-0002, same protocol as Android).

export type Mutation = { entity: "workout_session" | "body_measurement"; op: "upsert" | "delete"; id: string; data?: unknown };
type Result = { id: string; status: "ok" | "forbidden" | "invalid"; error?: string };

const KEY = "fittracker.outbox";

function readQueue(): Mutation[] {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? "[]") as Mutation[];
  } catch {
    return [];
  }
}

function writeQueue(queue: Mutation[]): void {
  try {
    if (queue.length === 0) localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, JSON.stringify(queue));
  } catch {
    // Storage unavailable (private mode): nothing can wait offline.
  }
}

export const pendingCount = () => readQueue().length;

// Pushes the queue plus `mutations`. Network trouble keeps everything queued
// (and resolves as "queued"); a server answer clears what it settled.
export async function pushMutations(mutations: Mutation[] = []): Promise<"sent" | "queued" | { rejected: string[] }> {
  // A newer version of the same record replaces the queued one.
  const ids = new Set(mutations.map((mutation) => mutation.id));
  const queue = [...readQueue().filter((mutation) => !ids.has(mutation.id)), ...mutations];
  if (queue.length === 0) return "sent";
  try {
    const { results } = await api<{ results: Result[] }>("/api/v1/sync/push", { body: { mutations: queue } });
    writeQueue([]);
    const rejected = results.filter((result) => result.status !== "ok").map((result) => result.error ?? result.status);
    return rejected.length > 0 ? { rejected } : "sent";
  } catch (failure: unknown) {
    if (failure instanceof ApiError && (failure.code === "network" || failure.code === "busy" || failure.status >= 500)) {
      writeQueue(queue);
      return "queued";
    }
    throw failure;
  }
}
