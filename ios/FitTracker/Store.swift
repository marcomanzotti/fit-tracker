import SwiftUI
import Combine
import WidgetKit

final class Store: ObservableObject {
    @Published var daily: [DailyEntry] = [] { didSet { sortedDailyCache = nil } }
    /// `daily` in date order, computed once per change: the dashboard reads it
    /// (through lastWeight and friends) many times in a single render.
    private var sortedDailyCache: [DailyEntry]?
    @Published var sessions: [WorkoutSession] = []
    @Published var body: [BodyEntry] = []
    @Published var plans: [WorkoutPlan] = []
    @Published var cardioTypes: [CardioType] = []
    @Published var foods: [FoodItem] = []
    @Published var exerciseItems: [ExerciseItem] = []
    @Published var recipes: [Recipe] = []
    @Published var prefs: Prefs = Prefs()

    /// Something went wrong reading or writing the saved file. The UI shows it; it
    /// is never swallowed into "no data".
    enum StorageProblem: Equatable {
        /// The data file could not be decoded and no backup could replace it. The
        /// file was set aside untouched and the app started empty.
        case unreadable
        /// The data file could not be decoded; this backup was loaded in its place.
        case recovered(from: String)
        /// The last write failed, with the system's reason.
        case saveFailed(String)
    }
    @Published private(set) var storageProblem: StorageProblem?

    enum ImportOutcome: Equatable { case imported, invalidFile, snapshotFailed }

    private static let dataFileName = "fittracker.json"
    private static let backupPrefix = "backup-"
    private static let corruptPrefix = "fittracker.corrupt-"
    private static let preImportPrefix = "pre-import-"
    private static let backupsKept = 30
    private static let preImportSnapshotsKept = 3
    private static let autosaveDebounceSeconds = 0.5

    private var loaded = false
    private var isSyncingHealth = false
    /// False only when an unreadable file could not be moved out of the way: saving
    /// would then overwrite the one copy of the user's history.
    private var canSave = true
    private var bag = Set<AnyCancellable>()
    private let directory: URL
    /// Serial, so writes land in the order the changes happened.
    private let writeQueue = DispatchQueue(label: "fittracker.store.write", qos: .utility)

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var dataURL: URL { directory.appendingPathComponent(Store.dataFileName) }

    init(directory: URL = Store.documentsDirectory) {
        self.directory = directory
        load()
        // Autosave: any change to the published collections persists after a short debounce.
        let pubs: [AnyPublisher<Void, Never>] = [
            $daily.map { _ in () }.eraseToAnyPublisher(),
            $sessions.map { _ in () }.eraseToAnyPublisher(),
            $body.map { _ in () }.eraseToAnyPublisher(),
            $plans.map { _ in () }.eraseToAnyPublisher(),
            $cardioTypes.map { _ in () }.eraseToAnyPublisher(),
            $foods.map { _ in () }.eraseToAnyPublisher(),
            $exerciseItems.map { _ in () }.eraseToAnyPublisher(),
            $recipes.map { _ in () }.eraseToAnyPublisher(),
            $prefs.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(pubs)
            .debounce(for: .seconds(Store.autosaveDebounceSeconds), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save() }
            .store(in: &bag)
    }

    // MARK: Persistence
    func load() {
        if let document = readDocument() { apply(document) }
        if plans.isEmpty { plans = Store.defaultPlans() }
        if cardioTypes.isEmpty { cardioTypes = Store.defaultCardioTypes() }
        // Register the default plans' exercises so a fresh install's library isn't
        // empty, then layer the curated catalog on top (once, never overwriting).
        for p in plans { registerPlanExercises(p) }
        seedExerciseLibraryIfNeeded()
        syncLang()
        loaded = true
    }

    /// The saved document, or nil on a first launch. A file that exists but cannot
    /// be decoded is never treated as "no data": it is moved aside under a dated
    /// name and the newest readable backup takes its place, so the autosave that
    /// follows launch has nothing of the user's left to overwrite.
    private func readDocument() -> AppData? {
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return nil }
        do {
            return migrate(try Store.decodeDocument(at: dataURL))
        } catch let error as DecodingError {
            appLog.error("Data file unreadable: \(String(describing: error), privacy: .public)")
            canSave = setAsideUnreadableFile()
            if let backup = newestReadableBackup() {
                storageProblem = .recovered(from: backup.name)
                return migrate(backup.document)
            }
            storageProblem = .unreadable
            return nil
        } catch {
            // The file is there but could not be opened (for instance the phone has
            // not been unlocked since a restart). It is not damaged: leave it where
            // it is, start empty for this run and write nothing over it.
            appLog.error("Data file not accessible: \(String(describing: error), privacy: .public)")
            canSave = false
            storageProblem = .unreadable
            return nil
        }
    }

    private static func decodeDocument(at url: URL) throws -> AppData {
        try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
    }

