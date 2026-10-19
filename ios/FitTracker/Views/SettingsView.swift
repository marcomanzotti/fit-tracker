import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings (sheet)
// Four sections. Switches and choices apply as soon as they are touched; the
// typed fields are saved with the button, and closing with unsaved text asks.

/// The typed fields of Settings, compared with how they were opened to know
/// whether closing would lose something.
private struct SettingsDraft: Equatable {
    var profile: ProfileFields
    var timerSec: String
    var holdPrep: String
    var barWeight: String
    var plates: String
    var units: String
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SettingsDraft
    private let opened: SettingsDraft
    @State private var section = "profile"
    @State private var showGuide = false
    @State private var showHealthHistory = false
    @State private var showGoals = false
    @State private var showManager = false
    @State private var askDiscard = false

    private static let sections = ["profile", "training", "health", "data"]

    init(store: Store) {
        let p = store.prefs
        let initial = SettingsDraft(
            profile: ProfileFields(p, currentWeight: store.lastWeight),
            timerSec: String(p.timer), holdPrep: String(p.holdPrep), barWeight: trimNum(p.bar),
            plates: p.plateSet.map { trimNum($0) }.joined(separator: " "),
            units: p.imperial ? "imperial" : "metric")
        _draft = State(initialValue: initial)
        opened = initial
    }

