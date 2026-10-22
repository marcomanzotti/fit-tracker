"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore, type ReactNode } from "react";
import { Button, Loading, Notice } from "@/components/ui";
import { PRIVACY_POLICY_VERSION } from "@/config";
import { api } from "@/lib/api";
import { authClient } from "@/lib/auth-client";
import { listItalian, ROLE_LABEL, SCOPE_LABEL } from "@/lib/labels";

type Preview = {
  kind: "staff" | "admin" | "client";
  email: string | null;
  inviterName: string;
  assignmentRole: string | null;
  scopes: string[] | null;
  status: "valid" | "accepted" | "revoked" | "expired";
};

// The token arrives after "#" (never sent to the server in a URL). It is kept for
// this tab so the person can sign up or sign in and come back to this page.
const STORAGE_KEY = "fittracker.invitation";

function readToken(): string {
  const fromLink = window.location.hash.slice(1);
  try {
    return fromLink || sessionStorage.getItem(STORAGE_KEY) || "";
  } catch {
    return fromLink;
  }
}

function keepToken(token: string): void {
  try {
    sessionStorage.setItem(STORAGE_KEY, token);
  } catch {
    // Storage unavailable (private mode): the link itself still works.
  }
}

const onHashChange = (notify: () => void) => {
  window.addEventListener("hashchange", notify);
  return () => window.removeEventListener("hashchange", notify);
};
const noSubscription = () => () => {};

function forgetToken(): void {
  try {
    sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    // Storage unavailable (private mode): nothing was kept.
  }
}

const STATUS_MESSAGE: Record<Exclude<Preview["status"], "valid">, string> = {
  accepted: "Questo invito è già stato usato. Accedi con il tuo account.",
  revoked: "Questo invito è stato annullato. Chiedi al tuo studio di mandartene un altro.",
  expired: "Questo invito è scaduto. Chiedi al tuo studio di mandartene un altro.",
};

const LINK_PRIMARY =
  "inline-flex min-h-11 items-center rounded-[var(--radius-control)] bg-signal px-4 text-sm font-semibold text-ink";
const LINK_QUIET =
  "inline-flex min-h-11 items-center rounded-[var(--radius-control)] border border-seam bg-steel px-4 text-sm font-semibold";

export function InvitationFlow() {
  const router = useRouter();
  const session = authClient.useSession();
  // The fragment and session storage exist only in the browser.
  const token = useSyncExternalStore(onHashChange, readToken, () => "");
  const inBrowser = useSyncExternalStore(noSubscription, () => true, () => false);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [agreed, setAgreed] = useState({ health: false, sharing: false });
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!token) return;
    keepToken(token);
    api<Preview>("/api/v1/invitations/preview", { body: { token } })
      .then(setPreview)
      .catch((failure: Error) => setError(failure.message));
  }, [token]);

  async function accept() {
    if (!preview) return;
    setBusy(true);
    setError(null);
    const consent =
      preview.kind === "client"
        ? { policyVersion: PRIVACY_POLICY_VERSION, healthProcessing: true, staffSharing: agreed.sharing }
        : undefined;
    try {
      await api("/api/v1/invitations/accept", { body: { token, consent } });
      forgetToken();
      // Staff set up two-factor authentication before reaching any client data.
      router.replace(preview.kind === "client" ? "/app" : "/studio/sicurezza");
    } catch (failure: unknown) {
      setError(failure instanceof Error ? failure.message : "Non è stato possibile accettare l'invito.");
      setBusy(false);
    }
  }

  if (inBrowser && !token) {
    return <Notice tone="error">Il link dell&apos;invito è incompleto. Aprilo di nuovo dalla mail.</Notice>;
  }
  if (error && !preview) return <Notice tone="error">{error}</Notice>;
  if (!preview || session.isPending) return <Loading />;
  if (preview.status !== "valid") return <Notice>{STATUS_MESSAGE[preview.status]}</Notice>;

  const role = preview.assignmentRole ? ROLE_LABEL[preview.assignmentRole] : null;
  const scopes = (preview.scopes ?? []).map((scope) => SCOPE_LABEL[scope] ?? scope);
  const isClient = preview.kind === "client";
  const canAccept = !isClient || (agreed.health && (!role || agreed.sharing));

  let title = `${preview.inviterName} ti invita nello studio`;
  let intro = preview.kind === "admin" ? "Avrai accesso alla gestione dello studio." : "Entrerai come professionista dello studio.";
  if (isClient) {
    title = role ? `${preview.inviterName} ti segue` : `${preview.inviterName} ti invita`;
    intro = role
      ? `Come ${role}, potrà vedere ${listItalian(scopes)} e preparare le tue schede.`
      : "Potrai registrare allenamenti, misure e alimentazione.";
  }

  return (
    <section className="flex flex-col gap-8">
      <div className="flex flex-col gap-3">
        <h1 className="condensed text-4xl font-bold leading-none">{title}</h1>
        <p className="text-ash">{intro}</p>
      </div>

      {!session.data ? (
        <div className="flex flex-col gap-3">
          <p>
            L&apos;invito è per <strong>{preview.email}</strong>. Accedi o crea un account con questo indirizzo.
          </p>
          <div className="flex gap-3">
            <Link href="/registrati?next=/invito" className={LINK_PRIMARY}>
              Crea account
            </Link>
            <Link href="/accedi?next=/invito" className={LINK_QUIET}>
              Accedi
            </Link>
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-5">
          {isClient && (
            <fieldset className="flex flex-col gap-4 rounded-[var(--radius-panel)] border border-seam p-5">
              <legend className="px-1 text-sm text-ash">
                Consensi (leggi l&apos;
                <Link href="/privacy" className="text-chalk underline underline-offset-4">
                  informativa privacy
                </Link>
                )
              </legend>
              <Consent checked={agreed.health} onChange={(health) => setAgreed({ ...agreed, health })}>
                Acconsento al trattamento dei miei dati di salute (allenamenti, misure, sonno, alimentazione) per ricevere il
                servizio.
              </Consent>
              {role && (
                <Consent checked={agreed.sharing} onChange={(sharing) => setAgreed({ ...agreed, sharing })}>
                  Acconsento che {preview.inviterName} veda {listItalian(scopes)}. Posso revocarlo quando voglio dal profilo.
                </Consent>
              )}
            </fieldset>
          )}
          {error && <Notice tone="error">{error}</Notice>}
          <Button variant="primary" onClick={accept} disabled={!canAccept || busy}>
            {busy ? "Accetto…" : "Accetta l'invito"}
          </Button>
        </div>
      )}
    </section>
  );
}

type ConsentProps = { checked: boolean; onChange: (value: boolean) => void; children: ReactNode };

function Consent({ checked, onChange, children }: ConsentProps) {
  return (
    <label className="flex cursor-pointer items-start gap-3 text-sm leading-relaxed">
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
        className="mt-1 size-5 shrink-0 accent-[var(--color-signal)]"
      />
      <span>{children}</span>
    </label>
  );
}
