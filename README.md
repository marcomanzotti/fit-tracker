# Fit Tracker

App di tracking allenamenti / peso / misurazioni, disponibile in **due versioni
native** che condividono layout, palette (nero + arancione), logica e formato dati:

| | Cartella | Tecnologia | Build / distribuzione |
|---|---|---|---|
| 📱 **iOS** | [`ios/`](ios/) | SwiftUI | `.ipa` via SideStore — [ios/README.md](ios/README.md) |
| 🤖 **Android** | [`android/`](android/) | Kotlin + Jetpack Compose | `.apk` via GitHub Actions — [android/README.md](android/README.md) |

## Funzionalità (entrambe le piattaforme)

- **Home** — check-in giornaliero (peso + sleep), streak, BMI, anelli obiettivo
  (peso + grasso), prossimo allenamento, grafico peso 14 giorni, record recenti,
  confronto settimanale, export.
- **Allena** — giorni di allenamento completamente personalizzabili: crea/modifica/
  riordina esercizi, log serie × peso, rilevamento PR live, "ultima volta",
  peso suggerito (+2.5 kg), timer di recupero, note, aggiunta esercizio al volo.
- **Corpo** — BMI, body-fat (manuale o US-Navy), massa magra/grassa, misurazioni
  settimanali con delta e grafici, export/import JSON.
- **Stats** — grafici peso/sleep/BMI/composizione, lista PR, progressione per
  esercizio, storico sessioni, obiettivi & profilo.

## Distribuzione rapida agli amici (Android)

Apri **Actions → Build Android APK**, scarica l'artifact `FitTracker-android`
(`FitTracker.apk`) e condividilo. Nessun account sviluppatore richiesto: è un APK
di debug installabile direttamente. Dettagli in [android/README.md](android/README.md).

## Compatibilità dei dati

Le due app usano lo **stesso schema JSON**, quindi un backup esportato da iOS si
può importare su Android e viceversa.
