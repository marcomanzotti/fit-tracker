# Fit Tracker

Fit Tracker e' un'app personale per allenamento, peso e composizione corporea che
trasforma dati inseriti a mano (o importati da Apple Salute) in metriche di
sport-science utilizzabili ogni giorno. L'obiettivo e' uno solo: darti carico,
recupero, nutrizione e progressi calcolati con formule validate, senza abbonamenti,
senza cloud e senza account, tenendo **tutti i dati in locale sul tuo dispositivo**.

E' disponibile in **due versioni native** che condividono layout, palette, logica e
formato dati, cosi' un backup esportato da una si importa nell'altra:

| Piattaforma | Cartella | Tecnologia | Build / distribuzione |
|---|---|---|---|
| iOS | [`ios/`](ios/) | SwiftUI | `.ipa` via SideStore — [ios/README.md](ios/README.md) |
| Android | [`android/`](android/) | Kotlin + Jetpack Compose | `.apk` via GitHub Actions — [android/README.md](android/README.md) |

## Obiettivi del progetto

- **Tutto calcolato dai tuoi dati.** Mostriamo solo metriche derivabili da cio' che
  inserisci: peso, sesso, eta', altezza, ripetizioni, durata e frequenza cardiaca
  media. Niente numeri inventati: se manca un dato, la metrica resta vuota.
- **Formula piu' precisa disponibile.** Per ogni calcolo l'app sceglie automaticamente
  la formula migliore consentita dai dati presenti (es. le calorie usano la frequenza
  cardiaca se c'e', altrimenti i MET specifici dello sport).
- **Local-first e privato.** Salvataggio automatico locale + backup datati. Export/import
  JSON per spostare i dati. Nessun server.
- **Bilingue runtime (IT / EN).** Tutta l'interfaccia e **ogni spiegazione "i"** sono
  nella tua lingua di riferimento e cambiano all'istante quando cambi lingua.
- **Niente emoji**, ovunque: UI, codice e documentazione.

## Le quattro schede

### Home — dashboard
- Check-in giornaliero (peso + punteggio sonno), streak con giorno di grazia, BMI con
  categoria OMS, anelli obiettivo (peso + grasso), prossimo allenamento.
- **Questa settimana**: striscia di 7 giorni; ogni giorno e' toccabile per registrare
  un allenamento (dati precompilati dall'ultima volta, sempre modificabili) o un
  **giorno di riposo**. Riposo e allenamento condividono colore e icona con il piano
  settimanale.
- **Dashboard scientifica** con pulsanti informativi ovunque: carico cardio (TRIMP),
  carico interno (ACWR / monotonia / strain), andamento carico 14 giorni, nutrizione,
  prontezza (HRV).

### Allena — log allenamento
- Giorni completamente personalizzabili: crea / modifica / riordina esercizi, metodi
  (superset, drop set, rest-pause, giant set), serie x peso, PR live, "ultima volta",
  peso suggerito, timer di recupero, note, aggiunta esercizio al volo.
- Attivita' cardio salvabili (corsa, nuoto, bici, camminata + personalizzate) con
  durata, distanza, FC media e RMSSD opzionale.
- **Calorie bruciate a fine di ogni sessione**, con possibilita' di sovrascriverle a mano.

### Corpo — misurazioni
- BMI, body-fat (manuale o stima US-Navy da collo + vita), massa magra/grassa,
  misurazioni settimanali con delta e grafici, export/import JSON.
- **Sonno**: se Apple Salute non rileva dati per la notte corrente, compare un form
  di inserimento manuale per ore di sonno, punteggio 0-100, HRV SDNN e FC notturna.

### Nutrizione — alimentazione
- **Calendario mensile** come vista principale: ogni giorno e' colorato per intake vs
  target (verde/ambra/rosso), toccabile per inserire o modificare.
- Apertura su **"Per pasto"** di default per il giorno corrente (colazione /
  pranzo / cena / spuntini); modalita' Totale rapido e Alimenti per uso avanzato.
- **Alimenti con marca opzionale**: distingui prodotti con lo stesso nome di brand diversi.
- **Ricette**: crea ricette da zero (valori per 100 g, oppure totale + porzioni) o
  assemblale aggiungendo alimenti gia' salvati. Nel picker alimenti / ricette, scorri
  verso destra per aprire le ricette, verso sinistra per gli alimenti.

### Stats — statistiche
- Grafici peso / sonno / BMI / composizione, lista PR, progressione per esercizio,
  storico sessioni, obiettivi e profilo.

## Motori di sport-science

Tutte le metriche sono calcolate da dati inseribili a mano. Ogni voce ha un pulsante
"i" che spiega cos'e', come si calcola e come leggerla, nella tua lingua.

- **Calorie bruciate** — sempre con la formula piu' precisa disponibile: 1) valore
  manuale se lo inserisci; 2) equazione di Keytel basata sulla FC media; 3) MET
  **specifico per sport** affinato dalla velocita' reale quando c'e' la distanza —
  bici, corsa, camminata e nuoto hanno formule diverse; 4) MET fisso per sport con la
  sola durata; 5) per la forza un MET di resistenza sulla durata, o una stima da volume.