    /// Move the unreadable file to `fittracker.corrupt-<timestamp>.json`. Returns
    /// false when it could not be moved, in which case saving stays off.
    private func setAsideUnreadableFile() -> Bool {
        let stamp = Store.fileStampFormatter.string(from: Date())
        let aside = directory.appendingPathComponent("\(Store.corruptPrefix)\(stamp).json")
        do {
            try FileManager.default.moveItem(at: dataURL, to: aside)
            return true
        } catch {
            appLog.error("Could not set the unreadable file aside: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func newestReadableBackup() -> (name: String, document: AppData)? {
        for url in datedFiles(prefix: Store.backupPrefix) {
            do {
                return (url.lastPathComponent, try Store.decodeDocument(at: url))
            } catch {
                appLog.error("Backup \(url.lastPathComponent, privacy: .public) unreadable, trying an older one")
            }
        }
        return nil
    }

    /// Files named `<prefix><sortable date>.json`, newest first (the date in the
    /// name makes lexicographic order chronological).
    private func datedFiles(prefix: String) -> [URL] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            appLog.error("Could not list \(self.directory.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return []
        }
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Upgrade a decoded document to the current schema. The guiding rule is "never
    /// drop a user's data": every field added so far is optional, so old backups
    /// decode untouched and only need their version normalized. When a future change
    /// can't be expressed as an additive optional field (a rename, a semantic shift),
    /// add an explicit `case` here that rewrites the data and bumps the version — the
    /// historical record always survives the upgrade.
    private func migrate(_ decoded: AppData) -> AppData {
        var a = decoded
        let version = a.schemaVersion ?? 1     // nil predates the field => version 1
        switch version {
        // case 1: <future migration to v2 goes here, then `fallthrough`>
        default: break
        }
        a.schemaVersion = AppData.currentSchemaVersion
        return a
    }

    private func apply(_ a: AppData) {
        daily = a.daily; sessions = a.sessions; body = a.body; prefs = a.prefs
        plans = a.plans.isEmpty ? Store.defaultPlans() : a.plans
        let savedCardio = a.cardioTypes ?? []
        cardioTypes = savedCardio.isEmpty ? Store.defaultCardioTypes() : savedCardio
        foods = a.foods ?? []
        exerciseItems = a.exerciseItems ?? []
        recipes = a.recipes ?? []
    }

    private var currentDocument: AppData {
        AppData(daily: daily, sessions: sessions, body: body, plans: plans, prefs: prefs,
                cardioTypes: cardioTypes, foods: foods, exerciseItems: exerciseItems, recipes: recipes)
    }

    /// Keep the global localization language + unit system in sync with prefs.
    func syncLang() { L.lang = prefs.langCode; Units.imperial = prefs.imperial }

    /// Persist the current state. The snapshot is taken here; encoding and the disk
    /// write happen off the main thread.
    func save() {
        guard loaded, canSave else { return }
        let document = currentDocument
        let widget = widgetSnapshot
        writeQueue.async { [weak self] in
            self?.write(document)
            self?.publish(widget)
        }
    }

    /// Write the current state before returning. Called when the app leaves the
    /// foreground, so an edit made inside the autosave debounce is not lost if the
    /// system then suspends or kills the app.
    func flushNow() {
        guard loaded, canSave else { return }
        let document = currentDocument
        writeQueue.sync { write(document) }
    }

    private func write(_ document: AppData) {
        do {
            let data = try JSONEncoder().encode(document)
            try keepDatedBackup()
            try data.write(to: dataURL, options: .atomic)
            prune(prefix: Store.backupPrefix, keep: Store.backupsKept)
            reportSave(failure: nil)
        } catch {
            appLog.error("Save failed: \(String(describing: error), privacy: .public)")
            reportSave(failure: error.localizedDescription)
        }
    }

    /// Publish a failed write, or clear the previous failure once a write succeeds.
    /// A load problem stays up until the user has acknowledged it.
    private func reportSave(failure: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let failure {
                self.storageProblem = .saveFailed(failure)
            } else if case .saveFailed = self.storageProblem {
                self.storageProblem = nil
            }
        }
    }

    /// The load alert was read. If saving is off, the banner takes over and stays:
    /// nothing typed from here on is being kept, and that must remain visible.
    func acknowledgeStorageProblem() {
        storageProblem = canSave ? nil : .saveFailed(L.t("store.saving_off"))
    }

    // MARK: Widget
    /// What the Home / Lock Screen widget shows right now.
    private var widgetSnapshot: WidgetSnapshot {
        let next = nextUp()
        return WidgetSnapshot(nextName: next?.name ?? "", nextColor: next?.color ?? "ffe000",
                              nextIcon: next?.icon ?? "dumbbell.fill", streak: streak,
                              kcalToday: dailyEntry(today())?.totalKcal ?? 0,
                              kcalTarget: Int(energyTargets().target))
    }
    private var publishedWidget: WidgetSnapshot?

    /// Hand the snapshot to the widget, only when it changed (reloads are budgeted
    /// by the system) and only from the real store, never from a test instance.
    private func publish(_ snapshot: WidgetSnapshot) {
        guard directory == Store.documentsDirectory, snapshot != publishedWidget else { return }
        do {
            try snapshot.save()
            publishedWidget = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        } catch {
            appLog.error("Widget snapshot not written: \(String(describing: error), privacy: .public)")
        }
    }

    /// One snapshot per day in Documents (visible in the Files app), taken from the
    /// file as it stood before the day's first save. It is the previous state, so a
    /// bad change made today can still be undone from it.
    private func keepDatedBackup() throws {
        let fm = FileManager.default
        let backup = directory.appendingPathComponent("\(Store.backupPrefix)\(today()).json")
        guard fm.fileExists(atPath: dataURL.path), !fm.fileExists(atPath: backup.path) else { return }
        try fm.copyItem(at: dataURL, to: backup)
    }

    /// Delete the oldest files with this prefix, keeping the `keep` most recent. The
    /// primary file holds the complete history, so this only trims redundant copies.
    private func prune(prefix: String, keep: Int) {
        for url in datedFiles(prefix: prefix).dropFirst(keep) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                appLog.error("Could not remove \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    private static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    /// Produce a JSON file URL for sharing/export, or nil when it could not be written.
    func exportFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fittracker-\(today()).json")
        do {
            try JSONEncoder.pretty.encode(currentDocument).write(to: url, options: .atomic)
            return url
        } catch {
            appLog.error("Export failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Replace everything with the contents of a backup file. The state being
    /// replaced is first written to `pre-import-<timestamp>.json`; without that
    /// copy nothing is replaced.
    func importFile(_ url: URL) -> ImportOutcome {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let incoming: AppData
        do {
            incoming = migrate(try Store.decodeDocument(at: url))
        } catch {
            appLog.error("Import file unreadable: \(String(describing: error), privacy: .public)")
            return .invalidFile
        }
        do {
            let stamp = Store.fileStampFormatter.string(from: Date())
            let snapshot = directory.appendingPathComponent("\(Store.preImportPrefix)\(stamp).json")
            try JSONEncoder().encode(currentDocument).write(to: snapshot, options: .atomic)
            prune(prefix: Store.preImportPrefix, keep: Store.preImportSnapshotsKept)
        } catch {
            appLog.error("Pre-import snapshot failed: \(String(describing: error), privacy: .public)")
            return .snapshotFailed
        }
        apply(incoming)
        syncLang()
        canSave = true
        storageProblem = nil
        return .imported
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }
}

// MARK: - Default starting templates (3-day Push / Pull / Legs split, fully editable)
// Names and exercises are English defaults; everything is customizable per user.
extension Store {
    static func defaultPlans() -> [WorkoutPlan] {
        [
            WorkoutPlan(id: "p1", name: "Push", sub: "Chest + Shoulders + Triceps", color: "ff5a52", exercises: [
                PlanExercise(name: "Barbell bench press", sets: 4, reps: "6-8"),
                PlanExercise(name: "Incline dumbbell press", sets: 3, reps: "8-10"),
                PlanExercise(name: "Seated dumbbell shoulder press", sets: 3, reps: "10"),
                PlanExercise(name: "Cable lateral raise", sets: 3, reps: "12-15"),
                PlanExercise(name: "Cable chest fly", sets: 3, reps: "12"),
                PlanExercise(name: "Triceps rope pushdown", sets: 3, reps: "12")
            ]),
            WorkoutPlan(id: "p2", name: "Pull", sub: "Back + Biceps + Rear Delts", color: "4fb8c4", exercises: [
                PlanExercise(name: "Pull-up", sets: 4, reps: "6-10"),
                PlanExercise(name: "Barbell row", sets: 3, reps: "8-10"),
                PlanExercise(name: "Lat pulldown", sets: 3, reps: "10-12"),
                PlanExercise(name: "Seated cable row", sets: 3, reps: "12"),
                PlanExercise(name: "Face pull", sets: 3, reps: "15"),
                PlanExercise(name: "EZ-bar biceps curl", sets: 3, reps: "10-12")
            ]),
            WorkoutPlan(id: "p3", name: "Legs", sub: "Quads + Hamstrings + Calves", color: "ffb000", exercises: [
                PlanExercise(name: "Barbell back squat", sets: 4, reps: "6-8"),
                PlanExercise(name: "Romanian deadlift", sets: 3, reps: "8-10"),
                PlanExercise(name: "Leg press", sets: 3, reps: "12"),
                PlanExercise(name: "Seated leg curl", sets: 3, reps: "12"),
                PlanExercise(name: "Leg extension", sets: 3, reps: "15"),
                PlanExercise(name: "Standing calf raise", sets: 4, reps: "15")
            ])
        ]
    }

    /// Default customizable cardio activities (colors from Theme.cardioColors).
    static func defaultCardioTypes() -> [CardioType] {
        [
            CardioType(id: "c-run",  name: "Running", sport: "running",  color: "ff5a52"),
            CardioType(id: "c-swim", name: "Swimming", sport: "swimming", color: "4fb8c4"),
            CardioType(id: "c-bike", name: "Cycling", sport: "cycling",  color: "7fc950"),
            CardioType(id: "c-walk", name: "Walking", sport: "walking",  color: "b08fff")
        ]
    }

    // MARK: Cardio type mutations
    func commitCardioType(_ ct: CardioType) {
        if let i = cardioTypes.firstIndex(where: { $0.id == ct.id }) { cardioTypes[i] = ct }
        else { cardioTypes.append(ct) }
    }
    func deleteCardioType(_ id: String) {
        cardioTypes.removeAll { $0.id == id }
        unschedule(id)
    }
    func deletePlan(_ id: String) {
        plans.removeAll { $0.id == id }
        unschedule(id)
    }
    /// A deleted plan or activity leaves the weekly schedule too.
    private func unschedule(_ id: String) {
        guard let schedule = prefs.schedule, schedule.contains(id) else { return }
        prefs.schedule = schedule.map { $0 == id ? "" : $0 }
    }
}

// MARK: - Derived data / domain logic (ports of the web app helpers)
extension Store {
    var sortedDaily: [DailyEntry] {
        if let cached = sortedDailyCache { return cached }
        let sorted = daily.sorted { $0.date < $1.date }
        sortedDailyCache = sorted
        return sorted
    }

    /// One time-bucketed average point (week/month/year) for an overview chart.
    struct WeekPoint: Identifiable { var date: String; var value: Double; var id: String { date } }

    /// Bucket granularity for the overview charts. The overview shows `.week` over
    /// ~3 months by default (readable trend); the expanded view lets the user switch.
    enum ChartGranularity: String, CaseIterable, Identifiable {
        case day, week, month, year
        var id: String { rawValue }
        /// How far back to look by default for this granularity.
        var months: Int {
            switch self {
            case .day:   return 3
            case .week:  return 6
            case .month: return 24
            case .year:  return 120
            }
        }
        /// Calendar components that identify a bucket.
        var comps: Set<Calendar.Component> {
            switch self {
            case .day:   return [.year, .month, .day]
            case .week:  return [.yearForWeekOfYear, .weekOfYear]
            case .month: return [.year, .month]
            case .year:  return [.year]
            }
        }
    }

    /// Generic time-bucketed average of a daily metric. Groups the days that carry a
    /// value into buckets of the chosen granularity and averages each bucket, so a
    /// crowded daily axis collapses into a readable trend. Used by every overview
    /// chart (sleep, steps, weight, BMI, VO2…) and their expanded views.
    func metricSeries(_ value: @escaping (DailyEntry) -> Double?,
                      granularity: ChartGranularity, months: Int? = nil) -> [WeekPoint] {
        let cal = Calendar.current
        let back = months ?? granularity.months
        guard let cutoff = cal.date(byAdding: .month, value: -back, to: Date()) else { return [] }
        var byBucket: [Date: (sum: Double, n: Int)] = [:]
        for e in daily {
            guard let v = value(e), v.isFinite,
                  let d = isoFormatter.date(from: e.date), d >= cutoff else { continue }
            let comps = cal.dateComponents(granularity.comps, from: d)
            guard let bucket = cal.date(from: comps) else { continue }
            var acc = byBucket[bucket] ?? (0, 0)
            acc.sum += v; acc.n += 1
            byBucket[bucket] = acc
        }
        return byBucket.keys.sorted().map { b in
            let acc = byBucket[b]!
            return WeekPoint(date: bucketLabel(b, granularity: granularity),
                             value: ((acc.sum / Double(acc.n)) * 10).rounded() / 10)
        }
    }

    /// Compact axis label for a bucket start date, tuned per granularity.
    private func bucketLabel(_ d: Date, granularity: ChartGranularity) -> String {
        let format: String
        switch granularity {
        case .day, .week: format = "MM-dd"
        case .month:      format = "yyyy-MM"
        case .year:       format = "yyyy"
        }
        return cachedFormatter(format).string(from: d)
    }

    /// Most recent lastUsed date across a family's variants (for "recent" sorting).
    func familyLastUsed(_ f: ExFamily) -> String {
        f.names.compactMap { n in exerciseItems.first { $0.name == n }?.lastUsed }.max() ?? ""
    }

    /// Number of logged sessions that include any variant of a family.
    func familySessionCount(_ f: ExFamily) -> Int {
        let names = Set(f.names)
        return sessions.filter { s in s.exercises.contains { names.contains($0.name) } }.count
    }

    /// Number of past sessions that logged this exact exercise name.
    func sessionCount(forExercise name: String) -> Int {
        sessions.filter { s in s.exercises.contains { $0.name == name } }.count
    }

    /// Latest known VO2 max (carried forward — Apple records it sparsely).
    var latestVO2: Double? { sortedDaily.last(where: { ($0.vo2max ?? 0) > 0 })?.vo2max }

    var lastWeight: Double {
        sortedDaily.last(where: { $0.weight != nil })?.weight ?? prefs.startWeight
    }

    func plan(_ id: String) -> WorkoutPlan? { plans.first { $0.id == id } }
    func cardioType(_ id: String) -> CardioType? { cardioTypes.first { $0.id == id } }

    func bmi(_ w: Double) -> Double { ((w / (prefs.height * prefs.height)) * 10).rounded() / 10 }

    func bmiCategory(_ b: Double) -> (String, Color) {
        if b < 18.5 { return (L.t("bmi.under"), Theme.blue) }
        if b < 25   { return (L.t("bmi.normal"), Theme.good) }
        if b < 30   { return (L.t("bmi.over"), Theme.acc2) }
        return (L.t("bmi.obese"), Theme.red)
    }

    // MARK: - Body-fat categories (sex-specific, ACE/ACSM ranges)
    // BMI stays the primary number, but because it can't tell muscle from fat,
    // whenever a body-fat % is known we classify by body fat instead. The key
    // rule: a man under 18% or a woman under 25% body fat is NOT clinically
    // overweight even if BMI ≥ 25 (they're simply muscular).
    enum BFCategory: String {
        case essential, athlete, fitness, average, overweight, obese
        var key: String { "bf." + rawValue }
        var color: Color {
            switch self {
            case .essential:  return Theme.blue       // very low — caution
            case .athlete:    return Theme.good
            case .fitness:    return Theme.good
            case .average:    return Theme.acc2
            case .overweight: return Theme.acc2
            case .obese:      return Theme.red
            }
        }
    }

    func bfCategory(_ bf: Double, sex: String) -> BFCategory {
        if sex == "f" {
            switch bf {
            case ..<14:  return .essential   // 10–13
            case ..<21:  return .athlete     // 14–20
            case ..<25:  return .fitness     // 21–24
            case ..<32:  return .average     // 25–31
            case ..<37:  return .overweight  // 32–36
            default:     return .obese       // 37+
            }
        } else {
            switch bf {
            case ..<6:   return .essential   // 2–5
            case ..<14:  return .athlete     // 6–13
            case ..<18:  return .fitness     // 14–17
            case ..<25:  return .average     // 18–24
            case ..<30:  return .overweight  // 25–29
            default:     return .obese       // 30+
            }
        }
    }

    /// Threshold below which a high BMI is muscle, not fat: men <18%, women <25%.
    private func notOverweightByFat(_ bf: Double) -> Bool {
        prefs.sex_ == "f" ? bf < 25 : bf < 18
    }

    /// The comment shown under the weight/kg box. When body fat is known it
    /// classifies by body fat (more accurate than BMI for muscular builds); the
    /// key rule prevents a lean, muscular person reading as "overweight".
    func bmiComment(weight: Double) -> (text: String, color: Color) {
        let b = bmi(weight)
        if let bf = currentBF {
            let cat = bfCategory(bf, sex: prefs.sex_)
            // High BMI but low fat → surface that it's muscle, not excess fat.
            if b >= 25 && notOverweightByFat(bf) {
                return ("BMI \(trimNum(b)) · \(L.t("bf.muscular"))", Theme.good)
            }
            return ("BMI \(trimNum(b)) · \(L.t(cat.key))", cat.color)
        }
        let std = bmiCategory(b)
        return ("BMI \(trimNum(b)) · \(std.0)", std.1)
    }

    /// US-Navy body-fat estimate (cm). The men's and women's equations are
    /// genuinely different: men use waist−neck; women use waist+hip−neck (the hip
    /// term is required, so a woman with no hip measurement returns nil rather than
    /// a wrong male-formula number). This was previously male-only for everyone.
    static let plausibleBodyFat = 2.0...60.0
    static let plausibleWeightKg = 30.0...250.0
    static let plausibleLengthCm = 10.0...300.0
    func bfNavy(waist: Double?, neck: Double?, hip: Double? = nil) -> Double? {
        let h = prefs.height * 100                       // height in cm
        guard let waist, let neck, waist > neck, h > 0 else { return nil }
        let v: Double
        if prefs.sex_ == "f" {
            guard let hip, (waist + hip) > neck else { return nil }
            v = 163.205 * log10(waist + hip - neck) - 97.684 * log10(h) - 78.387
        } else {
            v = 86.010 * log10(waist - neck) - 70.041 * log10(h) + 36.76
        }
        // Measurements that don't describe a human body give nonsense (a waist
        // barely above the neck is a large negative %): report nothing instead.
        guard Store.plausibleBodyFat.contains(v) else { return nil }
        return (v * 10).rounded() / 10
    }

    func hasCheckedIn() -> Bool { daily.contains { $0.date == today() && $0.weight != nil } }

    /// Consecutive days with a check-in or workout. The current day is a grace
    /// period: the streak stays alive all day even before today's check-in, and
    /// only breaks once a full day has passed with nothing logged. So if today is
    /// not logged yet we start counting from yesterday rather than zeroing out.
    /// Consecutive days with something the user did: a weigh-in, logged food, a
    /// typed step count, a session or a marked rest day. A day that only holds
    /// numbers imported from Apple Health does not count — otherwise the streak is
    /// just how many days the phone was carried.
    var streak: Int {
        var dates = prefs.restDaySet
        for e in daily where e.weight != nil || e.hasNutrition || e.stepsManual == true { dates.insert(e.date) }
        sessions.forEach { dates.insert($0.date) }
        let cal = Calendar.current
        var d = cal.startOfDay(for: Date())
        // Today still open: don't penalize until it actually elapses.
        if !dates.contains(isoFormatter.string(from: d)) {
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        var n = 0
        for _ in 0..<400 {
            let s = isoFormatter.string(from: d)
            if dates.contains(s) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
            else { break }
        }
        return n
    }

    // MARK: - Next workout (schedule-aware)
    /// What the user should train next: a strength plan or a cardio activity.
    enum NextItem {
        case plan(WorkoutPlan)
        case cardio(CardioType)
        var name: String { switch self { case .plan(let p): return p.name; case .cardio(let c): return c.name } }
        var color: String { switch self { case .plan(let p): return p.color; case .cardio(let c): return c.color } }
        var sub: String {
            switch self {
            case .plan(let p): return p.sub
            case .cardio(let c): return c.sportType.label
            }
        }
        var icon: String {
            switch self {
            case .plan: return "dumbbell.fill"
            case .cardio(let c): return c.sportType.icon
            }
        }
    }

    /// Resolve a schedule slot id to a concrete item (plan or cardio), if any.
    private func scheduleItem(_ id: String) -> NextItem? {
        if id.isEmpty || id == "rest" { return nil }
        if let p = plans.first(where: { $0.id == id }) { return .plan(p) }
        if let c = cardioTypes.first(where: { $0.id == id }) { return .cardio(c) }
        return nil
    }

    /// The next thing to train. With a weekly schedule, walks forward from today
    /// (Mon..Sun, looping to next week) to the next assigned, non-rest weekday,
    /// skipping today if it's already been trained. Without a schedule, rotates
    /// through the plan list after the most recent session.
    func nextUp() -> NextItem? {
        let cal = Calendar.current
        if prefs.hasSchedule {
            let sched = prefs.weekSchedule
            let todayMon = (cal.component(.weekday, from: Date()) + 5) % 7   // Monday = 0
            let trainedToday = sessions.contains { $0.date == today() }
            for off in 0..<8 {
                if off == 0 && trainedToday { continue }
                if let item = scheduleItem(sched[(todayMon + off) % 7]) { return item }
            }
            // Every scheduled slot points at something that no longer exists: fall
            // through to the rotation rather than showing no workout at all.
        }
        return nextPlanRotation().map { .plan($0) }
    }

    /// Next plan by simple rotation: the one after whatever was trained last.
    func nextPlanRotation() -> WorkoutPlan? {
        guard !plans.isEmpty else { return nil }
        guard let last = sessions.sorted(by: { $0.date > $1.date }).first,
              let idx = plans.firstIndex(where: { $0.id == last.planId }) else { return plans.first }
        return plans[(idx + 1) % plans.count]
    }

    /// Set the assignment for a weekday (Mon=0..Sun=6) in the weekly schedule.
    func setSchedule(weekday: Int, id: String) {
        guard (0..<7).contains(weekday) else { return }
        var s = prefs.weekSchedule
        s[weekday] = id
        // Drop the schedule entirely when nothing meaningful remains.
        prefs.schedule = s.contains { !$0.isEmpty && $0 != "rest" } ? s : nil
    }
    func clearSchedule() { prefs.schedule = nil }

    /// Maximum additional weight ever logged for an exercise. For bodyweight exercises
    /// the PR is the highest added weight (positive = weighted vest/belt, 0 = pure BW).
    /// Returns 0 when no sets have been logged with a positive weight.
    func exercisePR(_ name: String) -> Double {
        var mx = 0.0
        for s in sessions {
            for e in s.exercises where e.name == name {
                mx = max(mx, e.maxWeight)
            }
        }
        return mx
    }

    /// Longest hold ever logged for a timed (isometric) exercise, in seconds — the
    /// timed analogue of `exercisePR`. 0 when never held.
    func exerciseMaxSeconds(_ name: String) -> Double {
        var mx = 0.0
        for s in sessions {
            for e in s.exercises where e.name == name {
                mx = max(mx, e.maxSeconds)
            }
        }
        return mx
    }

    /// True when the exercise is marked as bodyweight in any plan or in the library.
    func isBodyweightExercise(_ name: String) -> Bool {
        if let item = exerciseItems.first(where: { $0.name == name }) { return item.isBodyweight }
        for p in plans { if let ex = p.exercises.first(where: { $0.name == name }) { return ex.bodyweight } }
        return false
    }

    func lastSession(forPlan id: String) -> WorkoutSession? {
        sessions.filter { $0.planId == id && $0.date != today() }
            .sorted { $0.date > $1.date }.first
    }

    /// Suggested next weight: previous session's max + 2.5 kg when ready to progress.
    /// Suppresses the suggestion when readiness or ACWR indicate recovery stress.
    func suggested(planId: String, exercise: String) -> Double? {
        guard let prog = progression(planId: planId, exercise: exercise),
              prog == .addLoad else { return nil }
        guard let last = lastSession(forPlan: planId),
              let ex = last.exercises.first(where: { $0.name == exercise }),
              !ex.sets.isEmpty else { return nil }
        // No recovery check here: progression() already ran it, and only returns
        // .addLoad when readiness and load allow it.
        let allDone = ex.sets.allSatisfy { pf($0.reps) > 0 && pf($0.weight) > 0 }
        guard allDone else { return nil }
        return ex.maxWeight + 2.5
    }

    /// Energy spent in a session, in kcal, as *active* energy (the resting
    /// baseline is removed, so the number is comparable to what a sports watch
    /// reports). Each category has its own formula:
    ///   - manual override always wins;
    ///   - each aerobic sport (cycling / running / walking / swimming) has its
    ///     own speed->MET curve, refined by avg HR when no distance is logged;
    ///   - strength uses avg HR + duration, plus a small bump from volume lifted;
    ///   - an unknown custom activity ("other", e.g. padel) uses a generic
    ///     HR + duration estimate, or a moderate fixed MET if no HR.
    /// A new activity that picks an existing sport category inherits that sport's
    /// formula automatically (it flows through `sportType`).
    func estimateCalories(_ s: WorkoutSession) -> Int {
        if let manual = s.caloriesManual, manual > 0 { return manual }
        let w = lastWeight
        guard let dur = s.durationMinutesD, dur > 0 else {
            // No duration logged: fall back to a strength volume/sets heuristic.
            return Int((s.volume * 0.022 + Double(s.totalSets) * 3 + 60).rounded())
        }
        let hours = dur / 60
        let speed: Double? = s.distanceKm.flatMap { $0 > 0 ? $0 / hours : nil }   // km/h
        let hrr = hrReserve(s.avgHR, session: s)
        let met = sportMET(s.sportType, speedKmh: speed, hrr: hrr)
        // Active energy = (MET - 1 resting) x weight x hours.
        var kcal = max(1.0, met - 1.0) * w * hours
        if s.sportType == .strength { kcal += min(90.0, s.volume * 0.008) }
        return max(1, Int(kcal.rounded()))
    }

    /// Heart-rate reserve fraction (0...1) from profile resting/max HR, or nil
    /// when no avg HR was entered.
    private func hrReserve(_ hr: Int?, session s: WorkoutSession) -> Double? {
        guard let hr, hr > 0 else { return nil }
        let rest = Double(prefs.restHRorDefault)
        let mx = Double(s.maxHRSes ?? prefs.estMaxHR)
        guard mx > rest else { return nil }
        return max(0, min(1, (Double(hr) - rest) / (mx - rest)))
    }

    /// Per-category gross MET. Aerobic sports use a speed->MET curve calibrated so
    /// the resulting active energy stays close to a sports-watch reading (the old
    /// HR-only Keytel equation badly overestimated, e.g. ~1200 kcal for a steady
    /// ride). When no speed is available we fall back to an HR-driven estimate,
    /// then to a moderate fixed MET.
    private func sportMET(_ sport: Sport, speedKmh v: Double?, hrr: Double?) -> Double {
        switch sport {
        case .running:
            if let v, v > 0 { return max(6.0, 0.95 * v + 0.5) }     // ~10 MET at 10 km/h
            if let hrr { return 3.0 + 9.0 * hrr }
            return 9.5
        case .cycling:
            if let v, v > 0 {
                switch v {
                case ..<16:  return 3.8
                case ..<20:  return 5.0      // ~17 km/h leisure -> ~500 kcal active for an 88-min ride
                case ..<24:  return 6.8
                case ..<28:  return 8.5
                case ..<33:  return 10.5
                default:     return 12.5
                }
            }
            if let hrr { return 2.5 + 7.0 * hrr }
            return 6.0
        case .walking:
            if let v, v > 0 {
                switch v {
                case ..<3.2: return 2.5
                case ..<4.8: return 3.3
                case ..<6.4: return 4.5
                case ..<8.0: return 6.0
                default:     return 7.5
                }
            }
            if let hrr { return 2.0 + 4.0 * hrr }
            return 3.5
        case .swimming:
            if let v, v > 0 { return v > 4 ? 10.0 : (v < 2.5 ? 6.0 : 8.3) }
            if let hrr { return 4.0 + 7.0 * hrr }
            return 8.0
        case .strength:
            if let hrr { return 2.8 + 5.5 * hrr }
            return 4.5
        case .other:
            if let hrr { return 2.0 + 7.0 * hrr }
            return 6.0
        }
    }

    // MARK: Daily nutrition & recovery
    /// Write daily extras for `date` (defaults to today, so existing call sites are
    /// unchanged). Routing through `upsertDaily` means any past day can be corrected
    /// by hand — the Body page's day picker relies on this.
    func saveDailyExtras(date: String = today(),
                         kcal: Int? = nil, protein: Double? = nil, carbs: Double? = nil,
                         fat: Double? = nil, salt: Double? = nil, steps: Int? = nil,
                         rmssd: Double? = nil, restHR: Int? = nil, sleepHR: Int? = nil) {
        upsertDaily(date) { e in
            if let kcal { e.kcal = kcal }
            if let protein { e.protein = protein }
            if let carbs { e.carbs = carbs }
            if let fat { e.fat = fat }
            if let salt { e.salt = salt }
            if let steps { e.steps = steps; e.stepsManual = true }
            if let rmssd { e.rmssd = rmssd }
            if let restHR { e.restHR = restHR }
            if let sleepHR { e.sleepHR = sleepHR }
        }
    }

    // MARK: Nutrition (quick total OR per-meal, for any date)
    /// Look up a day's entry (nil if never logged).
    func dailyEntry(_ date: String) -> DailyEntry? { daily.first { $0.date == date } }

    /// Upsert a day's entry by mutation, for an arbitrary (past) date.
    func upsertDaily(_ date: String, _ mutate: (inout DailyEntry) -> Void) {
        var e = daily.first(where: { $0.date == date }) ?? DailyEntry(date: date)
        mutate(&e)
        daily.removeAll { $0.date == date }
        daily.append(e)
    }

    /// Quick one-tap mode: a single daily total (clears any per-meal breakdown so
    /// the total is unambiguous).
    func saveNutritionTotal(date: String, kcal: Int?, protein: Double?, carbs: Double?, fat: Double?) {
        upsertDaily(date) { e in
            e.kcal = kcal; e.protein = protein; e.carbs = carbs; e.fat = fat
            e.meals = nil
        }
    }

    /// Per-meal mode: individual meals that auto-sum to the day total. Empty meals
    /// are dropped; the quick-total fields are cleared so `totalKcal` uses the sum.
    func saveNutritionMeals(date: String, meals: [String: MealEntry]) {
        let clean = meals.filter { !$0.value.isEmpty }
        upsertDaily(date) { e in
            e.meals = clean.isEmpty ? nil : clean
            e.kcal = nil; e.protein = nil; e.carbs = nil; e.fat = nil
        }
        // Float any foods used in a meal to the top of the picker.
        for m in clean.values { for l in (m.foods ?? []) { if let fid = l.foodId { touchFood(fid) } } }
    }

    // MARK: Saved food list (local, per-100 macros)
    /// Saved foods, most-recently-used first (then alphabetical) for the picker.
    func recentFoods() -> [FoodItem] {
        foods.sorted {
            ($0.lastUsed ?? "") != ($1.lastUsed ?? "")
                ? ($0.lastUsed ?? "") > ($1.lastUsed ?? "")
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    func food(barcode: String) -> FoodItem? { foods.first { $0.barcode == barcode } }

    /// Insert or update a saved food (matched by id).
    @discardableResult
    func saveFood(_ f: FoodItem) -> FoodItem {
        if let i = foods.firstIndex(where: { $0.id == f.id }) { foods[i] = f }
        else { foods.append(f) }
        return f
    }
    func deleteFood(_ id: String) { foods.removeAll { $0.id == id } }
    /// Undo of a delete: back at its old position (or the end, if the list shrank).
    func restoreFood(_ food: FoodItem, at index: Int) {
        guard !foods.contains(where: { $0.id == food.id }) else { return }
        foods.insert(food, at: min(max(0, index), foods.count))
    }
    /// Mark a food as used today so it floats to the top of the picker.
    func touchFood(_ id: String) {
        guard let i = foods.firstIndex(where: { $0.id == id }) else { return }
        foods[i].lastUsed = today()
    }

    /// Replace the day-level individual foods for a date (food-by-food logging
    /// without a meal). Empty list clears them.
    func saveDayFoods(date: String, foods logs: [FoodLog]) {
        upsertDaily(date) { e in
            e.foods = logs.isEmpty ? nil : logs
            // Day-level food logging is its own mode: clear the quick total and
            // the per-meal breakdown so the day total is unambiguous.
            if !logs.isEmpty {
                e.kcal = nil; e.protein = nil; e.carbs = nil; e.fat = nil
                e.meals = nil
            }
        }
        for l in logs { if let fid = l.foodId { touchFood(fid) } }
    }

    /// Series of logged-intake days for the nutrition charts (most recent `days`).
    struct NutPoint: Identifiable {
        var date: String; var kcal: Int
        var protein: Double; var carbs: Double; var fat: Double
        var id: String { date }
    }

    /// Weekly-averaged nutrition series for the charts. Mirrors `metricSeries`:
    /// groups logged days into ISO-week buckets and averages each macro, so the
    /// nutrition charts show weekly means — consistent with every other overview
    /// chart (sleep, steps, weight…) instead of noisy day-by-day values.
    func nutritionWeeklySeries(months: Int = ChartGranularity.week.months) -> [NutPoint] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .month, value: -months, to: Date()) else { return [] }
        struct Acc { var kcal = 0.0; var p = 0.0; var c = 0.0; var f = 0.0; var n = 0 }
        var byBucket: [Date: Acc] = [:]
        let comps = ChartGranularity.week.comps
        for e in daily where e.hasNutrition {
            guard let d = isoFormatter.date(from: e.date), d >= cutoff else { continue }
            guard let bucket = cal.date(from: cal.dateComponents(comps, from: d)) else { continue }
            var acc = byBucket[bucket] ?? Acc()
            acc.kcal += Double(e.totalKcal); acc.p += e.totalProtein
            acc.c += e.totalCarbs; acc.f += e.totalFat; acc.n += 1
            byBucket[bucket] = acc
        }
        return byBucket.keys.sorted().map { b in
            let a = byBucket[b]!; let n = Double(max(1, a.n))
            return NutPoint(date: weekBucketLabel(b),
                            kcal: Int((a.kcal / n).rounded()),
                            protein: (a.p / n * 10).rounded() / 10,
                            carbs: (a.c / n * 10).rounded() / 10,
                            fat: (a.f / n * 10).rounded() / 10)
        }
    }

    /// MM-dd label for a week bucket's start date (matches the day/week axis style).
    private func weekBucketLabel(_ d: Date) -> String { cachedFormatter("MM-dd").string(from: d) }

    // MARK: Apple Health import (optional, gap-fill only)
    /// Merge Health samples into daily entries. Imported values only fill missing
    /// fields so a manually typed number is never overwritten.
    /// Map asleep hours to a rough 0-100 sleep score (Apple gives duration, not a
    /// score). Peaks at 8 h, falls off either side; clamped to 0-100.
    static func sleepScore(fromHours h: Double) -> Int {
        let penalty = abs(h - 8.0) * 12.0      // ~12 points lost per hour off 8 h
        return max(0, min(100, Int((100 - penalty).rounded())))
    }

    /// Merge Health day samples into the daily entries.
    ///
    /// `overwrite: false` (the automatic sync) only fills gaps, so a value typed by
    /// hand is never clobbered. `overwrite: true` is the explicit "re-import" the
    /// user triggers from the Health-history screen: there they've asked for Health
    /// to win, so every imported field replaces what's stored. Steps are the one
    /// exception in gap-fill mode — they climb all day, so they refresh unless the
    /// user has manually overridden the count for that day.
    @discardableResult
    func applyHealthSamples(_ samples: [HealthDaySample], overwrite: Bool = false) -> Int {
        // Worked on a copy and published once: a year-long backfill would otherwise
        // fire a change (and a re-render) for every single day.
        var byDate = Dictionary(daily.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        var touched = 0
        for s in samples {
            var e = byDate[s.date] ?? DailyEntry(date: s.date)
            let before = e
            func fill<T>(_ kp: WritableKeyPath<DailyEntry, T?>, _ v: T?, positive: (T) -> Bool) {
                guard let v, positive(v) else { return }
                if overwrite || e[keyPath: kp] == nil { e[keyPath: kp] = v }
            }
            // Day totals that climb until midnight: the first import of the day is a
            // partial figure, so a later one may raise it (never lower it).
            func grow<T: Comparable>(_ kp: WritableKeyPath<DailyEntry, T?>, _ v: T?, positive: (T) -> Bool) {
                guard let v, positive(v) else { return }
                e[keyPath: kp] = overwrite ? v : max(e[keyPath: kp] ?? v, v)
            }
            if (overwrite || e.stepsManual != true), let v = s.steps, v > 0 {
                e.steps = v
                if overwrite { e.stepsManual = nil }   // Health is authoritative again
            }
            fill(\.restHR, s.restHR) { $0 > 0 }
            fill(\.hrvSDNN, s.hrvSDNN) { $0 > 0 }
            fill(\.hrvSleep, s.hrvSleep) { $0 > 0 }
            grow(\.activeKcal, s.activeKcal) { $0 > 0 }
            grow(\.exerciseMin, s.exerciseMin) { $0 > 0 }
            grow(\.sleepHours, s.sleepHours) { $0 > 0 }
            fill(\.sleepHR, s.sleepHR) { $0 > 0 }
            fill(\.vo2max, s.vo2max) { $0 > 0 }
            // Derive a 0-100 sleep score from Health sleep duration when the user
            // hasn't entered one — Apple exposes asleep hours, not a score, so we map
            // hours to a score peaking around 8 h (7.5-8.5 h ≈ 95-100).
            // A score derived earlier from fewer hours follows the hours; a score the
            // user typed (it differs from the derived one) is left alone.
            let wasDerived = before.sleep == before.sleepHours.map { Store.sleepScore(fromHours: $0) }
            if overwrite || e.sleep == nil || wasDerived, let h = e.sleepHours, h > 0 {
                e.sleep = Store.sleepScore(fromHours: h)
            }
            guard e != before else { continue }
            byDate[s.date] = e
            touched += 1
        }
        if touched > 0 { daily = byDate.values.sorted { $0.date < $1.date } }
        return touched
    }

    /// How many days in `[from, to]` already carry a value for each Health category.
    /// Feeds the Health-history screen so a category that never imported is visible
    /// as a plain "0 / N" instead of being silently absent.
    func healthCoverage(from: String, to: String) -> [String: Int] {
        let days = daily.filter { $0.date >= from && $0.date <= to }
        var out: [String: Int] = [:]
        for c in HealthCategory.allCases {
            out[c.rawValue] = days.filter { e in
                switch c {
                case .steps:       return (e.steps ?? 0) > 0
                case .restHR:      return (e.restHR ?? 0) > 0
                case .hrv:         return (e.hrvSleep ?? 0) > 0
                case .sleep:       return (e.sleepHours ?? 0) > 0 || (e.sleep ?? 0) > 0
                case .sleepHR:     return (e.sleepHR ?? 0) > 0
                case .activeKcal:  return (e.activeKcal ?? 0) > 0
                case .exerciseMin: return (e.exerciseMin ?? 0) > 0
                case .vo2max:      return (e.vo2max ?? 0) > 0
                }
            }.count
        }
        return out
    }

    /// Import an explicit window from Apple Health on demand (the history screen).
    /// Reports how many days were written so the user gets a real answer instead of
    /// a silent no-op. `overwrite` makes Health win over stored values.
    func importHealthRange(days: Int, overwrite: Bool,
                           completion: @escaping (_ ok: Bool, _ daysWritten: Int) -> Void) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion(false, 0); return }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else {
            completion(false, 0); return
        }
        hk.requestAuthorization { granted in
            guard granted else { completion(false, 0); return }
            hk.fetch(from: start, to: end, categories: self.prefs.healthCategories) { samples, complete in
                let n = self.applyHealthSamples(samples, overwrite: overwrite)
                // Only a full-year pull that Health answered in full counts as the
                // backfill. A 30-day manual import, or a year cut short by a locked
                // phone, must not cancel the automatic one.
                if complete, days >= Store.healthBackfillDays {
                    self.prefs.healthBackfilled = true
                    self.prefs.sleepHRVBackfilled = true
                }
                completion(complete, n)
            }
        }
    }

    // MARK: Apple Health workout import (any paired watch)
    /// Turn HKWorkout records (Apple Watch, Garmin, Fitbit, Polar, Coros, Huawei, …)
    /// into the app's own cardio/strength sessions. Three dedupe guards keep it from
    /// creating doubles:
    ///   1. a workout already imported (matched by its HKWorkout UUID) is skipped;
    ///   2. a workout recorded by FitTracker's own Apple Watch app is skipped — the
    ///      companion already delivered it over WatchConnectivity;
    ///   3. a workout that overlaps an existing session (same day + same sport +
    ///      duration within 2 min) is skipped, covering manually logged sessions.
    @discardableResult
    func applyHealthWorkouts(_ workouts: [HealthWorkout]) -> (count: Int, sources: [String]) {
        var imported = 0
        var srcs = Set<String>()
        // Includes UUIDs absorbed by a merge — otherwise a workout merged into
        // another session reads as never-imported and comes straight back.
        let known = Set(sessions.flatMap { $0.allHealthUUIDs })
        for w in workouts {
            if w.fromThisApp { continue }
            if known.contains(w.uuid) { continue }
            if hasSession(on: w.date, strength: w.sport == "strength", sport: w.sport,
                          durationSec: w.durationSec) { continue }

            sessions.append(sessionFromHealth(w))
            imported += 1
            if !w.sourceName.isEmpty { srcs.insert(w.sourceName) }
        }
        return (imported, srcs.sorted())
    }

    /// Build a WorkoutSession from a Health workout. Imported sessions get Apple's
    /// workout green and the HK display name ("Weight Training", "Running", …) so
    /// they read as "from Apple Health" on the calendar and carry every metric the
    /// device recorded (duration, kcal, avg/max HR, distance).
    private func sessionFromHealth(_ w: HealthWorkout) -> WorkoutSession {
        let isStrength = w.sport == "strength"
        let sportType = Sport(rawValue: w.sport) ?? .other
        let sessionName = w.displayName.isEmpty ? sportType.label : w.displayName
        var s = WorkoutSession(date: w.date, planId: "health-\(w.sport)",
                               planName: sessionName, planColor: Theme.appleGreen)
        s.sport = isStrength ? nil : w.sport
        s.durationSec = w.durationSec > 0 ? w.durationSec : nil
        s.avgHR = (w.avgHR ?? 0) > 0 ? w.avgHR : nil
        s.maxHRSes = (w.maxHR ?? 0) > 0 ? w.maxHR : nil
        s.distanceKm = (w.distanceKm ?? 0) > 0 ? w.distanceKm : nil
        if let k = w.kcal, k > 0 { s.caloriesManual = k }
        s.healthUUID = w.uuid
        s.source = w.sourceName.isEmpty ? nil : w.sourceName
        return s
    }

    /// Manually import one Health workout (from the calendar's import action),
    /// skipping the auto-match dedupe guards the user has already overridden by
    /// choosing it. Still avoids creating a duplicate of an already-imported UUID.
    /// Returns the created (or existing) session so the caller can open its editor.
    @discardableResult
    func importHealthWorkout(_ w: HealthWorkout) -> WorkoutSession {
        if let existing = sessions.first(where: { $0.allHealthUUIDs.contains(w.uuid) }) { return existing }
        let s = sessionFromHealth(w)
        sessions.append(s)
        save()
        return s
    }

    // MARK: Workout file import (GPX / TCX — any device that can export a file)
    /// Parse a GPX/TCX file the user exported from a watch app that does NOT sync
    /// to Apple Health (e.g. Huawei Health) and turn it into a session. Returns
    /// the created session on success so the caller can confirm / let the user edit.
    enum FileImportOutcome { case imported(WorkoutSession), alreadyLogged, unreadable }

    func importWorkoutFile(_ url: URL) -> FileImportOutcome {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            appLog.error("Workout file unreadable: \(String(describing: error), privacy: .public)")
            return .unreadable
        }
        guard let p = WorkoutFileParser.parse(data: data) else { return .unreadable }

        let sportType = Sport(rawValue: p.sport) ?? .other
        let isStrength = p.sport == "strength"
        // The same file picked twice, or a workout Health already delivered.
        guard !hasSession(on: p.date, strength: isStrength, sport: p.sport, durationSec: p.durationSec)
        else { return .alreadyLogged }
        var s = WorkoutSession(date: p.date, planId: "file-\(p.sport)",
                               planName: sportType.label, planColor: Theme.appleGreen)
        s.sport = isStrength ? nil : p.sport
        s.durationSec = p.durationSec > 0 ? p.durationSec : nil
        s.avgHR = (p.avgHR ?? 0) > 0 ? p.avgHR : nil
        s.maxHRSes = (p.maxHR ?? 0) > 0 ? p.maxHR : nil
        s.distanceKm = (p.distanceKm ?? 0) > 0 ? p.distanceKm : nil
        if let k = p.kcal, k > 0 { s.caloriesManual = k }
        s.source = url.lastPathComponent
        setRestDay(p.date, on: false)
        sessions.append(s)
        return .imported(s)
    }

    /// Whether a session of this sport and about this length already exists that day.
    private func hasSession(on date: String, strength: Bool, sport: String, durationSec: Int) -> Bool {
        sessions.contains { s in
            guard s.date == date, strength ? (s.sport == nil) : (s.sport == sport) else { return false }
            return abs((s.durationSeconds ?? 0) - durationSec) <= Store.sameWorkoutToleranceSec
        }
    }
    private static let sameWorkoutToleranceSec = 120

    /// Fetch Apple Health workouts recorded on a given day that are NOT already in
    /// the app, so the calendar can offer them for manual import when the automatic
    /// match missed them. Requests authorization first if needed.
    func importableHealthWorkouts(onDate date: String, completion: @escaping ([HealthWorkout]) -> Void) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion([]); return }
        hk.requestAuthorization { granted in
            guard granted else { completion([]); return }
            hk.fetchWorkouts(onDate: date) { workouts in
                // Hide ones already saved (by UUID) and ones recorded by this app's
                // own watch companion (those arrive over WatchConnectivity).
                let existing = Set(self.sessions.flatMap { $0.allHealthUUIDs })
                let out = workouts.filter { !$0.fromThisApp && !existing.contains($0.uuid) }
                completion(out)
            }
        }
    }

    /// Request authorization (if needed) and pull the last `days` days from Health.
    /// Sync Apple Health. The completion reports success plus how many workouts
    /// were newly imported and from which source apps, so the UI can confirm to
    /// the user that their watch is feeding the app.
    private static let healthBackfillDays = 365
    private static let healthRoutineDays = 90
    func syncHealth(days: Int? = nil, completion: ((_ ok: Bool, _ imported: Int, _ sources: [String]) -> Void)? = nil) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion?(false, 0, []); return }
        // First sync after connecting Health backfills a full year, so the charts
        // open with real history instead of building up over three months. Later
        // syncs only need the recent window.
        // The launch sync and the first foreground sync would otherwise overlap,
        // each pulling a year of samples.
        guard !isSyncingHealth else { completion?(false, 0, []); return }
        isSyncingHealth = true
        let finish: (Bool, Int, [String]) -> Void = { [weak self] ok, imported, sources in
            self?.isSyncingHealth = false
            completion?(ok, imported, sources)
        }
        // The year is read again once more after the sleep HRV was added, so past
        // nights get it too.
        let backfilled = prefs.healthBackfilled == true && prefs.sleepHRVBackfilled == true
        let window = days ?? (backfilled ? Store.healthRoutineDays : Store.healthBackfillDays)
        hk.requestAuthorization { granted in
            guard granted else { finish(false, 0, []); return }
            hk.fetch(days: window, categories: self.prefs.healthCategories) { samples, complete in
                self.applyHealthSamples(samples)
                // An incomplete answer leaves the backfill to run again next time.
                if complete, window >= Store.healthBackfillDays {
                    self.prefs.healthBackfilled = true
                    self.prefs.sleepHRVBackfilled = true
                }
                // Keep resting HR profile fresh from the most recent reading.
                if let last = samples.compactMap({ $0.restHR }).last, last > 0 { self.prefs.restingHR = last }
                // Importing past workouts from other watches is opt-in (formats
                // don't always translate cleanly), so honor the user's choice.
                guard self.prefs.importWorkoutsEnabled else { finish(true, 0, []); return }
                // Workouts stay on the 90-day window even during the daily-metric
                // backfill: a year of imported sessions from another watch would
                // bury the user's own log, and importing them is a separate opt-in.
                hk.fetchWorkouts(days: min(window, Store.healthRoutineDays)) { workouts in
                    let r = self.applyHealthWorkouts(workouts)
                    finish(true, r.count, r.sources)
                }
            }
        }
    }

