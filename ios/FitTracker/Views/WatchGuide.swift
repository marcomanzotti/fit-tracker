import SwiftUI
import UniformTypeIdentifiers

// MARK: - "Connect your watch" guide
// Closes the loop for every iPhone user: watches that sync to Apple Health
// (Garmin, Polar, Coros, Suunto, Amazfit, Apple Watch) just need their own app's
// Apple-Health toggle turned on — explained here per brand. Watches that DON'T
// (Huawei, Fitbit, China-market bands) get the universal fallback: export a
// GPX/TCX file and import it. After that, syncHealth/importWorkoutFile do the rest.

private struct Brand: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let it: [String]
    let en: [String]
    var steps: [String] { L.lang == "en" ? en : it }
}

// Watches that write workouts into Apple Health once their own app's toggle is on.
private let healthBrands: [Brand] = [
    Brand(name: "Apple Watch", icon: "applewatch",
          it: ["Installa l'app FitTracker: si installa anche sul Watch.",
               "Gli allenamenti arrivano da soli, in tempo reale e via Apple Salute."],
          en: ["Install the FitTracker app: it installs on the Watch too.",
               "Workouts arrive on their own, live and via Apple Health."]),
    Brand(name: "Garmin", icon: "applewatch.side.right",
          it: ["Apri Garmin Connect → Altro → Impostazioni → Apple Salute.",
               "Attiva la sincronizzazione. I prossimi allenamenti appariranno qui."],
          en: ["Open Garmin Connect → More → Settings → Apple Health.",
               "Turn syncing on. New workouts will show up here."]),
    Brand(name: "Polar", icon: "applewatch.side.right",
          it: ["Apri Polar Flow → Impostazioni → Apple Salute → attiva.",
               "Sincronizza una sessione per verificarla."],
          en: ["Open Polar Flow → Settings → Apple Health → enable.",
               "Sync a session to verify it."]),
    Brand(name: "COROS", icon: "applewatch.side.right",
          it: ["Apri l'app COROS → Profilo → App di terze parti → Apple Salute.",
               "Concedi i permessi di scrittura."],
          en: ["Open the COROS app → Profile → Third-party apps → Apple Health.",
               "Grant write permissions."]),
    Brand(name: "Suunto", icon: "applewatch.side.right",
          it: ["Apri l'app Suunto → Impostazioni → Apple Salute → attiva.",
               "Le attività verranno condivise con Salute."],
          en: ["Open the Suunto app → Settings → Apple Health → enable.",
               "Activities will be shared with Health."]),
    Brand(name: "Amazfit / Zepp", icon: "applewatch.side.right",
          it: ["Apri Zepp → Profilo → Aggiungi account → Apple Salute.",
               "Attiva le categorie allenamento e attività."],
          en: ["Open Zepp → Profile → Add account → Apple Health.",
               "Enable the workout and activity categories."])
]

struct WatchSetupGuide: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false

    private var fileTypes: [UTType] {
        var t: [UTType] = [.xml]
        if let g = UTType(filenameExtension: "gpx") { t.append(g) }
        if let c = UTType(filenameExtension: "tcx") { t.append(c) }
        return t
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    // 1) Connect Apple Health (the hub every brand below feeds into).
                    Card {
                        Lbl(text: t("hk.connect"), color: Theme.acc2).padding(.bottom, 8)
                        Text(t("guide.intro")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)
                            .padding(.bottom, 12)
                        if HealthKitManager.shared.isAvailable {
                            FilledButton(title: t("hk.sync")) { syncNow() }
                        } else {
                            Text(t("hk.unavailable")).font(.system(size: 12)).foregroundColor(Theme.sub)
                        }
                    }

                    // 2) Per-brand toggles.
                    Lbl(text: t("guide.health_group"), color: Theme.sub)
                    ForEach(healthBrands) { brand in brandCard(brand) }

                    // 3) Universal fallback for closed ecosystems.
                    Lbl(text: t("guide.other_group"), color: Theme.sub).padding(.top, 4)
                    Card {
                        Text(t("guide.other_note")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)
                            .padding(.bottom, 12)
                        FilledButton(title: t("guide.import_file"), color: Theme.blue) { importing = true }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $importing, allowedContentTypes: fileTypes, allowsMultipleSelection: false) { result in
            handleImport(result)
        }
    }

    private var header: some View {
        HStack {
            Text(t("guide.title")).font(.head(20, .bold)).foregroundColor(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(Theme.sub)
            }
        }
        .padding(.top, 18)
    }

    private func brandCard(_ b: Brand) -> some View {
        Card {
            HStack(spacing: 9) {
                Image(systemName: b.icon).font(.system(size: 16)).foregroundColor(Theme.acc)
                Text(b.name).font(.head(15, .semibold)).foregroundColor(Theme.txt)
            }
            .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(b.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)").font(.num(11)).foregroundColor(Theme.bg)
                            .frame(width: 18, height: 18).background(Theme.acc).clipShape(Circle())
                        Text(step).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(2)
                    }
                }
            }
        }
    }

    private func syncNow() {
        store.prefs.healthKit = true
        // This guide is explicitly about pulling in workouts from a paired watch,
        // so opt the user into workout import here (Settings can turn it back off).
        store.prefs.importWorkouts = true
        store.syncHealth { ok, n, sources in
            if !ok { toast.show(t("hk.unavailable")); return }
            if n > 0 {
                let src = sources.isEmpty ? "" : " · " + sources.joined(separator: ", ")
                toast.show("\(n) \(t("hk.imported_n"))\(src)")
            } else {
                toast.show(t("hk.synced"))
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        if store.importWorkoutFile(url) != nil {
            toast.show(t("guide.import_ok"))
        } else {
            toast.show(t("guide.import_fail"))
        }
    }
}
