# FitTracker: project guide for agents

FitTracker is turning from a personal iOS app into a coached platform for one studio (PTs, nutritionists, physios, admin, clients). Plan and phases: `~/.claude/plans/ethereal-crunching-wadler.md`. Decisions: [docs/adr/](docs/adr/README.md). Data protection: [docs/gdpr.md](docs/gdpr.md).

## Layout

| Folder | What | Status |
|---|---|---|
| `ios/` | SwiftUI app + Watch + widgets, local JSON storage | Unchanged until the iOS sync phase (F9) |
| `web/` | Next.js 16: public site, client PWA, staff dashboard, REST API `/api/v1` | In development |
| `android/` | Kotlin + Compose + Health Connect client | Phase F5 (old v9 port: `git show 40c57e7^:android/...`, reference only) |
| `deploy/` | Docker Compose + Caddy + backups for the Hetzner VPS | Phase F6 |
| `docs/` | ADRs and GDPR documents | |

## Web commands (run in `web/`)

- `npm run dev`: dev server on an embedded PGlite database in `web/.data/` (env from `.env.development`).
- `npm test`: Vitest. Every test gets a fresh in-memory Postgres (`createDatabase("pglite://memory")`).
- `npm run seed:demo`: fills the local dev database with demo data (admin@demo.test and luca@demo.test, password `demo-password-123`, a published program, workouts, weigh-ins). Delete `web/.data/dev` to start over.
- `npm run lint && npm run typecheck && npm run build`: what CI (`.github/workflows/web.yml`) runs.
- `npm run db:generate -- --name <topic>`: write a SQL migration after changing `src/db/schema/`. Read the SQL before committing; the app applies migrations at startup.

## Conventions

- **Read the Next.js docs first:** `web/node_modules/next/dist/docs/`. Next 16 renamed middleware to `proxy.ts`, enables Cache Components (session reads go behind `<Suspense>`), and has async request APIs. Never put personal data in `use cache` keys.
- **Server wiring:** `src/server/runtime.ts` is the only place that builds the database and auth. Factories (`createDatabase`, `createAuth`) take their dependencies so tests can inject them.
- **API responses** use the envelope in `src/server/http.ts`: `{ success, data, error }`. Exception: `/api/auth/*` is Better Auth and answers `{ message, code }`; clients handle both.
- **Validation:** every input from a request, the Android app or Health Connect is validated with zod at the boundary.
- **Staff access to client data** goes only through `withClientAccess` (`src/server/access.ts`), which checks assignment, scope and consent and writes `audit_log`. No direct staff queries; new reads go in `src/server/client-data.ts`.
- **Services validate their own input** with zod (`parseWith`), so routes stay thin: read the body or query, call the service, `ok(...)`. Routes use `route()` from `src/server/route.ts`, which handles rate limiting, CSRF (origin check for cookie calls), errors and `connection()`.
- **Roles** (`ROLES` in `src/db/schema/auth.ts`) are set only by the server, never from sign-up input.
- **Database:** timestamps are `timestamptz`. Synced tables get client UUIDs, `rev`, `updated_at`, `deleted_at` (ADR-0002).
- **Health Connect:** only request a data type that a visible feature uses (ADR-0005). Individual data is never sold or used for ads.
- **Dependencies** are pinned to exact versions published at least two weeks earlier.
- **Language:** UI text in Italian first (English second); code, comments and commit bodies follow the existing repo style.
- **Lean code** (Marco's standing preference): no dead code, extend an existing file before adding one, files under 800 lines, report line/file counts at the end of a phase.

## Open items from the F0/F1 reviews

Done in F1:
- 2FA is enforced for staff/admin.
- CI job `postgres` runs `src/server` tests on Postgres 17.
- The sync lock lives in the `bump_sync_rev` trigger.
- Denied access attempts are logged.

Still open:
- **F2 and later (sync):**
  - Every new synced table needs the `bump_sync_rev` trigger (custom migration).
  - Register the table in `entities` in `src/server/sync.ts`.
  - Staff-written client data (programs) must be written in a transaction; the trigger takes the client's lock.
- **F3 (jobs):**
  - Purge sync tombstones and expired or revoked invitations after a retention period.
  - Set and apply an `audit_log` retention period (see docs/gdpr.md).
  - Batch sync upserts if pushes get large.
- **F6:**
  - Add a sync "epoch" bumped on a backup restore, so devices whose cursor is ahead of the restored sequence resync from scratch.
  - Revoke UPDATE/DELETE on `audit_log` for the app role.
  - Caddy must set `header_up X-Real-IP {remote_host}`. Better Auth reads the client IP only from `X-Real-IP`.
  - Never publish the app port.
  - Send HSTS, then add a nonce-based CSP.
  - Run migrations as the owner role and give the app a DML-only role.
  - Wire `SMTP_URL`; production refuses to start without it.

## Workflow

Branch per phase from `main` (`feature/platform-fN`), TDD for server logic, then review agents:
- `code-reviewer`, `security-reviewer` and `database-reviewer` for schema and queries;
- `react-reviewer` for UI;
- `kotlin-reviewer` for Android.

Conventional commits (`feat(web): …`, `docs: …`), one per topic. Merge to `main` only with Marco's OK.
