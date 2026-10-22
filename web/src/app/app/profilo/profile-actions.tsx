"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Field, Input, Notice } from "@/components/ui";
import { PRIVACY_POLICY_VERSION } from "@/config";
import { api } from "@/lib/api";
import { authClient } from "@/lib/auth-client";

type Purpose = "health_processing" | "aggregate_insights" | "marketing";

export function ConsentToggle({ purpose, granted, label, hint }: { purpose: Purpose; granted: boolean; label: string; hint: string }) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function toggle() {
    setBusy(true);
    setError(null);
    try {
      await api("/api/v1/me/consents", { body: { purpose, granted: !granted, policyVersion: PRIVACY_POLICY_VERSION } });
      router.refresh();
    } catch (failure: unknown) {
      setError(failure instanceof Error ? failure.message : "Non salvato.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex items-start justify-between gap-4">
      <div>
        <p className="font-medium">{label}</p>
        <p className="text-sm text-ash">{hint}</p>
        {error && <p className="text-sm text-alert">{error}</p>}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={granted}
        aria-label={label}
        onClick={toggle}
        disabled={busy}
        className="relative mt-1 h-7 w-12 shrink-0 rounded-full border border-seam bg-steel transition-colors aria-checked:border-go aria-checked:bg-go disabled:opacity-50"
      >
        <span
          aria-hidden
          className={`absolute top-0.5 left-0.5 size-5.5 rounded-full bg-chalk transition-transform ${granted ? "translate-x-5" : "translate-x-0"}`}
        />
      </button>
    </div>
  );
}

// Accept or decline a professional proposed by the studio, or stop being followed.
export function CareActions({ assignmentId, status, name }: { assignmentId: string; status: string; name: string }) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);

  async function run(path: string, body: unknown) {
    setError(null);
    try {
      await api(`/api/v1/assignments/${assignmentId}/${path}`, { body });
      router.refresh();
    } catch (failure: unknown) {
      setError(failure instanceof Error ? failure.message : "Operazione non riuscita.");
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      {status === "pending" ? (
        <>
          <Button variant="primary" onClick={() => run("respond", { accept: true, policyVersion: PRIVACY_POLICY_VERSION })}>
            Accetta {name}
          </Button>
          <Button onClick={() => run("respond", { accept: false, policyVersion: PRIVACY_POLICY_VERSION })}>Rifiuta</Button>
        </>
      ) : (
        <button type="button" onClick={() => run("end", {})} className="text-sm text-ash hover:text-alert">
          Smetti di condividere i dati con {name}
        </button>
      )}
      {error && <span className="text-sm text-alert">{error}</span>}
    </div>
  );
}

export function SignOut() {
  const router = useRouter();
  return (
    <Button
      onClick={async () => {
        await authClient.signOut();
        router.replace("/accedi");
      }}
    >
      Esci
    </Button>
  );
}

// GDPR erasure: everything goes, after the password confirms it is really you.
export function DeleteAccount() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function confirm(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    const password = String(new FormData(event.currentTarget).get("password"));
    const { error: failure } = await authClient.deleteUser({ password });
    setBusy(false);
    if (failure) return setError(failure.code === "INVALID_PASSWORD" ? "Password non corretta." : "Account non cancellato. Riprova.");
    router.replace("/");
  }

  if (!open) {
    return (
      <Button variant="danger" onClick={() => setOpen(true)}>
        Cancella il mio account
      </Button>
    );
  }

  return (
    <form onSubmit={confirm} className="flex flex-col gap-4 rounded-[var(--radius-panel)] border border-alert/50 p-4">
      <Notice tone="error">
        Cancelli l&apos;account e tutti i dati: allenamenti, misure, consensi. Non si può annullare. Se vuoi una copia,
        scaricala prima dal riquadro Privacy.
      </Notice>
      <Field label="Conferma con la password" htmlFor="delete-password" error={error}>
        <Input id="delete-password" name="password" type="password" autoComplete="current-password" required />
      </Field>
      <div className="flex gap-3">
        <Button variant="danger" type="submit" disabled={busy}>
          {busy ? "Cancello…" : "Cancella definitivamente"}
        </Button>
        <Button type="button" onClick={() => setOpen(false)}>
          Annulla
        </Button>
      </div>
    </form>
  );
}
