# ADR-0002: Sync a cursore con un solo proprietario per entità

**Data**: 2026-10-22
**Stato**: accettato (si implementa nella fase F1)
**Decisori**: Marco Manzotti, Claude

## Contesto

L'app Android deve registrare gli allenamenti anche senza rete. Più avanti lo farà anche l'app iOS. I dati arrivano sia dal telefono del cliente sia dal web, mentre i professionisti modificano schede e target del cliente. Serve un sync semplice che non perda righe e non crei conflitti difficili da risolvere.

## Decisione

- **Righe sincronizzate:** ogni tabella sincronizzata ha un id UUIDv7 generato dal dispositivo, `rev`, `updated_at` e `deleted_at` (cancellazione logica). `rev` viene da una sequenza globale.
- **Pull:** `GET /api/v1/sync?cursor=N` restituisce le righe leggibili con `rev > N`.
- **Ordine delle scritture:** le scritture su un cliente sono serializzate con un advisory lock per cliente, così il cursore non salta righe.
- **Push:** `POST /api/v1/sync/push` è idempotente per id. Una sessione di allenamento viaggia intera, con esercizi e serie, in una transazione.
- **Proprietà:**
  - Il cliente scrive i propri dati: sessioni, misure, diario, check-in, metriche manuali.
  - Lo staff scrive schede, target, piani alimentari e note.
  - Ogni altra scrittura riceve 403.
- **Conflitti:** vince l'ultima scrittura per aggregato.
- **Health Connect:** i record arrivano in lotti, deduplicati su (utente, app di origine, id del record).

## Alternative considerate

### CRDT o merge a livello di campo
- **Pro**: nessuna modifica persa anche con scritture concorrenti.
- **Contro**: complessità alta in Kotlin, TypeScript e Swift.
- **Perché no**: con un solo proprietario per entità i conflitti reali sono quasi nulli.

### Il server come unica copia (niente offline)
- **Pro**: zero logica di sync.
- **Contro**: in palestra la rete spesso manca.
- **Perché no**: perdere un allenamento è inaccettabile.

## Conseguenze

### Positive
- Un solo protocollo per Android, PWA e iOS futuro.
- Cancellazioni propagate grazie a `deleted_at`.

### Negative
- Le cancellazioni logiche vanno ripulite periodicamente, rispettando i tempi del GDPR (vedi ADR-0005).

### Rischi
- Un client con l'orologio sbagliato non crea problemi: l'ordine lo decide `rev` lato server, non l'ora del dispositivo.
