import Combine
import CoreLocation
import SwiftUI
import WidgetKit

@Observable
final class Store {
    var daily: [DailyEntry] = [] { didSet { dataChanged() } }
    var sessions: [WorkoutSession] = [] { didSet { dataChanged() } }
    var body: [BodyEntry] = [] { didSet { dataChanged() } }
    var plans: [WorkoutPlan] = [] { didSet { dataChanged() } }
    var cardioTypes: [CardioType] = [] { didSet { dataChanged() } }
    var foods: [FoodItem] = [] { didSet { dataChanged() } }
    var exerciseItems: [ExerciseItem] = [] { didSet { dataChanged() } }
    var recipes: [Recipe] = [] { didSet { dataChanged() } }
    var prefs: Prefs = Prefs() { didSet { dataChanged() } }

    /// Values derived from the data (readiness, load, form, streak, targets, PRs,
    /// progressions…), each computed once per change: a single render of the
    /// dashboard or of the live workout asks for the same numbers many times.
    @ObservationIgnored private var derived: [String: Any] = [:]
    /// Something to save that is not on disk yet.
    @ObservationIgnored private var unsaved = false

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
    private(set) var storageProblem: StorageProblem?
    /// Numbers a save found not finite and wrote as 0, counted for the UI to say so.
    private(set) var repairedNumbers = 0
    /// A plan id or cardio-activity id the Home "Start" button asked for; the Train
    /// tab starts it and clears this. Not saved.
    var startRequest: String?
    /// The Stats section a Home card asked for ("load"); Stats opens it and clears this.
    var statsRequest: String?
    /// The calendar day the app is showing. It moves at midnight and when the app
    /// comes back on a new day, so nothing stays on yesterday.
    private(set) var currentDay = today()
    /// Every change empties the derived values and marks the data to save.
    /// Bumped on every change. The cache is not observed (memo writes it while a
    /// view draws), so every memo read touches this instead: a view that only reads
    /// cached values still redraws when the data behind them changes.
    private var revision = 0

    private func dataChanged() {
        derived.removeAll(keepingCapacity: true)
        revision &+= 1
        guard loaded else { return }
        unsaved = true
        scheduleSave()
        NotificationCenter.default.post(name: Store.dataDidChange, object: self)
    }
    /// Posted after any change to the saved data (the watch catalog follows it).
    static let dataDidChange = Notification.Name("fittracker.store.changed")