    private var isDirty: Bool { draft != opened }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    PillSelect(options: Self.sections, title: { t("set.sec_" + $0) }, selection: $section)
                    switch section {
                    case "training": trainingSection
                    case "health":   healthSection
                    case "data":     dataSection
                    default:         profileSection
                    }
                    if section == "profile" || section == "training" {
                        BigButton(title: t("save")) { save() }
                    }
                    Text(appVersionLabel).font(.ui(12)).foregroundColor(Theme.sub)
                        .frame(maxWidth: .infinity).padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(t("set.unsaved_q"), isPresented: $askDiscard, titleVisibility: .visible) {
            Button(t("save")) { save() }
            Button(t("set.unsaved_discard"), role: .destructive) { dismiss() }
            Button(t("cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showGuide) { WatchSetupGuide() }
        .sheet(isPresented: $showHealthHistory) { HealthHistoryView() }
        .sheet(isPresented: $showGoals) { GoalEditorView() }
        .sheet(isPresented: $showManager) { ExerciseManagerView() }
    }

    private var header: some View {
        HStack {
            Text(t("set.title").uppercased()).font(.head(18, .bold)).tracking(1).foregroundColor(Theme.txt)
            Spacer()
            Button { if isDirty { askDiscard = true } else { dismiss() } } label: {
                Image(systemName: "xmark").accessibilityLabel(t("a11y.close")).foregroundColor(Theme.sub)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            }
        }
        .padding(.top, 18)
    }

    // MARK: Binding straight to a preference, applied at once
    private func pref<T>(_ get: @escaping (Prefs) -> T, _ set: @escaping (inout Prefs, T) -> Void) -> Binding<T> {
        Binding(get: { get(store.prefs) }, set: { value in
            var p = store.prefs
            set(&p, value)
            store.prefs = p
        })
    }

    private func toggleRow(_ title: String, _ hint: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(14, weight: .medium)).foregroundColor(Theme.txt)
                if !hint.isEmpty { Text(hint).font(.ui(10)).foregroundColor(Theme.sub) }
            }
        }
        .tint(Theme.acc)
    }

    // MARK: Profile
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                Lbl(text: t("set.profile"))
                Spacer().frame(height: 14)
                ProfileFormBody(f: $draft.profile, showGoals: false)
            }
            Card {
                FieldRow(label: t("set.units")) {
                    PillSelect(options: ["metric", "imperial"],
                               title: { $0 == "metric" ? t("set.metric") : t("set.imperial") },
                               selection: $draft.units)
                }
                Spacer().frame(height: 14)
                GhostButton(title: t("set.goals_open"), color: Theme.acc) { showGoals = true }
            }
        }
    }

    // MARK: Training
    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                FieldRow(label: t("set.timer")) { InputField(placeholder: "60", text: $draft.timerSec, keyboard: .numberPad) }
                Spacer().frame(height: 14)
                toggleRow(t("set.auto_rest"), t("set.auto_rest_hint"), pref({ $0.autoRest }, { $0.autoRestTimer = $1 }))
                Spacer().frame(height: 14)
                toggleRow(t("set.live_activity"), t("set.live_activity_hint"),
                          pref({ $0.liveActivityEnabled }, { $0.liveActivity = $1 }))
            }
            Card {
                FieldRow(label: t("set.hold_prep")) { InputField(placeholder: "7", text: $draft.holdPrep, keyboard: .numberPad) }
                Text(t("set.hold_prep_hint")).font(.ui(10)).foregroundColor(Theme.sub).padding(.top, 6)
                Spacer().frame(height: 14)
                FieldRow(label: t("set.bar_weight")) { InputField(placeholder: "20", text: $draft.barWeight) }
                Spacer().frame(height: 14)
                FieldRow(label: t("set.plates")) { InputField(placeholder: "25 20 15 10 5 2.5 1.25", text: $draft.plates) }
            }
            volumeTargetsCard
            remindersCard
            GhostButton(title: t("set.manage_ex"), color: Theme.blue) { showManager = true }
        }
    }

    private var remindersCard: some View {
        Card {
            Lbl(text: t("rem.title"), color: Theme.acc2).padding(.bottom, 10)
            toggleRow(t("rem.weigh"), t("rem.weigh_hint"), reminder({ $0.remindWeighIn }, { $0.remindWeighIn = $1 }))
            Spacer().frame(height: 12)
            toggleRow(t("rem.workout"), t("rem.workout_hint"), reminder({ $0.remindWorkout }, { $0.remindWorkout = $1 }))
            Spacer().frame(height: 12)
            toggleRow(t("rem.weekly"), t("rem.weekly_hint"), reminder({ $0.remindWeekly }, { $0.remindWeekly = $1 }))
        }
    }

    /// A reminder switch: turning one on asks for notifications first.
    private func reminder(_ get: @escaping (Prefs) -> Bool?, _ set: @escaping (inout Prefs, Bool?) -> Void) -> Binding<Bool> {
        Binding(get: { get(store.prefs) == true }, set: { on in
            let apply = { (value: Bool) in
                var p = store.prefs; set(&p, value ? true : nil); store.prefs = p
                Reminders.reschedule(store)
            }
            guard on else { apply(false); return }
            Reminders.requestPermission { granted in
                if granted { apply(true) } else { toast.show(t("rem.denied"), duration: ToastCenter.longDuration) }
            }
        })
    }

    private static let volumeGroups: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms, .core]

    private var volumeTargetsCard: some View {
        Card {
            Lbl(text: t("set.vol_targets"), color: Theme.acc2).padding(.bottom, 4)
            Text(t("set.vol_targets_hint")).font(.ui(10)).foregroundColor(Theme.sub).padding(.bottom, 8)
            ForEach(Self.volumeGroups) { g in
                Stepper(value: Binding(get: { store.volumeTarget(g) }, set: { setVolumeTarget(g, $0) }), in: 4...30) {
                    HStack {
                        Circle().fill(Color(hex: g.color)).frame(width: 8, height: 8)
                        Text(t(g.labelKey)).font(.ui(13)).foregroundColor(Theme.txt)
                        Spacer()
                        Text("\(store.volumeTarget(g))").font(.num(15)).foregroundColor(Theme.acc2)
                    }
                }
            }
            if store.prefs.volumeTargets?.isEmpty == false {
                GhostButton(title: t("set.vol_reset"), color: Theme.sub) {
                    var p = store.prefs; p.volumeTargets = nil; store.prefs = p
                }
                .padding(.top, 8)
            }
        }
    }

    private func setVolumeTarget(_ g: MuscleGroup, _ value: Int) {
        var p = store.prefs
        var targets = p.volumeTargets ?? [:]
        targets[g.rawValue] = value
        p.volumeTargets = targets
        store.prefs = p
    }

    // MARK: Health
    private var healthSection: some View {
        Card {
            HStack(spacing: 2) {
                Lbl(text: t("hk.connect"), color: Theme.acc2)
                InfoButton(id: .steps, color: Theme.acc2)
                Spacer()
            }
            .padding(.bottom, 8)
            Text(t("hk.hint")).font(.ui(11)).foregroundColor(Theme.sub).lineSpacing(3).padding(.bottom, 12)
            if HealthKitManager.shared.isAvailable {
                if store.prefs.healthKitEnabled { connectedHealth } else {
                    FilledButton(title: t("hk.connect")) {
                        store.syncHealth { ok, n, sources in
                            if ok { var p = store.prefs; p.healthKit = true; store.prefs = p; toast.show(syncMsg(n, sources)) }
                        }
                    }
                }
                // Per-watch setup guide (Garmin/Polar/… toggles + GPX/TCX import).
                Spacer().frame(height: 14)
                GhostButton(title: t("guide.open"), color: Theme.blue) { showGuide = true }.padding(.bottom, 4)
            } else {
                Text(t("hk.unavailable")).font(.ui(12)).foregroundColor(Theme.sub)
            }
        }
    }

    private var connectedHealth: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HealthStatusRow()
                Spacer()
                GhostButton(title: t("hk.sync"), color: Theme.acc) {
                    store.syncHealth { ok, n, sources in if ok { toast.show(syncMsg(n, sources)) } }
                }
            }
            Text(t("hk.choose").uppercased()).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                .padding(.top, 12).padding(.bottom, 8)
            ForEach(HealthCategory.allCases) { cat in
                Toggle(isOn: pref({ $0.healthCategories.contains(cat.rawValue) }, { p, on in
                    var cats = p.healthCategories
                    if on { cats.insert(cat.rawValue) } else { cats.remove(cat.rawValue) }
                    p.setHealthCategories(cats)
                })) {
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon).font(.ui(12)).foregroundColor(Theme.acc2).frame(width: 18)
                        Text(t(cat.labelKey)).font(.ui(13)).foregroundColor(Theme.txt)
                    }
                }
                .tint(Theme.acc)
            }
            Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 10)
            toggleRow(t("hk.import_workouts"), t("hk.import_workouts_hint"),
                      pref({ $0.importWorkoutsEnabled }, { $0.importWorkouts = $1 }))
            Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 10)
            toggleRow(t("hk.export"), t("hk.export_hint"), pref({ $0.exportsToHealth }, { $0.exportToHealth = $1 }))
            Rectangle().fill(Theme.brd).frame(height: 1).padding(.vertical, 10)
            // Past daily data: pick a window, import it, and see exactly which
            // categories actually arrived.
            Button { tap(); showHealthHistory = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.ui(13, weight: .bold))
                    Text(t("hk.history")).font(.ui(13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.ui(11))
                }
                .foregroundColor(Theme.acc2)
                .padding(.vertical, 10)
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: Data
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BackupCard()
            ExternalBackupCard()
        }
    }

    /// Build the post-sync toast: a count + the source apps when workouts were
    /// imported, otherwise the plain "synced" confirmation.
    private func syncMsg(_ n: Int, _ sources: [String]) -> String {
        guard n > 0 else { return t("hk.synced") }
        let src = sources.isEmpty ? "" : " · " + sources.joined(separator: ", ")
        return "\(n) \(t("hk.imported_n"))\(src)"
    }

    private func save() {
        var p = store.prefs
        // Apply the unit choice first so ProfileFields converts its height/weight
        // inputs against the right system.
        p.units = draft.units
        Units.imperial = (draft.units == "imperial")
        draft.profile.apply(to: &p, includingGoals: false)
        if let ts = Int(draft.timerSec), ts > 0 { p.timer = ts }
        // 0 is a valid choice here (skip the lead-in), so only a non-numeric entry
        // falls back to the stored value.
        if let hp = Int(draft.holdPrep) { p.holdPrepSec = max(0, min(30, hp)) }
        if pf(draft.barWeight) > 0 { p.barWeight = pf(draft.barWeight) }
        // Split on spaces/semicolons only — a comma is a decimal separator here
        // ("2,5" is one plate, not two), and pf() already accepts both forms.
        let plates = draft.plates
            .split(whereSeparator: { $0.isWhitespace || $0 == ";" })
            .map { pf(String($0)) }
            .filter { $0 >= Prefs.smallestPlateKg }
        p.plates = plates.isEmpty ? nil : plates.sorted(by: >)
        store.prefs = p
        store.syncLang()
        haptic(.success)
        dismiss()
    }
}

