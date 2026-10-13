import SwiftUI
import Combine
import UserNotifications

// MARK: - Rest timer
final class RestTimer: ObservableObject {
    @Published private(set) var remaining = 0
    @Published private(set) var total = 60
    @Published private(set) var active = false
    @Published private(set) var done = false
    /// When the current rest ends. The countdown is derived from this, never from
    /// counting ticks, so time spent with the phone locked or the app closed is
    /// still time rested.
    @Published private(set) var endsAt: Date?
    private var cancellable: AnyCancellable?

    /// A rest found already over on returning to the app ended while it was away;
    /// the notification covered that, so no late haptic.
    private static let lateHapticToleranceSec = 2.0

    func start(_ seconds: Int, now: Date = Date()) {
        resume(endsAt: now.addingTimeInterval(Double(seconds)), total: seconds, now: now)
    }

    /// Pick up a rest that is already under way (restored after a relaunch).
    func resume(endsAt: Date, total: Int, now: Date = Date()) {
        guard endsAt > now else { return }
        self.total = total
        self.endsAt = endsAt
        active = true
        done = false
        refresh(now: now)
        cancellable = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] in self?.refresh(now: $0) }
    }

    /// Recompute the countdown from the clock.
    func refresh(now: Date = Date()) {
        guard active, !done, let endsAt else { return }
        remaining = max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
        guard remaining == 0 else { return }
        done = true
        cancellable?.cancel()
        if now.timeIntervalSince(endsAt) < Self.lateHapticToleranceSec { restDoneHaptic() }
    }

    func reset() { start(total) }
    func stop() {
        cancellable?.cancel(); active = false; done = false; endsAt = nil
        RestNotifier.cancel()   // no alert for a rest that was cut short
    }

    /// True only while the countdown is actually running. `active` stays true after
    /// it reaches zero so the strip can keep showing "GO" until dismissed, so it is
    /// NOT the right test for "is a rest in progress".
    var running: Bool { active && !done }

    var label: String { fmtClock(remaining) }
    var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }

    var draft: WorkoutDraft.Rest? {
        guard running, let endsAt else { return nil }
        return WorkoutDraft.Rest(endsAt: endsAt, total: total)
    }
}

// MARK: - Rest-timer notification
// The in-app countdown and its haptic only reach you with the phone in hand. A
// local notification covers the rest: pocketed phone, locked screen, another app.
// Local notifications need no capability beyond the user's permission, which we
// ask for the first time a rest actually starts rather than at launch.
enum RestNotifier {
    private static let id = "fittracker.rest"

    static func schedule(after seconds: Int) {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { post(after: seconds) }
                }
            case .authorized, .provisional, .ephemeral:
                post(after: seconds)
            default:
                break   // denied: the in-app timer and haptic still work
            }
        }
    }

    /// Cancel a pending alert — the rest was stopped or the workout ended, and a
    /// notification firing after that would be noise.
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func post(after seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = L.t("wk.rest_over")
        content.body = L.t("wk.rest_over_body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        // Only one rest is ever pending: a new set replaces the old alert.
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(req)
    }
}

// MARK: - Active workout session
// Holds the running strength workout: the log, the session fields typed in the
// live view and the plan it started from. Nothing about a workout in progress
// lives in a view's @State, so minimising, switching tab, or the system closing
// the app does not lose it — `SessionKeeper` writes `draft` to disk and brings it
// back at the next launch.
final class ActiveWorkout: ObservableObject {
    enum Restored: Equatable {
        case resumed
        /// Brought back after sitting untouched for hours: the user is asked what to do.
        case stale
    }

