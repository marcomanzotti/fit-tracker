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
- Gli scope possibili dipendono dalla disciplina: un fisioterapista non può chiedere il diario alimentare, un nutrizionista non vede gli allenamenti.
- Anche i tentativi rifiutati finiscono nel registro (azione `denied`).
- Ogni riga del registro conserva nome ed email del professionista, così il cliente vede chi ha guardato i suoi dati anche dopo che quell'account è stato cancellato.
- Essere admin non dà accesso ai dati di salute: serve un'assegnazione come per chiunque altro (aggiunto il 2026-10-22, fase F1).
- La 2FA è obbligatoria per staff e admin su tutte le API.

**Consensi**
- Un consenso per ogni finalità, con versione del testo, data e revoca. Le finalità sono: trattamento dei dati di salute (necessario al servizio), condivisione con ogni professionista, statistiche anonime, ogni studio di ricerca, marketing.
- Il consenso alla condivisione registra anche gli scope esatti accettati dal cliente.
- Revocare il trattamento dei dati di salute chiude subito tutte le assegnazioni.
- Un consenso dato su una versione precedente dell'informativa resta valido, ma viene segnato `outdated` e le app chiedono di rivederlo.
- Lo storico dei consensi si cancella insieme all'account (cascade): una volta eliminato l'utente non resta un trattamento da dimostrare. Da confermare col consulente.

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
- Export dei dati (art. 20) e cancellazione dell'account (art. 17) disponibili dall'app e dal web. L'export include il registro di chi ha consultato i dati.
- I link d'invito portano il token dopo `#`, quindi il token non arriva mai nei log del server. L'email resta salvata nell'invito solo finché non viene accettato.
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
