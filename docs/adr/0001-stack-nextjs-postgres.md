# ADR-0001: Un'unica app Next.js con PostgreSQL, Drizzle e Better Auth

**Data**: 2026-10-22
**Stato**: accettato
**Decisori**: Marco Manzotti, Claude

## Contesto

L'app iOS salva tutto in un JSON locale. Ora serve un server in UE che salvi i dati di clienti e professionisti dello studio. Su quel server girano anche il sito pubblico, l'area cliente (PWA), la dashboard dello staff e un'API per l'app Android. Il progetto è mantenuto da una persona sola, quindi conta avere poche parti in movimento.

## Decisione

- **Applicazione:** una sola app **Next.js 16** in `web/`, con sito, area cliente, dashboard e API REST `/api/v1`.
- **Database:** **PostgreSQL**, con schema e migrazioni gestiti da **Drizzle ORM** e input validati con **zod**.
- **Autenticazione:** **Better Auth**. Usa cookie sul web e token bearer per Android; la 2FA è prevista per lo staff.
- **Sviluppo e test:** girano su **PGlite**, cioè Postgres compilato in WebAssembly dentro Node, senza Docker né installazioni.
- **Produzione:** Postgres vero in Docker Compose su un VPS Hetzner in UE.
- **Migrazioni:** vengono applicate all'avvio dell'app; se una fallisce, l'app non parte.

## Alternative considerate

### Supabase self-hosted
- **Pro**: auth, storage e API pronte.
- **Contro**: una decina di servizi da tenere in piedi, logica sparsa tra policy SQL e codice.
- **Perché no**: troppa infrastruttura per una persona sola.

### FastAPI (Python) + frontend React separato
- **Pro**: Python è comodo per l'analisi dei dati.
- **Contro**: due progetti, due linguaggi e tipi non condivisi tra API e web.
- **Perché no**: raddoppia il lavoro di manutenzione.

## Conseguenze

### Positive
- Un linguaggio e un deploy; i tipi zod sono condivisi tra API, pagine e (via OpenAPI) Android.
- I test girano in pochi secondi su un database vero, senza servizi esterni.

### Negative
- Next.js 16 cambia spesso API: prima di scrivere codice si leggono le guide in `web/node_modules/next/dist/docs/`.
- PGlite permette una sola connessione per cartella: in sviluppo il database è usato solo dal server Next.

### Rischi
- Una migrazione sbagliata blocca l'avvio in produzione. Mitigazione: migrazioni generate da drizzle-kit, rilette prima del commit e provate in CI su un database vuoto.
