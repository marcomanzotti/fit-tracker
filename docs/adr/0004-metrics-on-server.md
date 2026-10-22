# ADR-0004: Metriche scientifiche calcolate solo sul server

**Data**: 2026-10-22
**Stato**: accettato (si implementa nella fase F3)
**Decisori**: Marco Manzotti, Claude

## Contesto

L'app iOS calcola molte metriche dai dati salvati. Il codice sta in `ios/FitTracker/Science.swift`, `Training.swift`, `Metrics.swift` e `Nutrition.swift`, circa 2.000 righe. Le metriche sono: TRIMP, forma, ACWR, prontezza, sonno, e1RM, progressione, BMR/TDEE e target nutrizionali. Dashboard, PWA e Android devono mostrare gli stessi numeri.

## Decisione

- I motori vengono portati in TypeScript in `web/src/science/` come funzioni pure.
- Job in background li ricalcolano dopo ogni import e salvano i risultati in `daily_metric`.
- Android mostra i valori del server. In locale calcola solo ciò che serve offline: e1RM e timer.
- Per garantire la parità con iOS, i test TypeScript confrontano i risultati con vettori di test esportati dai test Swift.

## Alternative considerate

### Duplicare i motori in Kotlin
- **Pro**: metriche disponibili offline sul telefono.
- **Contro**: tre implementazioni (Swift, Kotlin, TS) da tenere allineate.
- **Perché no**: le metriche cambiano lentamente e non servono durante l'allenamento.

### Calcolo al volo a ogni richiesta
- **Pro**: nessuna tabella derivata.
- **Contro**: la dashboard con molti clienti diventa lenta.
- **Perché no**: i valori giornalieri si calcolano una volta e si leggono molte volte.

## Conseguenze

### Positive
- Una sola fonte di verità per i numeri che vedono cliente e professionista.

### Negative
- Senza rete, l'app Android mostra metriche ferme all'ultimo sync.

### Rischi
- Le versioni Swift e TS possono divergere. Mitigazione: test golden e un'unica fixture in `contracts/fixtures/`.