    /// Autosave: a change persists after a short pause, so a burst of edits is one write.
    @ObservationIgnored private var pendingSave: DispatchWorkItem?
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Store.autosaveDebounceSeconds, execute: work)
    }

    /// The value for `key`, computed by `compute` once per data change.
    func memo<T>(_ key: String, _ compute: () -> T) -> T {
        _ = revision
        // The key is tested first: for an Optional T, casting an absent entry (nil)
        // succeeds with nil, and a miss would be mistaken for a cached nil.
        if let boxed = derived[key], let hit = boxed as? T { return hit }
        let value = compute()
        derived[key] = value
        return value
    }

    enum ImportOutcome: Equatable { case imported, invalidFile, snapshotFailed }

    private static let dataFileName = "fittracker.json"
    private static let backupPrefix = "backup-"
    private static let corruptPrefix = "fittracker.corrupt-"
    private static let preImportPrefix = "pre-import-"
    private static let backupsKept = 30
    private static let preImportSnapshotsKept = 3
    private static let autosaveDebounceSeconds = 0.5

    @ObservationIgnored private var loaded = false
    /// A Health read (sync or history import) is running; others wait for it.
    @ObservationIgnored private var healthBusy = false
    /// The running read is a sync, whose answer a second sync request can share.
    @ObservationIgnored private var syncInProgress = false { didSet { if syncInProgress != oldValue { healthSyncing = syncInProgress } } }
    /// What the Health link is doing, for the status line in Settings and Body.
    private(set) var healthSyncing = false
    /// The last sync could not read Health (permission refused or Health unavailable).
    private(set) var healthFailed = false
    /// Band data that landed in Health while a sync was running: read it once that
    /// sync ends instead of dropping the request.
    @ObservationIgnored private var healthResyncRequested = false
    /// Callers that asked for a sync while one was running get its answer.
    @ObservationIgnored private var waitingForSync: [(Bool, Int, [String]) -> Void] = []
    /// Work queued behind the running Health read.
    @ObservationIgnored private var afterHealthRead: [() -> Void] = []
    /// When the last automatic sync started: the app coming back to the
    /// foreground every few minutes does not read Health every time.
    @ObservationIgnored private var lastAutomaticSync: Date?
    /// Workout heart rate is being read; a second read waits for the next sync.
    @ObservationIgnored var readingWorkoutHeartRate = false
    /// False only when an unreadable file could not be moved out of the way: saving
    /// would then overwrite the one copy of the user's history.
    @ObservationIgnored private var canSave = true
    @ObservationIgnored private var bag = Set<AnyCancellable>()
    private let directory: URL
    /// Serial, so writes land in the order the changes happened.
    private let writeQueue = DispatchQueue(label: "fittracker.store.write", qos: .utility)
    /// The daily copy into the person's folder, apart from the saves.
    private static let copyQueue = DispatchQueue(label: "fittracker.store.copy", qos: .utility)

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var dataURL: URL { directory.appendingPathComponent(Store.dataFileName) }

    init(directory: URL = Store.documentsDirectory) {
        self.directory = directory
        load()
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshDay() }
            .store(in: &bag)
    }

    /// Move to the new day if the date changed: the screens, the recovery gate and
    /// the widget all follow it.
    func refreshDay() {
        let day = today()
        guard day != currentDay else { return }
        currentDay = day
        derived.removeAll()
        revision &+= 1
        let widget = widgetSnapshot
        writeQueue.async { [weak self] in self?.publish(widget) }
    }

    // MARK: Persistence
    func load() {
        // The templates are a first launch's starting point only: plans the user
        // deleted, down to the last one, stay deleted.
        if let document = readDocument() { apply(document) } else {
            plans = Store.defaultPlans()
            cardioTypes = Store.defaultCardioTypes()
        }
        // Register the plans' exercises so the library is never missing one, then
        // layer the curated catalog on top (once, never overwriting).
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
            reloadWhenUnlocked()
            return nil
        }
    }

    /// A Bluetooth event can relaunch the app before the phone is first unlocked:
    /// read the file again as soon as it can be opened, instead of staying empty
    /// and read-only until the next launch.
    private func reloadWhenUnlocked() {
        NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.canSave = true
                self.storageProblem = nil
                self.load()
            }
            .store(in: &bag)
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
        if version < 2 {
            // v1 kept no record of typed values. A sleep score that is not what the
            // old hours formula gives was typed by the user: mark it, so the new
            // score derived from the night never replaces it.
            a.daily = a.daily.map { e in
                guard let score = e.sleep else { return e }
                if let h = e.sleepHours, h > 0, score == Store.v1SleepScore(hours: h) { return e }
                var typed = e
                typed.markSleepScoreManual()
                return typed
            }
        }
        if version < 3 {
            // Every launch used to mark the plans' exercises as used that day, so
            // "recent" meant nothing: the sessions say when each was really logged.
            var lastLogged: [String: String] = [:]
            for s in a.sessions {
                for e in s.exercises where s.date > (lastLogged[e.name] ?? "") { lastLogged[e.name] = s.date }
            }
            a.exerciseItems = a.exerciseItems?.map { item in
                var fixed = item
                fixed.lastUsed = lastLogged[item.name]
                return fixed
            }
            // The weekly rate was typed with its own sign and could contradict the
            // goal (a cut with +0.5 ate a surplus): the goal decides the sign now.
            a.prefs.setWeeklyRate(a.prefs.weeklyRate)
        }
        a.schemaVersion = AppData.currentSchemaVersion
        return a
    }

    private func apply(_ a: AppData) {
        daily = a.daily; sessions = a.sessions; body = a.body; prefs = a.prefs
        plans = a.plans
        // nil only in a file older than cardio activities.
        cardioTypes = a.cardioTypes ?? Store.defaultCardioTypes()
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
        unsaved = false
        let document = currentDocument
        let widget = widgetSnapshot
        writeQueue.async { [weak self] in
            self?.write(document)
            self?.publish(widget)
        }
    }

    /// Write what is not on disk yet before returning. Called when the app goes
    /// to the background, so an edit made inside the autosave debounce is not lost
    /// if the system then suspends or kills the app; with nothing pending it costs
    /// nothing (encoding the whole file on the main thread is not free).
    func flushNow() {
        guard loaded, canSave, unsaved else { return }
        unsaved = false
        let document = currentDocument
        writeQueue.sync { write(document) }
    }

    /// Returns once every write already queued has finished (a test removes its
    /// folder only after this).
    func waitForWrites() { writeQueue.sync {} }

    private func write(_ document: AppData) {
        do {
            let encoded = try Store.encode(document)
            if encoded.repaired > 0 { reportRepaired(encoded.repaired) }
            // A new day's backup is the only time the folder needs trimming.
            let newBackup = try keepDatedBackup()
            try encoded.data.write(to: dataURL, options: .atomic)
            if newBackup { prune(prefix: Store.backupPrefix, keep: Store.backupsKept) }
            // A slow or offline cloud provider must not hold up a save (flushNow
            // waits on this queue from the main thread).
            let file = dataURL, day = today()
            Store.copyQueue.async { ExternalBackup.copyIfDue(file, day: day) }
            reportSave(failure: nil)
        } catch {
            appLog.error("Save failed: \(String(describing: error), privacy: .public)")
            reportSave(failure: error.localizedDescription)
        }
    }

    private static let nonFiniteMarker = "fittracker.nonfinite"

    /// The document as JSON. A number that is not finite (a bad value from a food
    /// database, a bug) makes the plain encoder fail, and with it every save from
    /// then on: it is written as 0 instead, and counted.
    static func encode(_ document: AppData, pretty: Bool = false) throws -> (data: Data, repaired: Int) {
        let encoder = pretty ? JSONEncoder.pretty : JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: nonFiniteMarker, negativeInfinity: nonFiniteMarker, nan: nonFiniteMarker)
        let data = try encoder.encode(document)
        let quoted = "\"\(nonFiniteMarker)\""
        guard data.range(of: Data(quoted.utf8)) != nil else { return (data, 0) }
        let text = String(decoding: data, as: UTF8.self)
        let repaired = text.components(separatedBy: quoted).count - 1
        return (Data(text.replacingOccurrences(of: quoted, with: "0").utf8), repaired)
    }

    private func reportRepaired(_ count: Int) {
        appLog.error("Save wrote \(count, privacy: .public) non-finite numbers as 0")
        DispatchQueue.main.async { [weak self] in self?.repairedNumbers += count }
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
                              kcalTarget: Int(energyTargets().target), date: today(), lang: prefs.langCode)
    }
    @ObservationIgnored private var publishedWidget: WidgetSnapshot?

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
    /// Returns true when it made today's backup.
    private func keepDatedBackup() throws -> Bool {
        let fm = FileManager.default
        let backup = directory.appendingPathComponent("\(Store.backupPrefix)\(today()).json")
        guard fm.fileExists(atPath: dataURL.path), !fm.fileExists(atPath: backup.path) else { return false }
        try fm.copyItem(at: dataURL, to: backup)
        return true
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
            try Store.encode(currentDocument, pretty: true).data.write(to: url, options: .atomic)
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
            try Store.encode(currentDocument).data.write(to: snapshot, options: .atomic)
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
    /// What a deletion took away, so Undo can put it back where it was.
    struct Removed<Item> {
        let item: Item
        let index: Int
        let schedule: [String]?
    }

    @discardableResult
    func deleteCardioType(_ id: String) -> Removed<CardioType>? {
        guard let i = cardioTypes.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = Removed(item: cardioTypes[i], index: i, schedule: prefs.schedule)
        cardioTypes.remove(at: i)
        unschedule(id)
        return removed
    }
    func restoreCardioType(_ r: Removed<CardioType>) {
        guard !cardioTypes.contains(where: { $0.id == r.item.id }) else { return }
        cardioTypes.insert(r.item, at: min(r.index, cardioTypes.count))
        if let schedule = r.schedule { prefs.schedule = schedule }
    }
    @discardableResult
    func deletePlan(_ id: String) -> Removed<WorkoutPlan>? {
        guard let i = plans.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = Removed(item: plans[i], index: i, schedule: prefs.schedule)
        plans.remove(at: i)
        unschedule(id)
        return removed
    }
    func restorePlan(_ r: Removed<WorkoutPlan>) {
        guard !plans.contains(where: { $0.id == r.item.id }) else { return }
        plans.insert(r.item, at: min(r.index, plans.count))
        if let schedule = r.schedule { prefs.schedule = schedule }
    }
    /// A deleted plan or activity leaves the weekly schedule too.
    private func unschedule(_ id: String) {
        guard let schedule = prefs.schedule, schedule.contains(id) else { return }
        prefs.schedule = schedule.map { $0 == id ? "" : $0 }
    }
}