    /// The plan being trained, as it was when the workout started. A snapshot, so
    /// the session can still be shown and saved if the plan is deleted meanwhile.
    @Published private(set) var plan: WorkoutPlan?
    @Published var log: [LoggedExercise] = [] { didSet { touch() } }
    @Published private(set) var startDate: Date?
    /// True when the user backed out of the live view but the workout is still
    /// running in the background (the floating strip un-minimizes it).
    @Published var minimized = false
    @Published var durationSec: Int? { didSet { touch() } }
    @Published var avgHR = "" { didSet { touch() } }
    @Published var caloriesManual = "" { didSet { touch() } }
    /// Exercises whose note field is open.
    @Published var openNotes: Set<UUID> = []
    /// Set at launch when a workout was brought back from disk; cleared once shown.
    @Published var restored: Restored?
    /// Id of the watch workout folded into this session. The saved session takes
    /// it, so the same result arriving again over the second transport dedupes.
    private(set) var watchResultId: String?
    /// Last time the log or a session field changed.
    private(set) var lastEditAt: Date?

    /// With no edit for this long, the workout is taken to have ended at the last
    /// edit: a session left open overnight must not record 14 hours.
    static let idleCutoffSec: TimeInterval = 45 * 60
    /// A restored workout untouched for this long is not silently resumed.
    static let staleAfterSec: TimeInterval = 6 * 3600

    private let clock: () -> Date

    init(clock: @escaping () -> Date = Date.init) { self.clock = clock }

    var planId: String? { plan?.id }
    var isActive: Bool { plan != nil }

    private func touch() { if isActive { lastEditAt = clock() } }

    func start(plan: WorkoutPlan) {
        clear()
        self.plan = plan
        startDate = clock()
        log = plan.exercises.map { ex in
            // Timed sets start EMPTY: the hold timer writes the seconds actually held,
            // and the plan's target drives that timer. Pre-filling the target used to
            // make an untouched set look already logged. Interval carries its HIIT
            // prescription (work/rest/rounds) forward unchanged.
            let sets = (0..<max(1, ex.sets)).map { _ in SetEntry() }
            let target: String
            switch ex.exKind {
            case .interval: target = "\(ex.rounds ?? 0)×\(ex.workSec ?? 0)s"
            case .timed:    target = "\(ex.sets)×\(ex.effectiveTargetSec)s"
            case .reps:     target = "\(ex.sets)×\(ex.reps)"
            }
            return LoggedExercise(name: ex.name,
                           sets: ex.exKind == .interval ? [] : sets,
                           notes: "",
                           target: target,
                           supersetGroup: ex.supersetGroup,
                           method: ex.method,
                           effortMode: ex.effortMode,
                           isBodyweight: ex.isBodyweight,
                           kind: ex.kind,
                           workSec: ex.workSec,
                           restSec: ex.restSec,
                           rounds: ex.rounds)
        }
        lastEditAt = startDate
    }

    func end() { clear() }

    private func clear() {
        plan = nil
        log = []
        startDate = nil
        minimized = false
        durationSec = nil
        avgHR = ""
        caloriesManual = ""
        openNotes = []
        restored = nil
        watchResultId = nil
        lastEditAt = nil
    }

    // MARK: Draft
    var draft: WorkoutDraft.Strength? {
        guard let plan, let startDate else { return nil }
        return WorkoutDraft.Strength(plan: plan, log: log, startDate: startDate,
                                     lastEditAt: lastEditAt ?? startDate,
                                     durationSec: durationSec, avgHR: avgHR,
                                     caloriesManual: caloriesManual, watchResultId: watchResultId)
    }

    func restore(_ draft: WorkoutDraft.Strength) {
        clear()
        plan = draft.plan
        startDate = draft.startDate
        log = draft.log
        durationSec = draft.durationSec
        avgHR = draft.avgHR
        caloriesManual = draft.caloriesManual
        watchResultId = draft.watchResultId
        lastEditAt = draft.lastEditAt      // after the assignments above, which count as edits
        let idle = clock().timeIntervalSince(draft.lastEditAt)
        restored = idle > Self.staleAfterSec ? .stale : .resumed
    }

    // MARK: Watch mirroring
    /// Mirror live telemetry into the session fields — only filling values the user
    /// hasn't typed, so manual edits always win.
    func absorb(live s: WatchLiveSample) {
        guard s.activityId == planId else { return }
        if avgHR.isEmpty, s.avgHR > 0 { avgHR = "\(s.avgHR)" }
        if (durationSec ?? 0) == 0, s.elapsedSec > 0 { durationSec = s.elapsedSec }
        if let exs = s.exercises { mergeWatchExercises(exs) }
    }

