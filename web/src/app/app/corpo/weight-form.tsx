"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Input, Notice } from "@/components/ui";
import { pushMutations } from "@/lib/sync-queue";

// A weigh-in, sent like any synced record (and kept for later when offline).
export function WeightForm({ today }: { today: string }) {
  const router = useRouter();
  const [status, setStatus] = useState<{ tone: "success" | "error" | "info"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const value = Number(String(new FormData(formElement).get("weight")).replace(",", "."));
    if (!Number.isFinite(value) || value < 20 || value > 400) {
      return setStatus({ tone: "error", text: "Scrivi il peso in kg, per esempio 72,4." });
    }
    setBusy(true);
    setStatus(null);
    try {
      const outcome = await pushMutations([
        { entity: "body_measurement", op: "upsert", id: crypto.randomUUID(), data: { measuredOn: today, kind: "weight", value } },
      ]);
      if (typeof outcome === "object") throw new Error(outcome.rejected.join("; "));
      formElement.reset();
      if (outcome === "queued") setStatus({ tone: "info", text: "Sei offline: la pesata partirà appena torni online." });
      else router.refresh();
    } catch (failure: unknown) {
      setStatus({ tone: "error", text: failure instanceof Error ? failure.message : "Pesata non salvata." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <div className="flex gap-3">
        <label className="flex-1">
          <span className="sr-only">Peso di oggi in kg</span>
          <Input name="weight" inputMode="decimal" placeholder="Peso di oggi (kg)" className="condensed text-xl" required />
        </label>
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? "Salvo…" : "Salva"}
        </Button>
      </div>
      {status && <Notice tone={status.tone}>{status.text}</Notice>}
    </form>
  );
}
