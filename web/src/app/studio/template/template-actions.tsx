"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui";
import { api } from "@/lib/api";

export function NewTemplateButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function create() {
    setBusy(true);
    try {
      const template = await api<{ id: string }>("/api/v1/programs", { body: { title: "Nuovo template", weeks: 4 } });
      router.push(`/studio/schede/${template.id}`);
    } catch (failure: unknown) {
      setError(failure instanceof Error ? failure.message : "Template non creato.");
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center gap-3">
      {error && <span className="text-sm text-alert">{error}</span>}
      <Button variant="primary" onClick={create} disabled={busy}>
        {busy ? "Creo…" : "Nuovo template"}
      </Button>
    </div>
  );
}

type Client = { id: string; name: string };

// Gives one client a draft copy of the template, ready to adapt and publish.
export function AssignTemplate({ templateId, clients }: { templateId: string; clients: Client[] }) {
  const [clientId, setClientId] = useState("");
  const [result, setResult] = useState<{ programId: string } | { error: string } | null>(null);
  const [busy, setBusy] = useState(false);

  if (clients.length === 0) return <span className="text-sm text-ash">Nessun cliente attivo da assegnare</span>;

  async function assign() {
    if (!clientId) return;
    setBusy(true);
    try {
      const [created] = await api<{ programId: string }[]>(`/api/v1/programs/${templateId}/assign`, {
        body: { clientIds: [clientId] },
      });
      setResult(created);
    } catch (failure: unknown) {
      setResult({ error: failure instanceof Error ? failure.message : "Assegnazione non riuscita." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <label htmlFor={`assign-${templateId}`} className="sr-only">
        Cliente
      </label>
      <select
        id={`assign-${templateId}`}
        value={clientId}
        onChange={(event) => setClientId(event.target.value)}
        className="min-h-11 rounded-[var(--radius-control)] border border-seam bg-graphite px-3 text-sm"
      >
        <option value="">Scegli un cliente</option>
        {clients.map((client) => (
          <option key={client.id} value={client.id}>
            {client.name}
          </option>
        ))}
      </select>
      <Button onClick={assign} disabled={!clientId || busy}>
        {busy ? "Assegno…" : "Assegna"}
      </Button>
      {result && "programId" in result && (
        <Link href={`/studio/schede/${result.programId}`} className="text-sm text-signal underline underline-offset-4">
          Apri la bozza
        </Link>
      )}
      {result && "error" in result && <span className="text-sm text-alert">{result.error}</span>}
    </div>
  );
}