    /// Fold a finished watch workout into this session, so there is one session and
    /// nothing the wrist already tracked has to be typed again.
    func absorb(result r: WatchResult) {
        guard r.activityId == planId else { return }
        if avgHR.isEmpty, let hr = r.avgHR, hr > 0 { avgHR = "\(hr)" }
        if (durationSec ?? 0) == 0, r.durationSec > 0 { durationSec = r.durationSec }
        if caloriesManual.isEmpty, let k = r.activeKcal, k > 0 { caloriesManual = "\(k)" }
        if let exs = r.exercises { mergeWatchExercises(exs) }
        objectWillChange.send()     // watchResultId is part of the draft
        watchResultId = r.id
    }

    /// Fill empty set fields from the wrist's per-set values (never overwrites).
    /// Timed (isometric) exercises carry per-set hold seconds instead of reps.
    private func mergeWatchExercises(_ exs: [WatchResultExercise]) {
        var merged = log
        for we in exs {
            guard let li = merged.firstIndex(where: { $0.name == we.name }) else { continue }
            let secs = we.seconds ?? []
            let n = max(max(we.reps.count, we.weight.count), secs.count)
            while merged[li].sets.count < n { merged[li].sets.append(SetEntry()) }
            for j in 0..<n {
                if merged[li].sets[j].reps.isEmpty, j < we.reps.count, pf(we.reps[j]) > 0 { merged[li].sets[j].reps = we.reps[j] }
                if merged[li].sets[j].weight.isEmpty, j < we.weight.count, pf(we.weight[j]) > 0 { merged[li].sets[j].weight = we.weight[j] }
                if (merged[li].sets[j].seconds ?? 0) == 0, j < secs.count, pf(secs[j]) > 0 { merged[li].sets[j].seconds = pf(secs[j]) }
            }
        }
        if merged != log { log = merged }
    }

    // MARK: Finishing
    func elapsedSec(at now: Date? = nil) -> Int {
        guard let startDate else { return 0 }
        return max(0, Int((now ?? clock()).timeIntervalSince(startDate)))
    }

    /// Duration to record when none was typed or streamed: start to now, unless the
    /// workout sat untouched past `idleCutoffSec`, in which case start to last edit.
    private func fallbackDurationSec(now: Date) -> Int? {
        guard let startDate else { return nil }
        let lastEdit = lastEditAt ?? startDate
        let end = now.timeIntervalSince(lastEdit) > Self.idleCutoffSec ? lastEdit : now
        let seconds = Int(end.timeIntervalSince(startDate))
        return seconds > 0 ? seconds : nil
    }

    /// The session to save, or nil when nothing was logged.
    func finishedSession() -> WorkoutSession? {
        guard let plan, let startDate else { return nil }
        let exercises = log.map { e -> LoggedExercise in
            var copy = e
            copy.sets = e.sets.filter { $0.filled }
            return copy
        }.filter {
            // Interval exercises carry their data in rounds (no sets); keep them when
            // any round was completed. Everything else needs at least one filled set.
            $0.exKind == .interval ? (($0.rounds ?? 0) > 0) : !$0.sets.isEmpty
        }
        guard !exercises.isEmpty else { return nil }
        var session = WorkoutSession(date: isoFormatter.string(from: startDate), planId: plan.id,
                                     planName: plan.name, planColor: plan.color, exercises: exercises)
        if let id = watchResultId.flatMap(UUID.init(uuidString:)) { session.id = id }
        // Duration source of truth: the value the user typed, else whatever the
        // paired watch streamed in (both land in durationSec), else the clock.
        session.durationSec = durationSec ?? fallbackDurationSec(now: clock())
        session.avgHR = Int(avgHR)
        session.caloriesManual = Int(caloriesManual).flatMap { $0 > 0 ? $0 : nil }
        return session
    }
}

