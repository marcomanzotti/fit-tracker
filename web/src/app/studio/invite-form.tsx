"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Field, Input, Notice } from "@/components/ui";
import { api } from "@/lib/api";
import { ROLE_LABEL } from "@/lib/labels";

// Invites a client to be followed in one of the professional's roles. The data
// they will share is the role's default set; they see it before consenting.
export function InviteForm({ disciplines }: { disciplines: string[] }) {
  const router = useRouter();
  const [status, setStatus] = useState<{ tone: "success" | "error"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  if (disciplines.length === 0) {
    return <p className="text-sm text-ash">Chiedi all&apos;admin dello studio di indicare il tuo ruolo per poter invitare clienti.</p>;
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const email = String(form.get("email"));
    setBusy(true);
    setStatus(null);
    try {
      await api("/api/v1/invitations", {
        body: { kind: "client", email, assignmentRole: String(form.get("role") ?? disciplines[0]) },
      });
      formElement.reset();
      setStatus({ tone: "success", text: `Invito mandato a ${email}.` });
      router.refresh();
    } catch (failure: unknown) {
      setStatus({ tone: "error", text: failure instanceof Error ? failure.message : "Invito non mandato." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-4">
      <Field label="Email del cliente" htmlFor="invite-email">
        <Input id="invite-email" name="email" type="email" autoComplete="off" required />
      </Field>
      {disciplines.length > 1 && (
        <Field label="Lo segui come" htmlFor="invite-role">
          <select id="invite-role" name="role" className="min-h-11 rounded-[var(--radius-control)] border border-seam bg-graphite px-3">
            {disciplines.map((discipline) => (
              <option key={discipline} value={discipline}>
                {ROLE_LABEL[discipline] ?? discipline}
              </option>
            ))}
          </select>
        </Field>
      )}
      {status && <Notice tone={status.tone}>{status.text}</Notice>}
      <Button variant="primary" type="submit" disabled={busy}>
        {busy ? "Mando…" : "Manda invito"}
      </Button>
    </form>
  );
}