// MARK: - Health link status (Settings)
/// Whether Health is connected, reading, or failing, and when it last answered.
/// A refused permission looks like an empty read, so the failure line sends the
/// person to the system settings.
struct HealthStatusRow: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(text).font(.head(11, .semibold)).tracking(0.3).foregroundColor(color)
            }
            if store.healthFailed {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text(t("hk.open_settings")).font(.ui(11, weight: .semibold)).foregroundColor(Theme.acc2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var color: Color { store.healthFailed ? Theme.red : (store.healthSyncing ? Theme.acc2 : Theme.good) }

    private var text: String {
        if store.healthSyncing { return t("hk.status_syncing") }
        if store.healthFailed { return t("hk.status_failed") }
        guard let last = store.prefs.lastHealthSync else { return t("hk.connected") }
        let when = Date(timeIntervalSince1970: last).formatted(date: .omitted, time: .shortened)
        return t("hk.status_last", when)
    }
}

private struct CSVFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

// MARK: - Backup: export and import the data file (Settings › Data)
struct BackupCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @State private var shareURL: IdentURL?
    @State private var csv: CSVFiles?
    @State private var importing = false
    @State private var pendingImport: IdentURL?

    var body: some View {
        Card {
            Lbl(text: t("home.backup")).padding(.bottom, 4)
            Text(t("home.backup_auto")).font(.ui(10)).foregroundColor(Theme.sub).padding(.bottom, 10)
            HStack(spacing: 10) {
                GhostButton(title: t("home.export")) {
                    if let url = store.exportFile() { shareURL = IdentURL(url: url) }
                    else { toast.show(t("home.export_failed")) }
                }
                GhostButton(title: t("home.import")) { importing = true }
            }
            GhostButton(title: t("bk.csv"), color: Theme.blue) {
                if let urls = CSVExport.files(store) { csv = CSVFiles(urls: urls) } else { toast.show(t("home.export_failed")) }
            }
            .padding(.top, 8)
            Text(t("bk.csv_hint")).font(.ui(10)).foregroundColor(Theme.sub).padding(.top, 4)
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .sheet(item: $csv) { files in ShareSheet(items: files.urls) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): pendingImport = IdentURL(url: url)
            case .failure:          toast.show(t("body.import_cancelled"))
            }
        }
        // Importing replaces everything, so it is confirmed first. The store keeps a
        // copy of the current data either way.
        .confirmationDialog(t("body.import_q"), isPresented: Binding(
            get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible, presenting: pendingImport) { file in
            Button(t("body.import_replace"), role: .destructive) { importBackup(file.url) }
            Button(t("cancel"), role: .cancel) {}
        } message: { _ in Text(t("body.import_q_body")) }
    }

    private func importBackup(_ url: URL) {
        switch store.importFile(url) {
        case .imported:       haptic(.success); toast.show(t("body.imported"))
        case .invalidFile:    haptic(.error); toast.show(t("body.invalid_file"))
        case .snapshotFailed: haptic(.error); toast.show(t("body.import_snapshot_failed"))
        }
    }
}