// MARK: - Derived data / domain logic (ports of the web app helpers)
extension Store {
    var sortedDaily: [DailyEntry] { memo("sortedDaily") { daily.sorted { $0.date < $1.date } } }

    /// One time-bucketed average point (day/week/month/year) for an overview chart;
    /// `day` is the start of its bucket.
    struct WeekPoint: Identifiable { var day: Date; var value: Double; var id: Date { day } }

    /// Bucket granularity for the overview charts. The overview shows `.week` over
    /// the last 2 months (a readable trend); the expanded view lets the user switch.
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
        /// Start of the bucket holding `d`. Weeks run Monday to Sunday, whatever
        /// the device's first weekday.
        func bucket(of d: Date, calendar cal: Calendar = .current) -> Date {
            switch self {
            case .day:   return cal.startOfDay(for: d)
            case .week:  return weekStart(now: d, calendar: cal)
            case .month: return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
            case .year:  return cal.date(from: cal.dateComponents([.year], from: d)) ?? d
            }
        }
        /// The bucket width on a Date axis (bar width, tap targets).
        var unit: Calendar.Component {
            switch self {
            case .day:   return .day
            case .week:  return .weekOfYear
            case .month: return .month
            case .year:  return .year
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
            let bucket = granularity.bucket(of: d, calendar: cal)
            var acc = byBucket[bucket] ?? (0, 0)
            acc.sum += v; acc.n += 1
            byBucket[bucket] = acc
        }
        return byBucket.keys.sorted().map { b in
            let acc = byBucket[b]!
            return WeekPoint(day: b, value: ((acc.sum / Double(acc.n)) * 10).rounded() / 10)
        }
    }

    /// Most recent lastUsed date across a family's variants (for "recent" sorting).
    func familyLastUsed(_ f: ExFamily) -> String {
        f.names.compactMap { libraryItem($0)?.lastUsed }.max() ?? ""
    }

