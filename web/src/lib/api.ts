// Calls to /api/v1 from the browser (cookie session). Errors carry the server's
// code and an Italian message for the screen.

export class ApiError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

const MESSAGES: Record<string, string> = {
  unauthorized: "Accedi per continuare.",
  two_factor_required: "Attiva la verifica in due passaggi per usare lo studio.",
  no_access: "Non segui questo cliente per questi dati.",
  consent_missing: "Il cliente non ha dato il consenso al trattamento dei dati di salute.",
  consent_required: "Serve il consenso al trattamento dei dati di salute.",
  policy_outdated: "L'informativa privacy è cambiata: ricarica la pagina e rileggila.",
  edited_elsewhere: "Un collega ha modificato questa scheda: ricarica per vedere le sue modifiche.",
  unknown_exercise: "La scheda usa un esercizio che non è in libreria.",
  empty_program: "Aggiungi almeno un giorno prima di pubblicare.",
  template_not_publishable: "Assegna il template a un cliente, poi pubblicalo.",
  invitation_expired: "Questo invito è scaduto: chiedine uno nuovo.",
  invitation_accepted: "Questo invito è già stato usato.",
  invitation_revoked: "Questo invito è stato annullato.",
  email_mismatch: "Questo invito è per un altro indirizzo email: accedi con quello.",
  too_many_invitations: "Hai mandato troppi inviti oggi: riprova domani.",
  scope_not_allowed: "Questo ruolo non può vedere alcuni dei dati scelti.",
  discipline_mismatch: "Non puoi seguire clienti con questo ruolo.",
  assignment_exists: "Questo professionista segue già il cliente.",
  rate_limited: "Troppe richieste ravvicinate: aspetta qualche secondo.",
  busy: "Il server è occupato: riprova tra un momento.",
  validation_failed: "Alcuni dati non sono validi.",
  not_found: "Non trovato.",
};

export function messageFor(code: string, fallback?: string): string {
  return MESSAGES[code] ?? fallback ?? "Qualcosa è andato storto. Riprova.";
}

type Envelope<T> = { success: boolean; data: T | null; error: { code: string; message: string } | null };

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const response = await fetch(path, {
    method: init.method ?? (init.body === undefined ? "GET" : "POST"),
    headers: init.body === undefined ? undefined : { "content-type": "application/json" },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
    credentials: "same-origin",
  }).catch(() => null);
  if (!response) throw new ApiError("Connessione assente: controlla la rete e riprova.", "network", 0);
  const json = (await response.json().catch(() => null)) as Envelope<T> | null;
  if (!response.ok || !json?.success) {
    const code = json?.error?.code ?? "network";
    throw new ApiError(messageFor(code), code, response.status);
  }
  return json.data as T;
}
