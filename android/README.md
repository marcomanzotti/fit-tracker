# Fit Tracker — Android (Jetpack Compose)

Port nativo Android dell'app iOS, scritto in **Kotlin + Jetpack Compose**.
Stessa identica struttura, stesso tema nero + arancione, stessi calcoli (BMI,
body-fat Navy, PR, streak, suggerimento peso, statistiche) e stessa persistenza
locale in JSON.

## Cosa c'è dentro

```
android/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/marco/fittracker/
│       │   ├── MainActivity.kt
│       │   ├── data/Models.kt      tipi dati + helper (porting di Models/Helpers.swift)
│       │   ├── data/Store.kt       persistenza JSON + tutta la matematica delle stat
│       │   └── ui/
│       │       ├── Theme.kt        palette colori
│       │       ├── Components.kt   card, bottoni, input, tag…
│       │       ├── Charts.kt       grafici a linee/barre + anelli (Canvas)
│       │       ├── RootScreen.kt   header, bottom nav, timer di recupero, toast
│       │       ├── HomeScreen.kt   dashboard
│       │       ├── WorkoutScreen.kt  griglia giorni + editor + workout live
│       │       ├── BodyScreen.kt   misurazioni & check-in
│       │       └── StatsScreen.kt  statistiche
│       └── res/                    tema, icona launcher (adaptive)
├── build.gradle.kts / settings.gradle.kts
└── gradle.properties
```

## Far uscire l'APK senza installare niente (consigliato)

C'è un workflow GitHub Actions ([.github/workflows/android.yml](../.github/workflows/android.yml))
che builda un **APK di debug** ad ogni push su `main` che tocca `android/`.

1. Vai su **Actions** → **Build Android APK** → ultima run.
2. Scarica l'artifact **FitTracker-android** (è `FitTracker.apk`).
3. Mandalo ai tuoi amici. Sul telefono Android devono solo abilitare
   *"Installa app da questa sorgente"* e aprire l'APK.

> È un APK di **debug**: si installa direttamente senza Play Store ed è perfetto
> per i test tra amici. Non serve alcun account sviluppatore.

Puoi anche lanciarlo a mano da **Actions** → **Run workflow**.

## Build in locale (se vuoi)

Serve Android Studio (o JDK 17 + Android SDK). Poi:

```bash
cd android
./gradlew assembleDebug      # genera app/build/outputs/apk/debug/app-debug.apk
```

(La prima volta apri la cartella `android/` in Android Studio: genera il
`gradlew` e `local.properties` da solo.)

## Dati & backup

Come su iOS: tutto in un file JSON nello storage privato dell'app, salvato
automaticamente ad ogni modifica, più una copia datata `backup-YYYY-MM-DD.json`.
Usa **Esporta JSON** / **Importa JSON** (Home o Corpo) per spostare i dati.
Il formato JSON è identico a quello iOS.