// MARK: - Workout in progress, on disk
/// Everything needed to bring a running workout back after the app was closed.
struct WorkoutDraft: Codable, Equatable {
    struct Strength: Codable, Equatable {
        var plan: WorkoutPlan
        var log: [LoggedExercise]
        var startDate: Date
        var lastEditAt: Date
        var durationSec: Int?
        var avgHR: String
        var caloriesManual: String
        var watchResultId: String?
    }
    struct Cardio: Codable, Equatable {
        var type: CardioType
        var startDate: Date
        /// Seconds from the running stretches already closed by a pause.
        var accumulatedSec: TimeInterval
        /// Start of the stretch still running when this was saved; nil if paused.
        var runningSince: Date?
        var distanceKm: Double?
    }
    struct Rest: Codable, Equatable {
        var endsAt: Date
        var total: Int
    }

    var savedAt: Date
    var strength: Strength?
    var cardio: Cardio?
    var rest: Rest?

    /// A rest countdown alone is not worth keeping.
    var isEmpty: Bool { strength == nil && cardio == nil }
}

struct WorkoutDraftStore {
    let url: URL

    static var standard: WorkoutDraftStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return WorkoutDraftStore(url: support.appendingPathComponent("active-workout.json"))
    }

    /// The saved draft, or nil when no workout was in progress.
    func load() throws -> WorkoutDraft? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(WorkoutDraft.self, from: Data(contentsOf: url))
    }

    /// Write the draft; an empty one removes the file.
    func save(_ draft: WorkoutDraft) throws {
        let fm = FileManager.default
        guard !draft.isEmpty else {
            if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
            return
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: url, options: .atomic)
    }
}

// MARK: - Session keeper
// The one place that looks after a session in progress, whichever screen is
// showing: it writes the draft, restores it at launch, keeps the screen awake,
// runs the Lock Screen activity, claims incoming watch data for the session and
// folds it in. Views only start, edit and end sessions.
final class SessionKeeper {
    private let drafts: WorkoutDraftStore
    private let store: Store
    private let workout: ActiveWorkout
    private let cardio: ActiveCardio
    private let timer: RestTimer
    private let toast: ToastCenter
    private let watch = WatchSync.shared
    private var bag = Set<AnyCancellable>()
    private var saveFailureShown = false

    /// Edits are written at most this often; starting, ending and leaving the
    /// foreground write at once.
    private static let saveIntervalSeconds = 1.0

    init(store: Store, workout: ActiveWorkout, cardio: ActiveCardio, timer: RestTimer,
         toast: ToastCenter, drafts: WorkoutDraftStore = .standard) {
        self.store = store; self.workout = workout; self.cardio = cardio
        self.timer = timer; self.toast = toast; self.drafts = drafts
        restore()
        observe()
    }

    private func restore() {
        let draft: WorkoutDraft?
        do {
            draft = try drafts.load()
        } catch {
            appLog.error("Workout draft unreadable: \(String(describing: error), privacy: .public)")
            toast.show(t("wk.draft_unreadable"), duration: ToastCenter.longDuration)
            return
        }
        guard let draft else { return }
        if let strength = draft.strength { workout.restore(strength) }
        if let saved = draft.cardio { cardio.restore(saved, savedAt: draft.savedAt) }
        if let rest = draft.rest, workout.isActive { timer.resume(endsAt: rest.endsAt, total: rest.total) }
    }

    private func observe() {
        // objectWillChange fires before the value lands; hopping to the main queue
        // means the handlers below always read the new state.
        let main = DispatchQueue.main

        Publishers.Merge3(workout.objectWillChange, cardio.objectWillChange,
                          timer.$endsAt.map { _ in () })
            .throttle(for: .seconds(Self.saveIntervalSeconds), scheduler: main, latest: true)
            .sink { [weak self] in self?.saveNow() }
            .store(in: &bag)

        workout.$plan.map { $0?.id }.removeDuplicates().receive(on: main)
            .sink { [weak self] _ in self?.strengthSessionChanged() }
            .store(in: &bag)
        cardio.$type.map { $0?.id }.removeDuplicates().receive(on: main)
            .sink { [weak self] _ in self?.sessionChanged() }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &bag)