- **TRIMP (Banister)** — carico cardio della sessione da durata + FC media, pesato sulla
  FC di riserva e con fattore esponenziale per sesso. E' la **fonte unica del carico
  interno**: senza FC media non c'e' carico (cosi' nessuna metrica si gonfia da sola).
- **ACWR via EWMA** — rapporto carico acuto (7 gg) / cronico (28 gg) con media mobile
  esponenziale. Zona 0.8-1.3 ottimale.
- **Monotonia & strain (Foster)** — uniformita' del carico settimanale e stress
  complessivo; segnalano quando valutare una settimana di scarico.
- **Prontezza (HRV)** — z-score di ln(RMSSD) su baseline personale; compare solo se
  registri l'HRV (sensore opzionale).
- **Nutrizione** — BMR (Mifflin-St Jeor) -> TDEE -> calorie obiettivo, macro su range
  ISSN, ciclizzazione carboidrati, cap sale OMS, **TDEE adattivo** appreso dai dati
  reali, **trend del peso** (regressione) con aggiustamento calorico, **disponibilita'
  energetica (LEA/RED-S)**.
- **Sovraccarico progressivo** — doppia progressione (aumenta carico / ripetizioni /
  mantieni) per il prossimo allenamento.

## Livelli di attivita'

Il livello di attivita' moltiplica il metabolismo basale (BMR) per stimare il dispendio
totale giornaliero (TDEE), base per calorie e macro. Scegli in base ai **giorni reali
di allenamento**:

| Livello | Moltiplicatore | Giorni di allenamento |
|---|---|---|
| Sedentario | x1.2 | lavoro d'ufficio, nessun allenamento |
| Leggero | x1.375 | 1-2 a settimana |
| Moderato | x1.55 | 3-4 a settimana |
| Alto | x1.725 | 5-6 a settimana |
| Atleta | x1.9 | 6-7 + lavoro fisico o doppie sedute |

## Note di input

- I campi decimali accettano sia la virgola che il punto: vengono trattati entrambi
  come separatore decimale (es. `25,5` e `25.5` sono equivalenti).
- I dati Apple Salute (passi, FC a riposo, HRV) sono opzionali e riempiono solo i campi
  mancanti, senza sovrascrivere cio' che inserisci a mano.

## Distribuzione rapida (Android)

Apri **Actions -> Build Android APK**, scarica l'artifact `FitTracker-android`
(`FitTracker.apk`) e condividilo. Nessun account sviluppatore richiesto: e' un APK
installabile direttamente. Dettagli in [android/README.md](android/README.md).

## Compatibilita' dei dati

Le due app usano lo **stesso schema JSON**: un backup esportato da iOS si importa su
Android e viceversa. Ogni campo aggiunto dopo lo schema iniziale e' opzionale, quindi i
backup vecchi continuano a caricarsi.
