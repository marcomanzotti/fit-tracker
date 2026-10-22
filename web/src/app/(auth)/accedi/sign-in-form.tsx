"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Field, Input, Notice } from "@/components/ui";
import { api, ApiError } from "@/lib/api";
import { authClient } from "@/lib/auth-client";
import { safeNext } from "@/lib/navigation";

const AUTH_ERRORS: Record<string, string> = {
  INVALID_EMAIL_OR_PASSWORD: "Email o password non corretti.",
  EMAIL_NOT_VERIFIED: "Conferma prima la tua email: ti abbiamo rimandato il link.",
  INVALID_CODE: "Codice non valido: controlla l'app di autenticazione e riprova.",
  TOO_MANY_REQUESTS: "Troppi tentativi: aspetta qualche secondo.",
};

const authMessage = (code?: string) => (code && AUTH_ERRORS[code]) || "Accesso non riuscito. Riprova.";

export function SignInForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [step, setStep] = useState<"password" | "code">("password");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Staff land in the studio, clients in the app, unless a page sent them here.
  async function goHome() {
    const next = params.get("next");
    try {
      const me = await api<{ user: { role: string } }>("/api/v1/me");
      const home = me.user.role === "client" ? "/app" : "/studio";
      router.replace(safeNext(next, home));
    } catch (failure: unknown) {
      if (failure instanceof ApiError && failure.code === "two_factor_required") router.replace("/studio/sicurezza");
      else setError(failure instanceof Error ? failure.message : authMessage());
    }
  }

  async function submitPassword(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setBusy(true);
    setError(null);
    const { data, error: failure } = await authClient.signIn.email({
      email: String(form.get("email")),
      password: String(form.get("password")),
    });
    setBusy(false);
    if (failure) return setError(authMessage(failure.code));
    if (data && "twoFactorRedirect" in data && data.twoFactorRedirect) return setStep("code");
    await goHome();
  }

  async function submitCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setBusy(true);
    setError(null);
    const { error: failure } = await authClient.twoFactor.verifyTotp({ code: String(form.get("code")) });
    setBusy(false);
    if (failure) return setError(authMessage(failure.code));
    await goHome();
  }

  if (step === "code") {
    return (
      <form onSubmit={submitCode} className="flex flex-col gap-5">
        <p className="text-ash">Inserisci il codice a 6 cifre della tua app di autenticazione.</p>
        <Field label="Codice" htmlFor="code" error={error}>
          <Input id="code" name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required autoFocus />
        </Field>
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? "Verifico…" : "Verifica"}
        </Button>
      </form>
    );
  }

  return (
    <form onSubmit={submitPassword} className="flex flex-col gap-5">
      {params.get("verificata") && <Notice tone="success">Email confermata. Ora puoi accedere.</Notice>}
      <Field label="Email" htmlFor="email">
        <Input id="email" name="email" type="email" autoComplete="email" required />
      </Field>
      <Field label="Password" htmlFor="password" error={error}>
        <Input id="password" name="password" type="password" autoComplete="current-password" required />
      </Field>
      <Button variant="primary" type="submit" disabled={busy}>
        {busy ? "Accedo…" : "Accedi"}
      </Button>
      <p className="text-sm text-ash">
        Non hai un account?{" "}
        <Link href={`/registrati${params.get("next") ? `?next=${encodeURIComponent(params.get("next") ?? "")}` : ""}`} className="text-chalk underline underline-offset-4">
          Registrati
        </Link>
      </p>
    </form>
  );
}
