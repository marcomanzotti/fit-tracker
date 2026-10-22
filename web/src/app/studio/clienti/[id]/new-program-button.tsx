"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui";
import { api } from "@/lib/api";

// Creates an empty 4-week draft for the client and opens it in the editor.
export function NewProgramButton({ clientId }: { clientId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function create() {
    setBusy(true);
    setError(null);
    try {
      const program = await api<{ id: string }>("/api/v1/programs", { body: { clientId, title: "Nuova scheda", weeks: 4 } });
      router.push(`/studio/schede/${program.id}`);
    } catch (failure: unknown) {
      setError(failure instanceof Error ? failure.message : "Scheda non creata.");
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center gap-3">
      {error && <span className="text-sm text-alert">{error}</span>}
      <Button variant="primary" onClick={create} disabled={busy}>
        {busy ? "Creo…" : "Nuova scheda"}
      </Button>
    </div>
  );
}