// MARK: - Daily copy outside the phone (Settings › Data)
struct ExternalBackupCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @State private var picking = false
    /// Bumped after a change so the folder name and last copy are read again.
    @State private var refresh = 0

    var body: some View {
        let folder = ExternalBackup.folderName()
        Card {
            Lbl(text: t("bk.title"), color: Theme.acc2).padding(.bottom, 4)
            Text(t("bk.hint")).font(.ui(11)).foregroundColor(Theme.sub).lineSpacing(3).padding(.bottom, 10)
            if let folder {
                Text(t("bk.folder", folder)).font(.ui(13, weight: .semibold)).foregroundColor(Theme.txt)
                Text(ExternalBackup.lastAttemptFailed() ? t("bk.failed")
                     : (ExternalBackup.lastCopyDay().map { t("bk.last", fmtDM($0)) } ?? t("bk.pending")))
                    .font(.ui(11)).foregroundColor(ExternalBackup.lastAttemptFailed() ? Theme.red : Theme.sub)
                    .padding(.top, 2).padding(.bottom, 10)
                HStack(spacing: 10) {
                    GhostButton(title: t("bk.copy_now"), color: Theme.acc) { copyNow() }
                    GhostButton(title: t("bk.change"), color: Theme.blue) { picking = true }
                }
                GhostButton(title: t("bk.stop"), color: Theme.sub) { ExternalBackup.forget(); refresh += 1 }
                    .padding(.top, 8)
            } else {
                FilledButton(title: t("bk.choose")) { picking = true }
            }
        }
        .id(refresh)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do {
                try ExternalBackup.choose(url)
                copyNow()
            } catch {
                appLog.error("Backup folder not usable: \(String(describing: error), privacy: .public)")
                toast.show(t("bk.folder_failed"), duration: ToastCenter.longDuration)
            }
        }
    }

    private func copyNow() {
        store.flushNow()
        let failed = ExternalBackup.copyIfDue(store.dataURL, day: today(), force: true) != nil
        toast.show(t(failed ? "bk.failed" : "bk.copied"), duration: failed ? ToastCenter.longDuration : ToastCenter.defaultDuration)
        refresh += 1
    }
}