    /// The library entry of an exercise, from a lookup table built once per change.
    func libraryItem(_ name: String) -> ExerciseItem? {
        memo("library") { Dictionary(exerciseItems.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first }) }[name]
    }

    /// Number of logged sessions that include any variant of a family.
    func familySessionCount(_ f: ExFamily) -> Int {
        memo("familySessions|\(f.base)") {
            let names = Set(f.names)
            return sessions.filter { s in s.exercises.contains { names.contains($0.name) } }.count
        }
    }

    /// Number of past sessions that logged this exact exercise name.
    func sessionCount(forExercise name: String) -> Int { exerciseRecords[name]?.sessions ?? 0 }

    /// Latest known VO2 max (carried forward — Apple records it sparsely).
    var latestVO2: Double? { sortedDaily.last(where: { ($0.vo2max ?? 0) > 0 })?.vo2max }

    var lastWeight: Double {
        memo("lastWeight") { sortedDaily.last(where: { $0.weight != nil })?.weight ?? prefs.startWeight }
    }

    func plan(_ id: String) -> WorkoutPlan? { plans.first { $0.id == id } }
    func cardioType(_ id: String) -> CardioType? { cardioTypes.first { $0.id == id } }

    func bmi(_ w: Double) -> Double { ((w / (prefs.height * prefs.height)) * 10).rounded() / 10 }

    // BMI, body fat and FFMI are labelled from the reference scales of their "i"
    // sheets (`scaleBand`): one set of bands for the card and the sheet. BMI cannot
    // tell muscle from fat, so with a body-fat % known the comment goes by body fat:
    // a man under 18 % or a woman under 25 % is not overweight, only muscular.

    /// Threshold below which a high BMI is muscle, not fat: men <18%, women <25%.
    private func notOverweightByFat(_ bf: Double) -> Bool {
        prefs.sex_ == "f" ? bf < 25 : bf < 18
    }

    /// The comment shown under the weight/kg box. When body fat is known it
    /// classifies by body fat (more accurate than BMI for muscular builds); the
    /// key rule prevents a lean, muscular person reading as "overweight".
    func bmiComment(weight: Double) -> (text: String, color: Color) {
        let b = bmi(weight)
        if let bf = currentBF, let fat = scaleBand(.bodyfat, bf) {
            // High BMI but low fat → surface that it's muscle, not excess fat.
            if b >= 25 && notOverweightByFat(bf) {
                return ("BMI \(trimNum(b)) · \(L.t("bf.muscular"))", Theme.good)
            }
            return ("BMI \(trimNum(b)) · \(L.t(fat.key))", fat.color)
        }
        let std = scaleBand(.bmi, b)
        return ("BMI \(trimNum(b)) · \(std.map { L.t($0.key) } ?? "")", std?.color ?? Theme.sub)
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

    func hasCheckedIn() -> Bool { dailyEntry(currentDay)?.weight != nil }

    /// Consecutive days with a check-in or workout. The current day is a grace
    /// period: the streak stays alive all day even before today's check-in, and
    /// only breaks once a full day has passed with nothing logged. So if today is
    /// not logged yet we start counting from yesterday rather than zeroing out.
    /// Consecutive days with something the user did: a weigh-in, logged food, a
    /// typed step count, a session or a marked rest day. A day that only holds
    /// numbers imported from Apple Health does not count — otherwise the streak is
    /// just how many days the phone was carried.
    var streak: Int { memo("streak") { computeStreak() } }

    private func computeStreak() -> Int {
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
        var id: String { switch self { case .plan(let p): return p.id; case .cardio(let c): return c.id } }
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
    func scheduleItem(_ id: String) -> NextItem? {
        if id.isEmpty || id == "rest" { return nil }
        if let p = plans.first(where: { $0.id == id }) { return .plan(p) }
        if let c = cardioTypes.first(where: { $0.id == id }) { return .cardio(c) }
        return nil
    }

    /// The next thing to train. With a weekly schedule, walks forward from today
    /// (Mon..Sun, looping to next week) to the next assigned, non-rest weekday,
    /// skipping today if it's already been trained. Without a schedule, rotates
    /// through the plan list after the most recent session.
    func nextUp() -> NextItem? { memo("nextUp") { computeNextUp() } }

    private func computeNextUp() -> NextItem? {
        let cal = Calendar.current
        if prefs.hasSchedule {
            let sched = prefs.weekSchedule
            let todayMon = mondayIndex(calendar: cal)
            let day = today()
            let trainedToday = sessions.contains { $0.date == day }
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
    func exercisePR(_ name: String) -> Double { exerciseRecords[name]?.weight ?? 0 }

    /// Longest hold ever logged for a timed (isometric) exercise, in seconds — the
    /// timed analogue of `exercisePR`. 0 when never held.
    func exerciseMaxSeconds(_ name: String) -> Double { exerciseRecords[name]?.seconds ?? 0 }

    /// Every exercise's top weight, longest hold and number of sessions, in one
    /// pass over the history per change.
    struct ExerciseRecord { var weight = 0.0; var seconds = 0.0; var sessions = 0 }
    var exerciseRecords: [String: ExerciseRecord] {
        memo("exerciseRecords") {
            var out: [String: ExerciseRecord] = [:]
            for s in sessions {
                for name in Set(s.exercises.map(\.name)) { out[name, default: ExerciseRecord()].sessions += 1 }
                for e in s.exercises {
                    out[e.name, default: ExerciseRecord()].weight = max(out[e.name]?.weight ?? 0, e.maxWeight)
                    out[e.name, default: ExerciseRecord()].seconds = max(out[e.name]?.seconds ?? 0, e.maxSeconds)
                }
            }
            return out
        }
    }

    /// True when the exercise is marked as bodyweight in any plan or in the library.
    func isBodyweightExercise(_ name: String) -> Bool {
        if let item = libraryItem(name) { return item.isBodyweight }
        for p in plans { if let ex = p.exercises.first(where: { $0.name == name }) { return ex.bodyweight } }
        return false
    }

    func lastSession(forPlan id: String) -> WorkoutSession? {
        memo("lastSession|\(id)") {
            let day = today()
            return sessions.filter { $0.planId == id && $0.date != day }.max { $0.date < $1.date }
        }
    }

    /// Suggested next weight: previous session's max + 2.5 kg when ready to progress.
    /// Suppresses the suggestion when readiness or ACWR indicate recovery stress.
    func suggested(planId: String, exercise: String) -> Double? {
        memo("suggested|\(planId)|\(exercise)") { computeSuggested(planId: planId, exercise: exercise) }
    }

    private func computeSuggested(planId: String, exercise: String) -> Double? {
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

    /// Heart-rate reserve fraction (0...1) from the resting HR of the session's day
    /// and the profile max, or nil when no avg HR was entered. Zones use the same
    /// max, so a workout lands in the same place in both.
    func hrReserve(_ hr: Int?, session s: WorkoutSession) -> Double? {
        guard let hr, hr > 0 else { return nil }
        let rest = restingHR(on: s.date)
        let mx = Double(prefs.estMaxHR)
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

    // MARK: Steps
    /// A step count typed by hand for `date`: Health stops overwriting it for that day.
    func saveSteps(_ steps: Int, date: String = today()) {
        upsertDaily(date) { e in e.steps = steps; e.stepsManual = true }
    }

    // MARK: Apple Health import
    /// The v1 sleep score (hours only, peak at 8 h): only used to recognise, in old
    /// data, a score the user typed.
    static func v1SleepScore(hours h: Double) -> Int {
        max(0, min(100, Int((100 - abs(h - 8.0) * 12.0).rounded())))
    }

    /// What a complete Health read covered: these days, these categories. A value
    /// it did not return there was deleted or corrected in Health.
    typealias HealthCoverage = (days: Set<String>, categories: Set<String>)

    /// Merge Health samples into the daily entries.
    ///
    /// Health is the reference for every value the user did not type: a later sync
    /// replaces what an earlier one wrote (a night the band delivered late, a day
    /// total that kept climbing, a value Health corrected) and, after a complete
    /// read (`clearing`), empties what Health no longer has. A typed value
    /// (`DailyEntry.isManual`) is never touched, except by the explicit re-import
    /// (`overwrite: true`) on the Health-history screen, where the user asked for
    /// Health to win.
    @discardableResult
    func applyHealthSamples(_ samples: [HealthDaySample], overwrite: Bool = false,
                            clearing: HealthCoverage? = nil) -> Int {
        // Worked on a copy and published once: a year-long backfill would otherwise
        // fire a change (and a re-render) for every single day.
        var byDate = Dictionary(daily.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        var touched = Set<String>()
        if let clearing {
            let reported = Dictionary(samples.map { ($0.date, $0.values) }, uniquingKeysWith: { first, _ in first })
            let fields = HealthCategory.allCases.filter { clearing.categories.contains($0.rawValue) }.flatMap(\.fields)
            for date in clearing.days {
                guard let entry = byDate[date] else { continue }
                let cleared = Store.clearingStaleHealth(entry, fields: fields, reported: reported[date] ?? [:])
                guard cleared != entry else { continue }
                byDate[date] = cleared
                touched.insert(date)
            }
        }
        for s in samples {
            var e = byDate[s.date] ?? DailyEntry(date: s.date)
            let before = e
            for (field, value) in s.values {
                if e.isManual(field) {
                    guard overwrite else { continue }
                    e.clearManual(field)
                }
                e[field] = value
                if field == .weight { e.weightFromHealth = true }
            }
            if overwrite, s.values[.sleepHours] != nil { e.clearSleepScoreManual() }
            if let timeline = s.sleepTimeline, overwrite || !e.isManual(.sleepHours) { e.sleepTimeline = timeline }
            guard e != before else { continue }
            byDate[s.date] = e
            touched.insert(s.date)
        }
        // Scores last: regularity compares each night with the ones before it.
        // Every day read is rescored, so a change to the formula reaches the
        // nights already stored on the next sync.
        for date in Set(samples.map(\.date)) {
            guard var e = byDate[date], !e.sleepScoreManual,
                  let score = sleepScore(of: e, regularity: sleepRegularity(endingOn: date, in: byDate)),
                  score != e.sleep else { continue }
            e.sleep = score
            byDate[date] = e
            touched.insert(date)
        }
        if !touched.isEmpty { daily = byDate.values.sorted { $0.date < $1.date } }
        return touched.count
    }

    /// The entry without the Health values that Health stopped reporting. Typed
    /// values stay; a night that is gone takes its derived score and stages along.
    private static func clearingStaleHealth(_ entry: DailyEntry, fields: [HealthField],
                                            reported: [HealthField: Double]) -> DailyEntry {
        var e = entry
        for f in fields where e[f] != nil && reported[f] == nil && !e.isManual(f) {
            e[f] = nil
            if f == .weight { e.weightFromHealth = nil }
            if f == .sleepHours {
                e.sleepTimeline = nil
                if !e.sleepScoreManual { e.sleep = nil }
            }
        }
        return e
    }

    /// Every yyyy-MM-dd from `start` to `end`, both day starts, both included.
    static func dayKeys(from start: Date, to end: Date) -> Set<String> {
        var days = Set<String>()
        var d = start
        while d <= end {
            days.insert(isoFormatter.string(from: d))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return days
    }

    /// How many days in `[from, to]` already carry a value for each Health category.
    /// Feeds the Health-history screen so a category that never imported is visible
    /// as a plain "0 / N" instead of being silently absent.
    func healthCoverage(from: String, to: String) -> [String: Int] {
        let days = daily.filter { $0.date >= from && $0.date <= to }
        var out: [String: Int] = [:]
        for c in HealthCategory.allCases {
            guard let field = c.fields.first else { continue }
            out[c.rawValue] = days.filter { ($0[field] ?? 0) > 0 }.count
        }
        return out
    }

    /// Import an explicit window from Apple Health on demand (the history screen).
    /// Reports how many days were written so the user gets a real answer instead of
    /// a silent no-op. `overwrite` makes Health win over stored values.
    /// `complete` is false when Health answered only in part (a locked phone, a
    /// permission off): the days written are then real but not the whole window.
    func importHealthRange(days: Int, overwrite: Bool,
                           completion: @escaping (_ granted: Bool, _ complete: Bool, _ daysWritten: Int) -> Void) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion(false, false, 0); return }
        // A sync reading the same days at the same time would race this one.
        guard !healthBusy else {
            afterHealthRead.append { [weak self] in self?.importHealthRange(days: days, overwrite: overwrite, completion: completion) }
            return
        }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else {
            completion(false, false, 0); return
        }
        healthBusy = true
        hk.requestAuthorization { granted in
            guard granted else { self.healthReadEnded(); completion(false, false, 0); return }
            let categories = self.prefs.healthCategories
            hk.fetch(from: start, to: end, categories: categories) { samples, complete in
                let n = self.applyHealthSamples(samples, overwrite: overwrite,
                                                clearing: complete ? (Store.dayKeys(from: start, to: end), categories) : nil)
                // Only a full-year pull that Health answered in full counts as the
                // backfill. A 30-day manual import, or a year cut short by a locked
                // phone, must not cancel the automatic one.
                if complete, days >= Store.healthBackfillDays { self.markHealthBackfilled() }
                self.healthReadEnded()
                completion(true, complete, n)
            }
        }
    }

    /// The running Health read is over: what queued up behind it runs now.
    private func healthReadEnded() {
        healthBusy = false
        let queued = afterHealthRead
        afterHealthRead = []
        queued.forEach { $0() }
    }

    // MARK: Health sync
    private static let healthBackfillDays = 365
    private static let healthRoutineDays = 90
    /// What the band's "data written" signal re-reads: the last nights and today.
    static let healthResyncDays = 3
    /// An automatic sync reads this week; the 90 days are re-read once a day.
    private static let healthForegroundDays = 7
    private static let automaticSyncIntervalSec: TimeInterval = 15 * 60

    private var isHealthBackfilled: Bool {
        prefs.healthBackfilled == true && prefs.sleepHRVBackfilled == true && prefs.healthV12Backfilled == true
    }
    private func markHealthBackfilled() {
        prefs.healthBackfilled = true
        prefs.sleepHRVBackfilled = true
        prefs.healthV12Backfilled = true
    }
    /// Request authorization (if needed) and pull the last `days` days from Health.
    /// `automatic` is the app coming to the foreground: at most every 15 minutes,
    /// and only this week unless today's full read has not happened yet. The Sync
    /// button and the band's signal always run. The completion reports success
    /// plus how many workouts were newly imported and from which source apps, so
    /// the UI can confirm to the user that their watch is feeding the app.
    func syncHealth(days: Int? = nil, automatic: Bool = false,
                    completion: ((_ ok: Bool, _ imported: Int, _ sources: [String]) -> Void)? = nil) {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { completion?(false, 0, []); return }
        if automatic {
            if let last = lastAutomaticSync, Date().timeIntervalSince(last) < Store.automaticSyncIntervalSec { return }
            lastAutomaticSync = Date()
        }
        // First sync after connecting Health backfills a full year, so the charts
        // open with real history instead of building up over three months. Later
        // syncs only need the recent window.
        // The launch sync and the first foreground sync would otherwise overlap,
        // each pulling a year of samples. A caller arriving meanwhile (the
        // Sync button) gets the running sync's answer; a request for fresh band
        // data runs once this sync ends, so its data is not left for the next launch.
        guard !healthBusy else {
            if syncInProgress {
                if let completion { waitingForSync.append(completion) }
                if days != nil { healthResyncRequested = true }
            } else {
                // A history import is reading: this sync runs right after it.
                afterHealthRead.append { [weak self] in self?.syncHealth(days: days, automatic: automatic, completion: completion) }
            }
            return
        }
        healthBusy = true
        syncInProgress = true
        let finish: (Bool, Int, [String]) -> Void = { [weak self] ok, imported, sources in
            guard let self else { return }
            let waiting = self.waitingForSync
            self.waitingForSync = []
            self.syncInProgress = false
            self.healthFailed = !ok
            if ok { self.prefs.lastHealthSync = Date().timeIntervalSince1970 }
            if self.healthResyncRequested {
                self.healthResyncRequested = false
                self.afterHealthRead.append { [weak self] in self?.syncHealth(days: Store.healthResyncDays) }
            }
            self.healthReadEnded()
            completion?(ok, imported, sources)
            waiting.forEach { $0(ok, imported, sources) }
        }
        // The year is read again whenever the reader learns something new about
        // past days: sleep HRV, then (v12) nights on the right day, stages and the
        // new metrics.
        let full = isHealthBackfilled ? Store.healthRoutineDays : Store.healthBackfillDays
        let fullReadDone = prefs.healthFullReadDay == today()
        let window = days ?? (automatic && fullReadDone ? Store.healthForegroundDays : full)
        hk.requestAuthorization { granted in
            guard granted else { finish(false, 0, []); return }
            let categories = self.prefs.healthCategories
            hk.fetch(days: window, categories: categories) { samples, complete in
                // Only a complete answer says what Health no longer has.
                let end = Calendar.current.startOfDay(for: Date())
                let covered = Calendar.current.date(byAdding: .day, value: -(window - 1), to: end)
                    .map { Store.dayKeys(from: $0, to: end) }
                self.applyHealthSamples(samples, clearing: complete ? covered.map { ($0, categories) } : nil)
                // An incomplete answer leaves the backfill to run again next time.
                if complete, window >= Store.healthBackfillDays { self.markHealthBackfilled() }
                if complete, window >= Store.healthRoutineDays { self.prefs.healthFullReadDay = today() }
                // Workouts stay on the 90-day window even during the daily-metric
                // backfill: a year of imported sessions from another watch would
                // bury the user's own log. Sessions already linked to Health are
                // refreshed whatever the import choice; only new sessions from
                // other devices wait for it.
                hk.fetchWorkouts(days: min(window, Store.healthRoutineDays)) { workouts in
                    let r = self.applyHealthWorkouts(workouts, importNew: self.prefs.importWorkoutsEnabled)
                    finish(true, r.count, r.sources)
                    self.readWorkoutHeartRate()
                    self.readWorkoutEffort()
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
    /// `route` is the GPS track of a live cardio session, written with the workout.
    func exportToHealth(_ session: WorkoutSession, route: [CLLocation] = [], completion: ((Bool) -> Void)? = nil) {
        guard prefs.exportsToHealth,
              session.exportedHealthUUID == nil,
              session.healthUUID == nil, session.source == nil,
              let sec = session.durationSeconds, sec > 0 else { completion?(false); return }
        let kcal = estimateCalories(session)
        // A live session knows when it ran; one logged afterwards ends now.
        let end = session.endTime ?? Date()
        let start = session.startTime ?? end.addingTimeInterval(-Double(sec))
        HealthKitManager.shared.save(sport: session.sportType, start: start, end: end,
                                     kcal: kcal > 0 ? kcal : nil, distanceKm: session.distanceKm,
                                     route: route) { uuid in
            guard let uuid else { completion?(false); return }
            if let i = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[i].exportedHealthUUID = uuid
                if self.sessions[i].startTime == nil { self.sessions[i].startTime = start; self.sessions[i].endTime = end }
            }
            completion?(true)
        }
    }

    // MARK: Session editing
    /// Delete a session. Its Health workouts are remembered so the next sync does
    /// not bring it back. Returns it with its position, for Undo.
    @discardableResult
    func deleteSession(_ id: UUID) -> (session: WorkoutSession, index: Int)? {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = sessions[i]
        sessions = sessions.filter { $0.id != id }
        dismissHealthWorkouts(removed.allHealthUUIDs)
        return (removed, i)
    }

    /// Undo of a delete: back where it was, and its Health workouts are its own again.
    func restoreSession(_ session: WorkoutSession, at index: Int) {
        guard !sessions.contains(where: { $0.id == session.id }) else { return }
        var list = sessions
        list.insert(session, at: min(max(0, index), list.count))
        sessions = list
        undismissHealthWorkouts(session.allHealthUUIDs)
    }

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
        copy.metrics = nil
        copy.metricOverrides = nil
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
    /// Save an edited session, or add a new one (from the day picker). A day with
    /// a workout is no longer a rest day.
    func saveSession(_ s: WorkoutSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[i] = s
        } else {
            setRestDay(s.date, on: false)
            sessions.append(s)
        }
    }

    /// Fold several sessions from the same day into one — a gym session logged in
    /// two halves, or a manual log plus the watch's own record of the same workout.
    /// `primary` decides the identity kept (name, colour, plan, sport); everything
    /// measurable is combined:
    ///   • exercises concatenate, and an exercise present in both gets its sets appended
    ///   • duration, distance and calories sum for two halves of a workout; when one
    ///     of them came from Health it is the same workout recorded twice, so the
    ///     larger value wins instead of doubling
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

        let sameWorkout = picked.contains { !$0.allHealthUUIDs.isEmpty }
        func combine(_ values: [Double]) -> Double {
            sameWorkout ? (values.max() ?? 0) : values.reduce(0, +)
        }
        let totalSec = Int(combine(picked.compactMap { $0.durationSeconds }.map(Double.init)))
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

        let dist = combine(picked.compactMap { $0.distanceKm })
        if dist > 0 { merged.distanceKm = dist }
        if let elev = picked.compactMap({ $0.elevationM }).max() { merged.elevationM = elev }
        // Calories: what each session accounts for (manual override when present,
        // else its estimate), combined the same way as duration.
        let kcal = Int(combine(picked.map { Double(estimateCalories($0)) }))
        if kcal > 0 { merged.caloriesManual = kcal }
        // A merged pace would be meaningless across different efforts — let it
        // recompute from the summed distance and duration.
        merged.paceManual = nil

        let absorbed = others.flatMap { $0.allHealthUUIDs }
        if !absorbed.isEmpty {
            merged.mergedHealthUUIDs = ((merged.mergedHealthUUIDs ?? []) + absorbed).uniqued()
        }
        if merged.source == nil, let src = others.compactMap({ $0.source }).first { merged.source = src }
        // Extra metrics: the primary's win, the others fill what it lacks.
        for o in others {
            if let m = o.metrics { merged.metrics = (merged.metrics ?? [:]).merging(m) { mine, _ in mine } }
            if let m = o.metricOverrides { merged.metricOverrides = (merged.metricOverrides ?? [:]).merging(m) { mine, _ in mine } }
        }

        sessions.removeAll { s in others.contains { $0.id == s.id } }
        saveSession(merged)
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

    // MARK: New session for a past/other day (from Home or Calendar)
    /// A strength session for `date`, prefilled from the most recent session of
    /// that plan (its sets, reps, weights, load), or from the plan template when
    /// there's no history. Not saved: the editor's Save adds it, Cancel leaves
    /// nothing behind.
    func newSession(plan: WorkoutPlan, date: String) -> WorkoutSession {
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
        // Heart rate is a measurement of that day, not a template: copying it would
        // invent TRIMP load for a day nobody recorded.
        s.durationSec = last?.durationSeconds
        return s
    }

    /// A cardio session for `date`, prefilled from the most recent log of that
    /// activity. Not saved until the editor's Save, like `newSession(plan:date:)`.
    func newSession(cardio type: CardioType, date: String) -> WorkoutSession {
        let pid = "cardio-\(type.id)"
        let last = sessions.filter { $0.planId == pid }.sorted { $0.date > $1.date }.first
        var s = WorkoutSession(date: date, planId: pid, planName: type.name,
                               planColor: type.color, exercises: [], sport: type.sport)
        s.durationSec = last?.durationSeconds
        s.distanceKm = last?.distanceKm
        s.paceManual = last?.paceManual
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

    // MARK: Mutations
    // Every mutation below takes an explicit `date` defaulting to today, so the Body
    // page can log or correct a past day without a second set of functions.
    func saveCheckIn(weight: Double?, sleep: Int?, restHR: Int? = nil, sleepHR: Int? = nil,
                     date: String = today()) {
        upsertDaily(date) { entry in
            if let weight { entry.weight = weight; entry.markManual(.weight) }
            if let sleep { entry.sleep = sleep; entry.markSleepScoreManual() }
            if let restHR { entry.restHR = restHR; entry.markManual(.restHR) }
            if let sleepHR { entry.sleepHR = sleepHR; entry.markManual(.sleepHR) }
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
            if let hours, hours > 0 { e.sleepHours = hours; e.markManual(.sleepHours) }
            if let score { e.sleep = min(100, max(0, score)); e.markSleepScoreManual() }
            // Typed with the night's sleep, so it is a sleep HRV.
            if let hrv, hrv > 0 { e.hrvSleep = hrv; e.markManual(.hrvSleep) }
            if let sleepHR, sleepHR > 0 { e.sleepHR = sleepHR; e.markManual(.sleepHR) }
        }
    }

}
