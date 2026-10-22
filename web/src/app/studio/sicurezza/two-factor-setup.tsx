"use client";

import QRCode from "qrcode";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Field, Input, Notice } from "@/components/ui";
import { authClient } from "@/lib/auth-client";

type Enrollment = { qr: string; uri: string; backupCodes: string[] };

// Staff read health data, so the studio requires a second factor: an
// authenticator app (TOTP). Three steps: password, scan the QR code, confirm a code.
export function TwoFactorSetup() {
  const router = useRouter();
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function start(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const password = String(new FormData(event.currentTarget).get("password"));
    setBusy(true);
    setError(null);
    const { data, error: failure } = await authClient.twoFactor.enable({ password });
    if (failure || !data || data.method !== "totp") {
      setBusy(false);
      return setError(failure?.code === "INVALID_PASSWORD" ? "Password non corretta." : "Non è stato possibile iniziare. Riprova.");
    }
    const qr = await QRCode.toDataURL(data.totpURI, { margin: 1, width: 220, color: { dark: "#0b0b0d", light: "#f4efe6" } });
    setEnrollment({ qr, uri: data.totpURI, backupCodes: data.backupCodes });
    setBusy(false);
  }

  async function confirm(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const code = String(new FormData(event.currentTarget).get("code"));
    setBusy(true);
    setError(null);
    const { error: failure } = await authClient.twoFactor.verifyTotp({ code });
    setBusy(false);
    if (failure) return setError("Codice non valido: controlla l'ora del telefono e riprova.");
    setDone(true);
  }

  if (done && enrollment) {
    return (
      <div className="flex flex-col gap-5">
        <Notice tone="success">Verifica in due passaggi attiva.</Notice>
        <p>
          Conserva questi codici di emergenza in un posto sicuro: ognuno vale una volta se perdi il telefono.
        </p>
        <ul className="condensed grid grid-cols-2 gap-2 text-lg">
          {enrollment.backupCodes.map((code) => (
            <li key={code} className="rounded-[var(--radius-control)] border border-seam px-3 py-2">
              {code}
            </li>
          ))}
        </ul>
        <Button variant="primary" onClick={() => router.replace("/studio")}>
          Vai ai clienti
        </Button>
      </div>
    );
  }

  if (enrollment) {
    return (
      <form onSubmit={confirm} className="flex flex-col gap-5">
        <p>Inquadra il codice con un&apos;app di autenticazione (per esempio Google Authenticator, 1Password o Authy).</p>
        {/* eslint-disable-next-line @next/next/no-img-element -- generated data URL, nothing to optimize */}
        <img src={enrollment.qr} alt="Codice QR per l'app di autenticazione" width={220} height={220} className="rounded-[var(--radius-control)]" />
        <a href={enrollment.uri} className="text-sm text-ash underline underline-offset-4">
          Sul telefono? Apri direttamente nell&apos;app
        </a>
        <Field label="Codice a 6 cifre" htmlFor="code" error={error}>
          <Input id="code" name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required autoFocus />
        </Field>
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? "Verifico…" : "Attiva"}
        </Button>
      </form>
    );
  }

  return (
    <form onSubmit={start} className="flex flex-col gap-5">
      <p className="text-ash">
        Per vedere i dati dei clienti serve la verifica in due passaggi: oltre alla password, un codice dall&apos;app
        di autenticazione del tuo telefono.
      </p>
      <Field label="Conferma la password" htmlFor="password" error={error}>
        <Input id="password" name="password" type="password" autoComplete="current-password" required />
      </Field>
      <Button variant="primary" type="submit" disabled={busy}>
        {busy ? "Preparo…" : "Inizia"}
      </Button>
    </form>
  );
}
