"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Field, Input, Notice } from "@/components/ui";
import { authClient } from "@/lib/auth-client";
import { safeNext } from "@/lib/navigation";

const MIN_PASSWORD = 10;

const SIGN_UP_ERRORS: Record<string, string> = {
  PASSWORD_TOO_SHORT: `La password deve avere almeno ${MIN_PASSWORD} caratteri.`,
  INVALID_EMAIL: "Questo indirizzo email non è valido.",
  TOO_MANY_REQUESTS: "Troppi tentativi: aspetta qualche secondo.",
};

export function SignUpForm() {
  const params = useSearchParams();
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const email = String(form.get("email"));
    const next = safeNext(params.get("next"), "");
    setBusy(true);
    setError(null);
    // The verification link brings the person back to sign-in (and then to `next`).
    const { error: failure } = await authClient.signUp.email({
      name: String(form.get("name")),
      email,
      password: String(form.get("password")),
      callbackURL: `/accedi?verificata=1${next ? `&next=${encodeURIComponent(next)}` : ""}`,
    });
    setBusy(false);
    if (failure) return setError((failure.code && SIGN_UP_ERRORS[failure.code]) || "Registrazione non riuscita. Riprova.");
    setSentTo(email);
  }

  if (sentTo) {
    return (
      <Notice tone="success">
        Ti abbiamo mandato un link a {sentTo}. Aprilo per confermare l&apos;email, poi accedi.
      </Notice>
    );
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-5">
      <Field label="Nome e cognome" htmlFor="name">
        <Input id="name" name="name" autoComplete="name" required maxLength={80} />
      </Field>
      <Field label="Email" htmlFor="email">
        <Input id="email" name="email" type="email" autoComplete="email" required />
      </Field>
      <Field label="Password" htmlFor="password" hint={`Almeno ${MIN_PASSWORD} caratteri.`} error={error}>
        <Input id="password" name="password" type="password" autoComplete="new-password" minLength={MIN_PASSWORD} required />
      </Field>
      <Button variant="primary" type="submit" disabled={busy}>
        {busy ? "Creo l'account…" : "Crea account"}
      </Button>
      <p className="text-sm text-ash">
        Hai già un account?{" "}
        <Link href="/accedi" className="text-chalk underline underline-offset-4">
          Accedi
        </Link>
      </p>
    </form>
  );
}
