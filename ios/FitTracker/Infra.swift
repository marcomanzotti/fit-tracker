import Foundation
import ActivityKit
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
        // Written here, on the main thread: the settings callback below runs on
        // another queue, where the app's language must not be read.
        let content = UNMutableNotificationContent()
        content.title = L.t("wk.rest_over")
        content.body = L.t("wk.rest_over_body")
        content.sound = .default
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { post(content, after: seconds) }
                }
            case .authorized, .provisional, .ephemeral:
                post(content, after: seconds)
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

    private static func post(_ content: UNNotificationContent, after seconds: Int) {
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
    /// The Finish button of the bottom bar was tapped; the live view opens its finish sheet.
    @Published var finishRequest = false
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
    /// The HKWorkout the watch saved for this session. In the draft too: a session
    /// restored without it was exported to Health a second time.
    private var watchHealthUUID: String?
    /// Last time the log or a session field changed.
    private(set) var lastEditAt: Date?

    /// With no edit for this long, the workout is taken to have ended at the last
    /// edit: a session left open overnight must not record 14 hours.
    static let idleCutoffSec: TimeInterval = 45 * 60
    /// A restored workout untouched for this long is not silently resumed.
    static let staleAfterSec: TimeInterval = 6 * 3600

    private let clock: () -> Date
    /// Called synchronously when a session starts or ends, so the draft on disk
    /// changes in the same turn (set by SessionKeeper).
    var onBoundary: () -> Void = {}

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
        onBoundary()
    }

    func end() {
        clear()
        onBoundary()
    }

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
        watchHealthUUID = nil
        lastEditAt = nil
        durationFromWatch = nil
        avgHRFromWatch = nil
    }

    // MARK: Draft
    var draft: WorkoutDraft.Strength? {
        guard let plan, let startDate else { return nil }
        return WorkoutDraft.Strength(plan: plan, log: log, startDate: startDate,
                                     lastEditAt: lastEditAt ?? startDate,
                                     durationSec: durationSec, avgHR: avgHR,
                                     caloriesManual: caloriesManual, watchResultId: watchResultId,
                                     watchHealthUUID: watchHealthUUID)
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
        watchHealthUUID = draft.watchHealthUUID
        lastEditAt = draft.lastEditAt      // after the assignments above, which count as edits
        let idle = clock().timeIntervalSince(draft.lastEditAt)
        restored = idle > Self.staleAfterSec ? .stale : .resumed
    }

    // MARK: Watch mirroring
    /// Mirror live telemetry into the session fields — only filling values the user
    /// hasn't typed, so manual edits always win.
    func absorb(live s: WatchLiveSample) {
        guard s.activityId == planId else { return }
        if s.avgHR > 0 { takeFromWatch(avgHR: "\(s.avgHR)") }
        if s.elapsedSec > 0 { takeFromWatch(durationSec: s.elapsedSec) }
        if let exs = s.exercises { mergeWatchExercises(exs) }
    }

    // A value the watch wrote keeps following the watch (the first live sample is
    // a few seconds and an early heart rate); a value the user typed is never touched.
    private var durationFromWatch: Int?
    private var avgHRFromWatch: String?
    private func takeFromWatch(durationSec seconds: Int) {
        guard durationSec == nil || durationSec == durationFromWatch else { return }
        durationFromWatch = seconds
        durationSec = seconds
    }
    private func takeFromWatch(avgHR value: String) {
        guard avgHR.isEmpty || avgHR == avgHRFromWatch else { return }
        avgHRFromWatch = value
        avgHR = value
    }

    /// Fold a finished watch workout into this session, so there is one session and
    /// nothing the wrist already tracked has to be typed again.
    /// Whether a finished watch workout belongs to this session: same activity, and
    /// dated the day this session started or today (a session can cross midnight).
    /// A late copy of yesterday's result for the same plan does not.
    func accepts(_ r: WatchResult) -> Bool {
        guard r.activityId == planId, let startDate else { return false }
        return r.date == isoFormatter.string(from: startDate) || r.date == isoFormatter.string(from: clock())
    }

    func absorb(result r: WatchResult) {
        guard accepts(r) else { return }
        if let hr = r.avgHR, hr > 0 { takeFromWatch(avgHR: "\(hr)") }
        if r.durationSec > 0 { takeFromWatch(durationSec: r.durationSec) }
        if caloriesManual.isEmpty, let k = r.activeKcal, k > 0 { caloriesManual = "\(k)" }
        if let exs = r.exercises { mergeWatchExercises(exs) }
        objectWillChange.send()     // watchResultId is part of the draft
        watchResultId = r.id
        watchHealthUUID = r.healthUUID
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
        // Already in Health from the watch: linked, so it is not exported twice.
        session.healthUUID = watchHealthUUID
        // Duration source of truth: the value the user typed, else whatever the
        // paired watch streamed in (both land in durationSec), else the clock.
        session.durationSec = durationSec ?? fallbackDurationSec(now: clock())
        session.startTime = startDate
        session.endTime = startDate.addingTimeInterval(TimeInterval(session.durationSec ?? 0))
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
        var watchHealthUUID: String?
    }
    struct Cardio: Codable, Equatable {
        var type: CardioType
        var startDate: Date
        /// Seconds from the running stretches already closed by a pause.
        var accumulatedSec: TimeInterval
        /// Start of the stretch still running when this was saved; nil if paused.
        var runningSince: Date?
        var distanceKm: Double?
        // What the paired watch reported. Once it has confirmed delivery it will not
        // send the result again, so losing it here would lose the measured numbers.
        var watchResult: WatchResult?
        var watchAvgHR: Int?
        var watchKcal: Int?
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

    /// Keep a draft that could not be decoded under another name, so the next save
    /// (which removes the file when no session is running) does not destroy it.
    func setAsideUnreadable() {
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent("active-workout.unreadable-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try FileManager.default.moveItem(at: url, to: aside)
        } catch {
            appLog.error("Unreadable workout draft not set aside: \(String(describing: error), privacy: .public)")
        }
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
            drafts.setAsideUnreadable()
            toast.show(t("wk.draft_unreadable"), duration: ToastCenter.longDuration)
            return
        }
        guard let draft else { return }
        if let strength = draft.strength { workout.restore(strength) }
        if let saved = draft.cardio { cardio.restore(saved, savedAt: draft.savedAt) }
        if let rest = draft.rest, workout.isActive { timer.resume(endsAt: rest.endsAt, total: rest.total) }
    }

    private func observe() {
        // Starting and ending are written at once, in the caller's own turn.
        workout.onBoundary = { [weak self] in self?.saveNow() }
        cardio.onBoundary = { [weak self] in self?.saveNow() }

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
        if workout.accepts(result) {
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

    /// A plain message that arrived while an Undo was on screen: shown after it.
    private var waiting: (message: String, duration: Double)?

    func show(_ msg: String, duration: Double = ToastCenter.defaultDuration, action: Action? = nil) {
        // A second message must not take away a deletion's Undo before it times out.
        if self.action != nil, action == nil, message != nil {
            waiting = (msg, duration)
            return
        }
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
        action = nil
        if let next = waiting {
            waiting = nil
            show(next.message, duration: next.duration)
            return
        }
        withAnimation { message = nil }
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


// MARK: - Live Activity control (app side)
// Starts, updates and ends the Lock Screen / Dynamic Island activity for a running
// workout. Every entry point is a no-op when Live Activities are unavailable or the
// user turned the setting off, so callers never need to check first.
//
// Updates are pushed only on real events (exercise changed, set logged, rest
// started/stopped). The clock and the rest countdown are rendered from dates by
// SwiftUI itself, so no per-second update is needed — which is what keeps this
// inside the system's update budget.
//
// Note: every ActivityKit type is written module-qualified. The app already has
// its own `Activity` (the TDEE activity level in Models.swift), which shadows
// ActivityKit's inside this module.
enum LiveActivityController {
    /// Id of the activity THIS session started. Ending an activity is asynchronous,
    /// so right after a restart the system list can still contain the outgoing one;
    /// looking up by id means an update can never land on the activity we just
    /// dismissed.
    private static var activeId: String?

    static func start(planName: String, planColor: String, startDate: Date, enabled: Bool) {
        #if canImport(ActivityKit)
        guard enabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A stale activity from a crashed session would otherwise sit there forever.
        endAll()
        let attrs = WorkoutActivityAttributes(planName: planName, planColor: planColor)
        let state = WorkoutActivityAttributes.ContentState(
            startDate: startDate, exercise: "", setsDone: 0, restEndsAt: nil)
        do {
            activeId = try ActivityKit.Activity<WorkoutActivityAttributes>.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil).id
        } catch {
            // The workout itself is unaffected; only the Lock Screen view is missing.
            appLog.error("Live Activity not started: \(String(describing: error), privacy: .public)")
        }
        #endif
    }

    /// Show the activity for a workout that is running: keep the one already on the
    /// Lock Screen when the app was relaunched mid-workout, otherwise start one.
    static func resume(planName: String, planColor: String, startDate: Date, enabled: Bool) {
        #if canImport(ActivityKit)
        guard enabled else { return }
        if activeId != nil { return }
        if let existing = ActivityKit.Activity<WorkoutActivityAttributes>.activities
            .first(where: { $0.attributes.planName == planName
                && abs($0.content.state.startDate.timeIntervalSince(startDate)) < 1 }) {
            activeId = existing.id
            return
        }
        start(planName: planName, planColor: planColor, startDate: startDate, enabled: enabled)
        #endif
    }

    static func update(exercise: String, setsDone: Int, restEndsAt: Date?) {
        #if canImport(ActivityKit)
        guard let id = activeId,
              let activity = ActivityKit.Activity<WorkoutActivityAttributes>.activities
                  .first(where: { $0.id == id }) else { return }
        var state = activity.content.state
        state.exercise = exercise
        state.setsDone = setsDone
        state.restEndsAt = restEndsAt
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        #endif
    }

    static func end() {
        #if canImport(ActivityKit)
        endAll()
        #endif
    }

    #if canImport(ActivityKit)
    private static func endAll() {
        activeId = nil
        for a in ActivityKit.Activity<WorkoutActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate) }
        }
    }
    #endif
}
