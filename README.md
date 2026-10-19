# Fit Tracker

App personale per allenamento, corpo, sonno e nutrizione. Trasforma quello che
registri a mano e quello che arriva da Apple Salute (Apple Watch, Xiaomi Smart Band 10,
Garmin, Polar e altri) in metriche di scienze dello sport, con la formula più precisa
che i dati permettono. Niente account, niente abbonamenti, niente server: **tutti i dati
restano sul telefono**.

| Componente | Cartella | Tecnologia |
|---|---|---|
| App iPhone (iOS 18+) | [`ios/FitTracker/`](ios/FitTracker/) | SwiftUI, Swift Charts, HealthKit |
| App Apple Watch (watchOS 11+) | [`ios/FitTrackerWatch/`](ios/FitTrackerWatch/) | SwiftUI, HealthKit, WatchConnectivity |
| Widget e Live Activity | [`ios/FitTrackerWidgets/`](ios/FitTrackerWidgets/) | WidgetKit, ActivityKit |
| Codice comune ai tre | [`ios/Shared/`](ios/Shared/) | tipi del collegamento col Watch, stile |
| Test | [`ios/FitTrackerTests/`](ios/FitTrackerTests/) | XCTest |

La sincronizzazione diretta con la Xiaomi Smart Band 10 viene dal pacchetto `Band10Kit`
del repository [xiaomi-band10-apple-health](https://github.com/marcomanzotti/xiaomi-band10-apple-health),
che va clonato accanto a questo (`../band10-health`).

## Principi

- **Solo metriche ricavabili dai tuoi dati.** Se manca un dato la metrica resta vuota,
  non viene inventata.
- **La formula più precisa disponibile**, scelta in automatico in base a quello che c'è.
- **Locale e privato.** Salvataggio automatico, backup datati, export e import JSON.
- **Italiano e inglese**, cambiabili al volo; ogni metrica ha una scheda "i" che spiega
  cos'è, come si calcola e i range di riferimento.
- Nessuna emoji, nell'interfaccia come nel codice.

## Le schede

- **Home**: prontezza e recupero, prossimo allenamento, check-in del peso, settimana,
  carico, nutrizione di oggi.
- **Allena**: giorni di forza personalizzabili (metodi, serie a tempo, intervalli, tenute
  isometriche con conto alla rovescia), attività cardio salvate, seduta live con recupero
  automatico, PR, peso suggerito, calcolatore dei dischi e riscaldamento, piano settimanale,
  calendario, import di allenamenti da Salute e da file GPX, TCX e FIT.
- **Corpo**: peso, massa grassa (manuale o metodo Navy), FFMI, misure, sonno con fasi e
  ipnogramma, parametri notturni (HRV, FC, SpO2, respiro, temperatura), storico di Salute.
- **Nutrizione**: calendario mensile, pasti, alimenti con codice a barre (Open Food Facts),
  ricette, obiettivi di calorie e macro.
- **Stats**: grafici di tutte le metriche, PR, progressione per esercizio, carico e forma.

## Motori di calcolo

- **Carico**: TRIMP di Banister dalla FC della seduta, con la FC a riposo e la FC max del
  profilo. Fitness, fatica e forma con le medie esponenziali di Banister (42 e 7 giorni),
  monotonia e strain di Foster, zone FC e decoupling per gli allenamenti aerobici.
- **Prontezza**: HRV notturna, FC a riposo e punteggio del sonno contro una baseline
  personale di 60 giorni; i parametri notturni fuori norma la limitano a "leggero".
- **Calorie bruciate**: valore del dispositivo o manuale, altrimenti MET specifico per sport
  affinato da velocità e FC.
- **Nutrizione**: metabolismo basale Mifflin-St Jeor, TDEE dal livello di attività, TDEE
  adattivo dall'andamento reale del peso, macro su range ISSN, disponibilità energetica.
- **Progressione**: doppia progressione per esercizio, e1RM, volume per gruppo muscolare.
- **Sonno**: notti ricostruite per fonte (una notte contata una volta sola anche con due
  dispositivi), punteggio, debito di sonno, regolarità e jet lag sociale.

## I tuoi dati

- Un unico file JSON in `Documents`, salvato in automatico a ogni modifica, con una copia
  datata al giorno (`backup-AAAA-MM-GG.json`, ne restano 30).
- Un file illeggibile non viene mai sovrascritto: viene rinominato, si carica il backup
  più recente e l'app lo dice. Un salvataggio fallito mostra un avviso.
- Export e import JSON da Corpo e Impostazioni; l'import tiene una copia di ciò che sostituisce.
- **Una seduta in corso sopravvive alla chiusura dell'app**: serie, durata, FC, recupero,
  tempo e distanza del cardio vengono scritti man mano e ripristinati al riavvio.
- Ogni campo aggiunto dopo lo schema iniziale è facoltativo, quindi un backup vecchio si
  carica sempre.

## Build e installazione

Serve Xcode 26 o successivo e il repository `band10-health` accanto a questo.

```bash
python3 ios/build_and_run.py           # compila in Release e installa sull'iPhone collegato
python3 ios/build_and_run.py --watch   # in più compila e installa l'app del Watch
```

Lo script trova da solo l'iPhone (e il Watch) raggiungibili; con più dispositivi si
sceglie con `FIT_TRACKER_DEVICE` e `FIT_TRACKER_WATCH`. `FIT_TRACKER_CONFIGURATION=Debug`
compila una build di debug, molto più lenta. In fondo alle Impostazioni e alla lista del
Watch compaiono versione, numero di build (numero di commit) e commit installati: un `+`
dopo l'hash vuol dire modifiche non ancora committate.

Con il team gratuito il profilo scade dopo 7 giorni: si reinstalla con lo stesso comando.
Al primo avvio dopo una reinstallazione l'iPhone chiede di autorizzare lo sviluppatore in
Impostazioni › Generali › VPN e gestione dispositivi.

`ios/build-ipa.sh` produce un `.ipa` non firmato, utile solo come archivio.

## Test

```bash
cd ios
xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Coprono file dati (anche corrotti), seduta in corso e suoi orologi, import da Salute e da
file, notti di sonno e le formule di carico, prontezza, nutrizione e progressione.

La CI ([`.github/workflows/`](.github/workflows/)) gira sui push a `main` e ai branch
`feature/**`: controlla che `Localization.swift` non abbia chiavi duplicate (farebbero
chiudere l'app all'avvio), esegue i test e compila l'app con e senza Watch.

## Apple Watch

L'app del Watch mostra gli stessi piani di forza e le stesse attività cardio del telefono.
Durante la seduta registra FC, calorie e distanza con `HKWorkoutSession`; per la forza si
segnano le serie dal polso con la Digital Crown. A fine seduta il risultato arriva al
telefono via WatchConnectivity e l'allenamento viene salvato in Salute una volta sola.

```
ios/
├── Shared/WatchBridge.swift        tipi scambiati tra telefono e Watch
├── FitTracker/WatchSync.swift      lato telefono: catalogo verso il Watch, risultati in arrivo
└── FitTrackerWatch/                l'app del Watch
    ├── WorkoutManager.swift         allenamento live con HealthKit
    ├── WatchLink.swift              WatchConnectivity lato Watch
    └── WatchViews.swift             lista, seduta live, riepilogo
```

| Target | Contenuto |
|---|---|
| `FitTracker` | app iPhone senza Watch |
| `FitTrackerWatch` | app del Watch |
| `FitTrackerWatchHost` | app iPhone con il Watch incorporato (quella installata dallo script) |
| `FitTrackerWidgets` | widget e Live Activity, incorporati in entrambe le app iPhone |
| `FitTrackerTests` | test, ospitati nell'app |