        watch.$live.compactMap { $0 }.receive(on: main)
            .sink { [weak self] sample in
                self?.workout.absorb(live: sample)
                self?.cardio.absorb(live: sample)
            }
            .store(in: &bag)
        watch.$pendingResult.compactMap { $0 }.receive(on: main)
            .sink { [weak self] result in self?.take(result) }
            .store(in: &bag)
    }

    /// A strength workout started, was restored or ended: the Lock Screen activity
    /// follows it.
    private func strengthSessionChanged() {
        if let plan = workout.plan, let start = workout.startDate {
            LiveActivityController.resume(planName: plan.name, planColor: plan.color, startDate: start,
                                          enabled: store.prefs.liveActivityEnabled)
        } else {
            // Also clears an activity stranded by a session that could not be restored.
            LiveActivityController.end()
        }
        sessionChanged()
    }

    private func sessionChanged() {
        let running = workout.isActive || cardio.isActive
        UIApplication.shared.isIdleTimerDisabled = running
        watch.claimedActivityId = workout.planId ?? cardio.activityId
        saveNow()
    }

    /// A finished watch workout claimed for the running session.
    private func take(_ result: WatchResult) {
        watch.pendingResult = nil
        if workout.planId == result.activityId {
            workout.absorb(result: result)
            toast.show(t("wk.watch_synced"))
        } else if cardio.activityId == result.activityId {
            cardio.absorb(result: result)
            toast.show(t("wk.watch_synced"))
        } else {
            // The session ended between the claim and now: keep it as its own session.
            store.ingestWatchResult(result)
        }
    }

    func saveNow() {
        let draft = WorkoutDraft(savedAt: Date(), strength: workout.draft, cardio: cardio.draft, rest: timer.draft)
        do {
            try drafts.save(draft)
            saveFailureShown = false
        } catch {
            appLog.error("Workout draft not saved: \(String(describing: error), privacy: .public)")
            // Said once per failure streak: this runs every second while training.
            if !saveFailureShown { toast.show(t("wk.draft_save_failed"), duration: ToastCenter.longDuration) }
            saveFailureShown = true
        }
    }
}

// MARK: - Toast
final class ToastCenter: ObservableObject {
    struct Action {
        let title: String
        let run: () -> Void
    }

    @Published var message: String?
    @Published private(set) var action: Action?
    private var work: DispatchWorkItem?

    static let defaultDuration = 1.8
    /// For messages the user needs time to read or act on (errors, Undo).
    static let longDuration = 4.0

    func show(_ msg: String, duration: Double = ToastCenter.defaultDuration, action: Action? = nil) {
        message = msg
        self.action = action
        work?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.hide() }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: w)
    }

    /// A deletion that can still be taken back for a few seconds.
    func showUndo(_ msg: String, undo: @escaping () -> Void) {
        show(msg, duration: ToastCenter.longDuration, action: Action(title: t("undo"), run: undo))
    }

    func runAction() {
        action?.run()
        work?.cancel()
        hide()
    }

    private func hide() {
        withAnimation { message = nil }
        action = nil
    }
}

struct ToastView: View {
    let text: String
    var action: ToastCenter.Action? = nil
    var onAction: () -> Void = {}
    var body: some View {
        HStack(spacing: 14) {
            Text(text.uppercased())
                .font(.head(12, .semibold)).tracking(1)
                .foregroundColor(Theme.acc2)
            if let action {
                Button(action: onAction) {
                    Text(action.title.uppercased()).font(.head(12, .bold)).tracking(1).foregroundColor(Theme.txt)
                        .underline()
                }
                .buttonStyle(PressableStyle())
                .hitArea()
            }
        }
            .padding(.vertical, 11).padding(.horizontal, 18)
            .chrome(14, stroke: Theme.brd2)
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }
}
