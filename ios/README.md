# Fit Tracker — native iOS app

A full native **SwiftUI** rewrite of your Fit Tracker MVP, built to sideload onto
your iPhone with **SideStore**. Same layout you liked, new black + orange palette,
and fully customizable workouts.

---

## What's inside

```
fit_tracker/
├── FitTracker.xcodeproj        ← open this in Xcode
├── FitTracker/                 ← all Swift source + assets
│   ├── FitTrackerApp.swift     app entry
│   ├── Theme.swift             color palette + fonts
│   ├── Models.swift            data types (Codable)
│   ├── Store.swift             persistence + all the stats math
│   ├── Helpers.swift / Infra.swift / Components.swift
│   ├── RootView.swift          header, bottom nav, rest-timer strip
│   ├── Views/                  Home, Workout, PlanEditor, LiveWorkout, Body, Stats
│   └── Assets.xcassets         app icon (from fit-tracker.png) + accent color
├── build-ipa.sh                one-command unsigned .ipa builder for SideStore
└── README.md
```

---

## Features

**Home** – daily check-in (weight + sleep), streak, BMI, goal rings (weight + body-fat),
next workout, 14-day weight chart, recent PRs, week-vs-week comparison, data export.

**Allena (Workout) — fully personalizable**
- Tap a day to start logging: reps × weight per set, live PR detection, “last time”
  reference, suggested next weight (+2.5 kg when you completed every set), rest timer,
  per-exercise notes.
- **Add an exercise mid-workout** by typing its name (e.g. *Dip*) — it’s added to the
  session *and* saved into that day for next time.
- **Create a day from scratch** (＋ Nuovo giorno) and **edit any day** (the slider icon):
  rename, set a subtitle + color, add / remove / **reorder** exercises, set custom
  series & reps. The original 4 days are just editable starting templates — change or
  delete them freely.

**Corpo (Body)** – check-in, BMI / body-fat (manual or US-Navy from neck+waist) /
lean & fat mass, weekly measurements (waist, chest, arms, legs, neck, hips) with deltas,
per-measurement charts, JSON export & import.

**Stats** – weight / sleep / BMI / body-composition charts, all-time PR list,
per-exercise progression (max weight + volume), full workout history, and an
**Obiettivi & profilo** card to set your goal weight, goal body-fat %, start weight,
height and default rest-timer length.

---

## Your data is safe

- Everything is stored in a JSON file in the app’s **Documents** folder and saved
  automatically (debounced) on every change.
- A dated copy (`backup-YYYY-MM-DD.json`) is written too — both are visible in the
  iPhone **Files app → On My iPhone → Fit Tracker**.
- Use **Esporta JSON** (Home or Corpo) to share a full backup, and **Importa JSON**
  to restore it. Export before you ever delete/reinstall the app.

> Note: iCloud sync isn’t included because a free SideStore signing certificate
> can’t use iCloud entitlements. Manual export + the dated backups cover this.

---

## Build & install (you have Xcode ready)

### Option A — run straight from Xcode (quickest to test)
1. Open `FitTracker.xcodeproj`.
2. Select the **FitTracker** scheme + your iPhone.
3. In **Signing & Capabilities**, pick your personal team (free Apple ID) and, if
   needed, change the bundle id `com.marco.fittracker` to something unique.
4. Press ▶︎. (You can also just use SideStore below instead of signing here.)

### Option B — make an .ipa for SideStore (recommended)
SideStore signs the app on your phone with your own Apple ID, so we ship it **unsigned**.

1. If `xcodebuild` only sees Command Line Tools, point it at Xcode once:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. From this folder:
   ```bash
   ./build-ipa.sh
   ```
   This produces **`FitTracker.ipa`** next to the script.

3. Get the `.ipa` onto your iPhone (AirDrop, iCloud Drive, or the SideStore
   “Files” import).

4. In **SideStore** → **My Apps** → **＋** (top-left) → select `FitTracker.ipa`.
   SideStore re-signs it with your Apple ID and installs it. Refresh it within 7 days
   (SideStore can auto-refresh in the background) to keep it from expiring.

---

## Customizing

- **App icon:** replace `fit-tracker.png` (1024×1024, no alpha), then regenerate:
  ```bash
  sips -s format png -z 1024 1024 fit-tracker.png \
    --out FitTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png
  ```
- **Bundle id / name:** edit `PRODUCT_BUNDLE_IDENTIFIER` and
  `INFOPLIST_KEY_CFBundleDisplayName` in the project build settings.
- **Palette:** all colors live in `FitTracker/Theme.swift`.

---

## Requirements
- macOS with **Xcode** (iOS 16+ deployment target; uses Swift Charts).
- An iPhone with **SideStore** set up (free Apple ID).
