# ADR-0005: Protezione dei dati di salute e uso dei dati

**Data**: 2026-10-22
**Stato**: accettato
**Decisori**: Marco Manzotti, Claude

## Contesto

La piattaforma raccoglie dati di salute: sonno, frequenza cardiaca, HRV, peso, alimentazione e allenamenti. Per il GDPR sono una categoria particolare (art. 9). L'obiettivo è raccogliere più dati possibile e monetizzarli. La policy di Google su Health Connect vieta di vendere quei dati o di usarli per pubblicità. Google approva solo i permessi legati a una funzione visibile nell'app.

## Decisione

**Accesso dello staff**
- I professionisti vedono un cliente solo tramite un'assegnazione attiva con scope: training, nutrition, body, sleep, vitals, notes.
- Ogni lettura passa da un'unica guardia, `withClientAccess`, che registra l'accesso in `audit_log`.

**Consensi**
- Un consenso per ogni finalità, con versione del testo, data e revoca. Le finalità sono: trattamento dei dati di salute (necessario al servizio), condivisione con ogni professionista, statistiche anonime, ogni studio di ricerca, marketing.

**Health Connect**
- Si chiede un tipo di dato solo quando una funzione lo mostra.
- I permessi si chiedono a passi; i percorsi GPS hanno un consenso in più.

**Usi dei dati che progettiamo**
- abbonamenti
- statistiche aggregate, solo su gruppi di almeno 10 persone consenzienti
- export pseudonimizzati, per studio e con consenso dedicato

**Usi che escludiamo**
- **Non progettiamo la vendita di dati individuali** né l'uso per pubblicità.

**Diritti e conservazione**
- Export dei dati (art. 20) e cancellazione dell'account (art. 17) disponibili dall'app e dal web.
- Le cancellazioni arrivano anche ai backup entro il loro periodo di conservazione.
- Dati in UE: VPS e object storage Hetzner.
- Una DPIA è obbligatoria. La bozza è in [`docs/gdpr.md`](../gdpr.md) e va rivista da un consulente prima del lancio.

## Alternative considerate

### Accesso dello staff a tutti i clienti dello studio
- **Pro**: più semplice da sviluppare.
- **Contro**: viola il principio di minimizzazione; un nutrizionista vedrebbe dati che non gli servono.
- **Perché no**: gli scope costano poco se introdotti subito.

### Vendita o licenza di dati individuali a terzi
- **Pro**: ricavi diretti.
- **Contro**: richiede un consenso specifico e libero per ogni terzo, vietato dalla policy Health Connect; rischio di sanzioni e di rimozione dal Play Store.
- **Perché no**: non è un'opzione praticabile.

## Conseguenze

### Positive
- La dichiarazione Health Connect e il modulo Data safety del Play Store si compilano con risposte coerenti.
- La fiducia dei clienti diventa un argomento di vendita per lo studio.

### Negative
- Ogni nuova funzione che usa dati deve dichiarare scope e finalità.

### Rischi
- Uno scope dimenticato espone dati. Mitigazione: test di permesso per ogni ruolo e scope, e nessuna query dello staff fuori da `withClientAccess`.