    // MARK: Export a session to Apple Health (opt-in)
    /// Write a session into Health so a workout logged by hand still closes the
    /// rings. Deliberately narrow:
    ///   • off unless the user turned it on;
    ///   • never re-exports (`exportedHealthUUID` already set);
    ///   • never exports a session that CAME from Health or a file — writing it back
    ///     would duplicate the original record;
    ///   • needs a duration, since an HKWorkout without one carries no information.
    func exportToHealth(_ session: WorkoutSession, completion: ((Bool) -> Void)? = nil) {
        guard prefs.exportsToHealth,
              session.exportedHealthUUID == nil,
              session.healthUUID == nil, session.source == nil,
              let sec = session.durationSeconds, sec > 0 else { completion?(false); return }
        let kcal = estimateCalories(session)
        HealthKitManager.shared.save(session: session, sport: session.sportType,
                                     durationSec: sec, kcal: kcal > 0 ? kcal : nil,
                                     distanceKm: session.distanceKm) { uuid in
            guard let uuid else { completion?(false); return }
            if let i = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[i].exportedHealthUUID = uuid
            }
            completion?(true)
        }
    }

    // MARK: Session editing
    func deleteSession(_ id: UUID) { sessions.removeAll { $0.id == id } }

    /// Copy a past session to another day (default today), keeping its exercises and
    /// their weights but clearing what belongs to the original performance: the
    /// Health provenance, the exported marker and the measured heart rate.
    @discardableResult
    func duplicateSession(_ id: UUID, to date: String = today()) -> WorkoutSession? {
        guard let src = sessions.first(where: { $0.id == id }) else { return nil }
        var copy = src
        copy.id = UUID()
        copy.date = date
        copy.healthUUID = nil
        copy.mergedHealthUUIDs = nil
        copy.exportedHealthUUID = nil
        copy.source = nil
        copy.avgHR = nil
        copy.maxHRSes = nil
        // Fresh set ids, so editing the copy can never touch the original's rows.
        copy.exercises = src.exercises.map { e in
            var ex = e
            ex.id = UUID()
            ex.sets = e.sets.map { s in
                var set = s
                set.id = UUID()
                return set
            }
            return ex
        }
        setRestDay(date, on: false)
        sessions.append(copy)
        return copy
    }
    func updateSession(_ s: WorkoutSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s }
    }

    /// Fold several sessions from the same day into one — a gym session logged in
    /// two halves, or a manual log plus the watch's own record of the same workout.
    /// `primary` decides the identity kept (name, colour, plan, sport); everything
    /// measurable is combined:
    ///   • exercises concatenate, and an exercise present in both gets its sets appended
    ///   • duration, distance and calories sum
    ///   • average HR is weighted by each session's duration (a 10-minute warm-up
    ///     shouldn't drag down the average of an hour of work); max HR takes the peak
    ///   • absorbed Health UUIDs are recorded so the import dedupe still recognises them
    /// Returns the merged session, or nil if fewer than two ids resolve.
    @discardableResult
    func mergeSessions(_ ids: [UUID], keeping primary: UUID) -> WorkoutSession? {
        let picked = ids.compactMap { id in sessions.first { $0.id == id } }
        guard picked.count >= 2, var merged = picked.first(where: { $0.id == primary }) else { return nil }
        let others = picked.filter { $0.id != primary }

        for o in others {
            for ex in o.exercises {
                if let i = merged.exercises.firstIndex(where: { $0.name == ex.name }) {
                    merged.exercises[i].sets.append(contentsOf: ex.sets)
                    // Rounds are the interval equivalent of sets, so they add up too.
                    if let r = ex.rounds { merged.exercises[i].rounds = (merged.exercises[i].rounds ?? 0) + r }
                    let notes = [merged.exercises[i].notes, ex.notes].filter { !$0.isEmpty }
                    merged.exercises[i].notes = notes.joined(separator: " · ")
                } else {
                    merged.exercises.append(ex)
                }
            }
        }

        let totalSec = picked.compactMap { $0.durationSeconds }.reduce(0, +)
        if totalSec > 0 { merged.durationSec = totalSec; merged.durationMin = nil }

        // Duration-weighted average HR; sessions without a duration fall back to an
        // equal share so their HR still counts for something.
        let hrParts = picked.compactMap { s -> (Double, Double)? in
            guard let hr = s.avgHR, hr > 0 else { return nil }
            return (Double(hr), Double(s.durationSeconds ?? 0))
        }
        if !hrParts.isEmpty {
            let totalW = hrParts.reduce(0) { $0 + $1.1 }
            if totalW > 0 {
                merged.avgHR = Int((hrParts.reduce(0) { $0 + $1.0 * $1.1 } / totalW).rounded())
            } else {
                merged.avgHR = Int((hrParts.reduce(0) { $0 + $1.0 } / Double(hrParts.count)).rounded())
            }
        }
        if let mx = picked.compactMap({ $0.maxHRSes }).max() { merged.maxHRSes = mx }

        let dist = picked.compactMap { $0.distanceKm }.reduce(0, +)
        if dist > 0 { merged.distanceKm = dist }
        if let elev = picked.compactMap({ $0.elevationM }).max() { merged.elevationM = elev }
        // Calories: sum what each session actually accounts for (manual override when
        // present, else its estimate), so the merged total matches the day's real burn.
        let kcal = picked.reduce(0) { $0 + estimateCalories($1) }
        if kcal > 0 { merged.caloriesManual = kcal }
        // A merged pace would be meaningless across different efforts — let it
        // recompute from the summed distance and duration.
        merged.paceManual = nil

        let absorbed = others.flatMap { $0.allHealthUUIDs }
        if !absorbed.isEmpty {
            merged.mergedHealthUUIDs = ((merged.mergedHealthUUIDs ?? []) + absorbed).uniqued()
        }
        if merged.source == nil, let src = others.compactMap({ $0.source }).first { merged.source = src }

        sessions.removeAll { s in others.contains { $0.id == s.id } }
        updateSession(merged)
        return merged
    }

    // MARK: Rest days (markers, not sessions)
    func isRestDay(_ date: String) -> Bool { prefs.restDaySet.contains(date) }
    func setRestDay(_ date: String, on: Bool) {
        var set = prefs.restDaySet
        if on { set.insert(date) } else { set.remove(date) }
        prefs.restDays = set.isEmpty ? nil : Array(set).sorted()
    }
    func toggleRestDay(_ date: String) { setRestDay(date, on: !isRestDay(date)) }

    // MARK: Quick insert (log a workout for a past/other day from Home or Calendar)
    /// Create a strength session for `date`, prefilled from the most recent
    /// session of that plan (its sets, reps, weights, load), or from the plan
    /// template when there's no history. Marking the day clears any rest flag.
    @discardableResult
    func quickInsertSession(plan: WorkoutPlan, date: String) -> WorkoutSession {
        let last = sessions.filter { $0.planId == plan.id }.sorted { $0.date > $1.date }.first
        let exercises: [LoggedExercise]
        if let last {
            exercises = last.exercises.map { e in
                LoggedExercise(name: e.name,
                               sets: e.sets.map { SetEntry(reps: $0.reps, weight: $0.weight) },
                               notes: "", target: e.target,
                               supersetGroup: e.supersetGroup, method: e.method)
            }
        } else {
            exercises = plan.exercises.map { pe in
                LoggedExercise(name: pe.name,
                               sets: (0..<max(1, pe.sets)).map { _ in SetEntry() },
                               target: "\(pe.sets)×\(pe.reps)",
                               supersetGroup: pe.supersetGroup, method: pe.method)
            }
        }
        var s = WorkoutSession(date: date, planId: plan.id, planName: plan.name,
                               planColor: plan.color, exercises: exercises)
        s.durationSec = last?.durationSeconds
        s.avgHR = last?.avgHR
        s.maxHRSes = last?.maxHRSes
        setRestDay(date, on: false)
        sessions.append(s)
        return s
    }

    /// Create a cardio session for `date`, prefilled from the most recent log of
    /// that activity. Returns it so the caller can open the editor to adjust.
    @discardableResult
    func quickInsertCardio(type: CardioType, date: String) -> WorkoutSession {
        let pid = "cardio-\(type.id)"
        let last = sessions.filter { $0.planId == pid }.sorted { $0.date > $1.date }.first
        var s = WorkoutSession(date: date, planId: pid, planName: type.name,
                               planColor: type.color, exercises: [], sport: type.sport)
        s.durationSec = last?.durationSeconds
        s.avgHR = last?.avgHR
        s.distanceKm = last?.distanceKm
        s.paceManual = last?.paceManual
        setRestDay(date, on: false)
        sessions.append(s)
        return s
    }

    struct PRInfo { var weight: Double; var date: String? }
    /// PR per exercise name across all plans + sessions.
    func allPRs() -> [String: PRInfo] {
        var prs: [String: PRInfo] = [:]
        for p in plans { for e in p.exercises { if prs[e.name] == nil { prs[e.name] = PRInfo(weight: 0, date: nil) } } }
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            for e in s.exercises {
                let w = e.maxWeight
                if w >= (prs[e.name]?.weight ?? 0) { prs[e.name] = PRInfo(weight: w, date: s.date) }
            }
        }
        return prs
    }

    /// Distinct exercise names from every plan, in plan order. Also includes
    /// exercises in the library that are no longer in any plan (historical).
    func allExerciseNames() -> [(group: String, name: String)] {
        var seen = Set<String>()
        var out: [(String, String)] = []
        for p in plans {
            for e in p.exercises where !e.name.isEmpty {
                if seen.insert(e.name).inserted { out.append((p.name, e.name)) }
            }
        }
        // Append library exercises that fell out of all plans.
        for item in exerciseItems.sorted(by: { ($0.lastUsed ?? "") > ($1.lastUsed ?? "") }) where !item.name.isEmpty {
            if seen.insert(item.name).inserted { out.append((L.t("ex.library"), item.name)) }
        }
        return out
    }

    // MARK: Exercise library

    /// Auto-save an exercise the first time it is used; update its bodyweight flag.
    /// On first save it also gets a suggested movement family (base) and a guessed
    /// muscle-group category, both of which the user can later override.
    @discardableResult
    func touchExerciseInLibrary(_ name: String, isBodyweight: Bool = false) -> ExerciseItem {
        if let i = exerciseItems.firstIndex(where: { $0.name == name }) {
            exerciseItems[i].lastUsed = today()
            if isBodyweight { exerciseItems[i].isBodyweight = true }
            if exerciseItems[i].base == nil { exerciseItems[i].base = Store.normalizedBase(name) }
            if exerciseItems[i].category == nil { exerciseItems[i].category = Store.guessCategory(name).rawValue }
            return exerciseItems[i]
        }
        let item = ExerciseItem(name: name, isBodyweight: isBodyweight, lastUsed: today(),
                                base: Store.normalizedBase(name), category: Store.guessCategory(name).rawValue)
        exerciseItems.append(item)
        return item
    }

    /// Rebuild a Train-page plan from a past session (used when the original plan
    /// was deleted). Carries over names, set counts, a representative rep target,
    /// method, effort scale, bodyweight flag, and the library muscle group.
    @discardableResult
    func recreatePlan(from session: WorkoutSession) -> WorkoutPlan {
        let exs: [PlanExercise] = session.exercises.map { le in
            // Most common rep value across the logged sets as the new target.
            let reps = le.sets.compactMap { Int(pf($0.reps)) }.filter { $0 > 0 }
            let repTarget = reps.isEmpty ? "10" : "\(mode(reps))"
            return PlanExercise(name: le.name, sets: max(1, le.sets.count), reps: repTarget,
                                supersetGroup: le.supersetGroup, method: le.method,
                                effortMode: le.effortMode, isBodyweight: le.isBodyweight,
                                muscle: exerciseCategory(le.name))
        }
        let plan = WorkoutPlan(name: session.planName, color: session.planColor, exercises: exs)
        plans.append(plan)
        registerPlanExercises(plan)
        return plan
    }

    /// Most frequent value in a list (ties resolved by first seen).
    private func mode(_ xs: [Int]) -> Int {
        var counts: [Int: Int] = [:]
        for x in xs { counts[x, default: 0] += 1 }
        return counts.max { a, b in a.value < b.value }?.key ?? (xs.first ?? 10)
    }

    /// Register every exercise in a plan into the library (creating entries as
    /// needed) and apply the muscle group / bodyweight flag chosen in the editor.
    /// Called on plan save so the library is always populated and recoverable, even
    /// after the plan itself is later deleted.
    func registerPlanExercises(_ plan: WorkoutPlan) {
        for ex in plan.exercises {
            let name = ex.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            touchExerciseInLibrary(name, isBodyweight: ex.bodyweight)
            if let m = ex.muscle, !m.isEmpty,
               let i = exerciseItems.firstIndex(where: { $0.name == name }) {
                exerciseItems[i].category = m
            }
        }
    }

    /// Set the movement family + muscle-group for an exercise (creates the library
    /// entry if needed). Empty base => the exercise is its own family.
    func setExerciseFamily(_ name: String, base: String?, category: String?) {
        let cleanBase = base?.trimmingCharacters(in: .whitespaces)
        if let i = exerciseItems.firstIndex(where: { $0.name == name }) {
            exerciseItems[i].base = (cleanBase?.isEmpty ?? true) ? Store.normalizedBase(name) : cleanBase
            if let category { exerciseItems[i].category = category }
        } else {
            exerciseItems.append(ExerciseItem(name: name, lastUsed: today(),
                                              base: (cleanBase?.isEmpty ?? true) ? Store.normalizedBase(name) : cleanBase,
                                              category: category ?? Store.guessCategory(name).rawValue))
        }
    }

    // MARK: Exercise rename / merge / delete (rewrites historical data)

    /// Rename an exercise everywhere it appears — every logged set in past
    /// sessions, every plan, and the library — so the whole history follows the new
    /// name. When `to` already exists this is a MERGE: the two histories combine
    /// under the destination name, and the source library entry is dropped (the
    /// destination's bodyweight/base/category metadata wins). PRs, progress charts
    /// and "last session" all recompute automatically off the rewritten sessions.
    /// Returns false (no-op) for an empty/identical target.
    @discardableResult
    func renameExercise(from oldName: String, to newRaw: String) -> Bool {
        let newName = newRaw.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != oldName else { return false }
        let isMerge = exerciseItems.contains { $0.name == newName }
            || plans.contains { $0.exercises.contains { $0.name == newName } }
            || sessions.contains { $0.exercises.contains { $0.name == newName } }

        // 1) Rewrite every logged exercise in past sessions.
        for si in sessions.indices {
            for ei in sessions[si].exercises.indices where sessions[si].exercises[ei].name == oldName {
                sessions[si].exercises[ei].name = newName
            }
        }
        // 2) Rewrite plan templates.
        for pi in plans.indices {
            for ei in plans[pi].exercises.indices where plans[pi].exercises[ei].name == oldName {
                plans[pi].exercises[ei].name = newName
            }
        }
        // 3) Library: on merge drop the old entry (keep the destination's metadata);
        //    on a plain rename, carry the old entry's metadata over to the new name.
        if let oi = exerciseItems.firstIndex(where: { $0.name == oldName }) {
            if isMerge {
                // Preserve the freshest lastUsed across the two entries.
                if let di = exerciseItems.firstIndex(where: { $0.name == newName }) {
                    let merged = max(exerciseItems[di].lastUsed ?? "", exerciseItems[oi].lastUsed ?? "")
                    exerciseItems[di].lastUsed = merged.isEmpty ? exerciseItems[di].lastUsed : merged
                }
                exerciseItems.remove(at: oi)
            } else {
                exerciseItems[oi].name = newName
            }
        } else if !isMerge {
            touchExerciseInLibrary(newName)
        }
        return true
    }

    /// Delete an exercise from the whole history: remove its sets from every past
    /// session (dropping a session that becomes empty), from every plan, and from
    /// the library. Irreversible — used by the manage-exercises screen behind a
    /// confirmation.
    func deleteExercise(_ name: String) {
        // Only a session this delete emptied is dropped. Sessions that never had
        // exercises (Health imports, watch sessions, cardio) are not touched.
        sessions = sessions.compactMap { session in
            guard session.exercises.contains(where: { $0.name == name }) else { return session }
            var stripped = session
            stripped.exercises.removeAll { $0.name == name }
            return stripped.exercises.isEmpty ? nil : stripped
        }
        for pi in plans.indices {
            plans[pi].exercises.removeAll { $0.name == name }
        }
        exerciseItems.removeAll { $0.name == name }
    }

    /// Groups of exercise names that look like accidental duplicates (same name up
    /// to case, spacing and accents), surfaced as merge suggestions. Only groups
    /// with more than one real variant are returned, most-recent first.
    func similarExerciseGroups() -> [[String]] {
        func key(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
             .replacingOccurrences(of: "-", with: " ")
             .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let names = Set(allExerciseNames().map { $0.name })
        var byKey: [String: [String]] = [:]
        for n in names { byKey[key(n), default: []].append(n) }
        return byKey.values.filter { $0.count > 1 }
            .map { $0.sorted { recencyOf($0) > recencyOf($1) } }
            .sorted { (recencyOf($0.first ?? "")) > (recencyOf($1.first ?? "")) }
    }

    /// Most recent date this exact exercise name was logged or marked used.
    private func recencyOf(_ name: String) -> String {
        let lib = exerciseItems.first { $0.name == name }?.lastUsed ?? ""
        let logged = sessions.filter { $0.exercises.contains { $0.name == name } }
            .map { $0.date }.max() ?? ""
        return max(lib, logged)
    }

    /// The movement family an exercise rolls up to (its saved base, else a
    /// normalized form of the name).
    func exerciseBase(_ name: String) -> String {
        if let item = exerciseItems.first(where: { $0.name == name }), let b = item.base, !b.isEmpty { return b }
        return Store.normalizedBase(name)
    }

    /// The muscle-group key for an exercise (saved category, else a guess).
    func exerciseCategory(_ name: String) -> String {
        if let item = exerciseItems.first(where: { $0.name == name }), let c = item.category, !c.isEmpty { return c }
        return Store.guessCategory(name).rawValue
    }

    /// Strip common grip / variation qualifiers so variants of one movement share a
    /// family by default (e.g. "Wide-grip lat pulldown" -> "Lat pulldown"). The
    /// result is title-cased; the user can always edit the family afterwards.
    static func normalizedBase(_ name: String) -> String {
        var s = " " + name.lowercased() + " "
        let qualifiers = ["wide-grip", "wide grip", "close-grip", "close grip", "narrow-grip",
                          "narrow grip", "neutral-grip", "neutral grip", "reverse-grip", "reverse grip",
                          "rear-delt", "rear delt", "single-arm", "single arm", "one-arm", "one arm",
                          "wide", "close", "narrow"]
        for q in qualifiers { s = s.replacingOccurrences(of: " \(q) ", with: " ") }
        let cleaned = s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return name }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    /// Best-effort muscle-group from the exercise name's keywords.
    static func guessCategory(_ name: String) -> MuscleGroup {
        let n = name.lowercased()
        func has(_ ks: [String]) -> Bool { ks.contains { n.contains($0) } }
        if has(["squat", "leg press", "leg curl", "leg extension", "lunge", "calf", "hamstring",
                "quad", "glute", "rdl", "romanian", "hip thrust"]) { return .legs }
        if has(["bench", "chest", "fly", "pec", "push-up", "push up", "dip"]) { return .chest }
        if has(["row", "pulldown", "pull-up", "pull up", "chin-up", "lat ", "deadlift", "pull-over", "back extension"]) { return .back }
        if has(["shoulder", "lateral raise", "delt", "overhead press", "ohp", "upright row", "face pull", "shrug"]) { return .shoulders }
        if has(["curl", "triceps", "biceps", "pushdown", "skull", "preacher", "hammer", "forearm"]) { return .arms }
        if has(["plank", "crunch", "ab ", "abs", "core", "sit-up", "sit up", "leg raise", "russian twist"]) { return .core }
        if has(["run", "cycl", "bike", "swim", "walk", "row erg", "rowing", "elliptical", "jump rope"]) { return .cardio }
        return .other
    }

    /// A movement family (base) grouping all of its variant exercise names.
    struct ExFamily: Identifiable {
        var base: String
        var category: String       // MuscleGroup raw value
        var names: [String]
        var id: String { base }
    }

    /// Every known exercise (plans + library) grouped into movement families,
    /// each tagged with a muscle-group, sorted by most-recently-used name.
    func exerciseFamilies() -> [ExFamily] {
        var byBase: [String: (cat: String, names: [String])] = [:]
        for (_, name) in allExerciseNames() where !name.isEmpty {
            let base = exerciseBase(name)
            var entry = byBase[base] ?? (exerciseCategory(name), [])
            if !entry.names.contains(name) { entry.names.append(name) }
            byBase[base] = entry
        }
        return byBase.map { ExFamily(base: $0.key, category: $0.value.cat, names: $0.value.names) }
            .sorted { $0.base.localizedCaseInsensitiveCompare($1.base) == .orderedAscending }
    }

    struct ExPoint { var date: String; var maxW: Double; var vol: Double }
    func exerciseHistory(_ name: String) -> [ExPoint] {
        sessions.filter { s in s.exercises.contains { $0.name == name } }
            .sorted { $0.date < $1.date }
            .map { s in
                let ex = s.exercises.first { $0.name == name }!
                return ExPoint(date: fmtShort(s.date), maxW: ex.maxWeight, vol: ex.volume.rounded())
            }
    }

    /// History aggregated over every variant in a movement family: per session the
    /// max weight across variants and the summed volume.
    func exerciseHistory(family base: String) -> [ExPoint] {
        let names = Set(exerciseItems.filter { exerciseBase($0.name) == base }.map { $0.name })
            .union(plans.flatMap { $0.exercises.map { $0.name } }.filter { exerciseBase($0) == base })
        return sessions.filter { s in s.exercises.contains { names.contains($0.name) } }
            .sorted { $0.date < $1.date }
            .map { s in
                let exs = s.exercises.filter { names.contains($0.name) }
                let maxW = exs.map { $0.maxWeight }.max() ?? 0
                let vol = exs.reduce(0.0) { $0 + $1.volume }
                return ExPoint(date: fmtShort(s.date), maxW: maxW, vol: vol.rounded())
            }
    }

    var bodyLatest: BodyEntry? { body.max { $0.date < $1.date } }
    /// The newest body record on or before `date`: what was true on that day.
    func bodyEntry(onOrBefore date: String) -> BodyEntry? {
        body.filter { $0.date <= date }.max { $0.date < $1.date }
    }
    /// The newest body record strictly before `date`, for "change since last time".
    func bodyEntry(before date: String) -> BodyEntry? {
        body.filter { $0.date < date }.max { $0.date < $1.date }
    }

    /// Effective body-fat %: manual override wins, otherwise Navy estimate.
    var currentBF: Double? {
        guard let bl = bodyLatest else { return nil }
        return bl.bfManual ?? bfNavy(waist: bl.waist, neck: bl.neck, hip: bl.hips)
    }

    // MARK: Mutations
    // Every mutation below takes an explicit `date` defaulting to today, so the Body
    // page can log or correct a past day without a second set of functions.
    func saveCheckIn(weight: Double?, sleep: Int?, restHR: Int? = nil, sleepHR: Int? = nil,
                     date: String = today()) {
        upsertDaily(date) { entry in
            if let weight { entry.weight = weight }
            if let sleep { entry.sleep = sleep }
            if let restHR { entry.restHR = restHR }
            if let sleepHR { entry.sleepHR = sleepHR }
        }
    }

    /// Upsert a body-measurement record for `date` by mutation (mirrors `upsertDaily`).
    private func upsertBody(_ date: String, _ mutate: (inout BodyEntry) -> Void) {
        var rec = body.first(where: { $0.date == date }) ?? BodyEntry(date: date)
        mutate(&rec)
        body.removeAll { $0.date == date }
        body.append(rec)
    }

    func saveBodyFat(_ v: Double, date: String = today()) {
        upsertBody(date) { $0.bfManual = v }
    }

    func saveMeasurements(_ values: [String: Double], date: String = today()) {
        upsertBody(date) { rec in
            for (k, v) in values where v > 0 { rec.set(k, v) }
        }
    }

    // MARK: Manual sleep entry (when Health has no data for the day)
    /// Save sleep data manually (all fields optional; only provided ones are written).
    func saveManualSleep(hours: Double?, score: Int?, hrv: Double?, sleepHR: Int?,
                         date: String = today()) {
        upsertDaily(date) { e in
            if let hours, hours > 0 { e.sleepHours = hours }
            if let score { e.sleep = min(100, max(0, score)) }
            // Typed with the night's sleep, so it is a sleep HRV.
            if let hrv, hrv > 0 { e.hrvSleep = hrv }
            if let sleepHR, sleepHR > 0 { e.sleepHR = sleepHR }
        }
    }

    // MARK: Saved recipes
    /// All recipes sorted most-recently-used first, then alphabetically.
    func recentRecipes() -> [Recipe] {
        recipes.sorted {
            ($0.lastUsed ?? "") != ($1.lastUsed ?? "")
                ? ($0.lastUsed ?? "") > ($1.lastUsed ?? "")
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    @discardableResult
    func saveRecipe(_ r: Recipe) -> Recipe {
        if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r }
        else { recipes.append(r) }
        return r
    }

    func deleteRecipe(_ id: String) { recipes.removeAll { $0.id == id } }
    func restoreRecipe(_ recipe: Recipe, at index: Int) {
        guard !recipes.contains(where: { $0.id == recipe.id }) else { return }
        recipes.insert(recipe, at: min(max(0, index), recipes.count))
    }

}
