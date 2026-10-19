import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// MARK: - iPhone <-> Apple Watch connectivity (wearable purpose only)
// This is the ONLY phone-side change for the watch companion. It needs no extra
// entitlement (WatchConnectivity is unrestricted), so the existing unsigned IPA
// keeps sideloading exactly as before. Responsibilities:
//   • push the user's saved strength plans + cardio activities to the watch so
//     the wrist offers the same workouts (and follows language);
//   • receive a finished, live-tracked workout from the watch and turn it into a
//     normal WorkoutSession in the Store (idempotently).
// On a phone with no paired watch / no companion installed it is a silent no-op.
final class WatchSync: NSObject, ObservableObject {
    static let shared = WatchSync()

    /// Latest live telemetry from a workout running on the watch (nil when none).
    @Published var live: WatchLiveSample?
    /// True while a watch workout is actively streaming.
    @Published var liveActive = false
    /// A finished watch workout for the activity the phone has in progress, waiting
    /// to be folded into that session (so it is not saved a second time).
    @Published var pendingResult: WatchResult?
    /// Activity id of the session in progress on the phone, set by SessionKeeper
    /// for as long as that session runs — whatever screen is showing.
    var claimedActivityId: String?
    /// Results already routed. The watch sends each one over two transports.
    private var handledResultIds = Set<String>()

    private weak var store: Store?
    private var bag = Set<AnyCancellable>()
    private var activated = false
    /// The catalog last sent: the same one is not sent again after every edit.
    private var lastSentCatalog: Data?

    /// Wire the sync to the live Store and start the WC session. Safe to call
    /// more than once (e.g. on every AppRootView.onAppear) — it only sets up once.
    func attach(_ store: Store) {
        self.store = store
        guard !activated else { pushContext(); return }
        activated = true

        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate()
        }
        #endif

        // Re-push the catalog whenever the plans, cardio activities or language
        // change, and after every new session (the wrist's gray placeholders are
        // last time's numbers), debounced so a burst of edits sends a single update.
        let triggers: [AnyPublisher<Void, Never>] = [
            store.$sessions.map { _ in () }.eraseToAnyPublisher(),
            store.$plans.map { _ in () }.eraseToAnyPublisher(),
            store.$cardioTypes.map { _ in () }.eraseToAnyPublisher(),
            store.$prefs.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(triggers)
            .debounce(for: .seconds(0.6), scheduler: RunLoop.main)
            .sink { [weak self] in self?.pushContext() }
            .store(in: &bag)

        pushContext()
    }

    /// Build the activity catalog from the Store and send it to the watch.
    func pushContext() {
        #if canImport(WatchConnectivity)
        guard let store, WCSession.isSupported() else { return }
        let session = WCSession.default
        // No watch paired, or the companion not installed: nothing to push to.
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        var activities: [WatchActivity] = store.plans.map { plan in
            // For each exercise, attach the plan default reps + the last logged
            // session's per-set reps/weight, used as gray placeholders on the wrist.
            let last = store.lastSession(forPlan: plan.id)
            let exs = plan.exercises.map { pe -> WatchExercise in
                let logged = last?.exercises.first { $0.name == pe.name }
                // Timed (isometric) exercises track a hold countdown on the wrist:
                // the target comes from the plan's dedicated seconds field (older
                // plans keep it as text in `reps`), and lastSeconds carries the
                // previous session's holds.
                let targetSec = pe.exKind == .timed
                    ? (pe.effectiveTargetSec > 0 ? pe.effectiveTargetSec : 30) : nil
                let lastSeconds = pe.exKind == .timed
                    ? logged?.sets.map { $0.seconds.map { s in fmtSecs(s) } ?? "" }
                    : nil
                return WatchExercise(id: pe.id.uuidString, name: pe.name, sets: max(1, pe.sets),
                                     reps: pe.reps,
                                     lastReps: logged?.sets.map { $0.reps } ?? [],
                                     lastWeight: logged?.sets.map { $0.weight } ?? [],
                                     kind: pe.kind, targetSec: targetSec, lastSeconds: lastSeconds,
                                     restSec: pe.restTimerSec ?? store.prefs.timer)
            }
            return WatchActivity(id: plan.id, kind: WatchKind.strength.rawValue, name: plan.name,
                                 color: plan.color, sub: plan.sub, sport: nil, exercises: exs)
        }
        activities += store.cardioTypes.map {
            WatchActivity(id: "cardio-\($0.id)", kind: WatchKind.cardio.rawValue, name: $0.name,
                          color: $0.color, sub: $0.sportType.label, sport: $0.sport)
        }
        let ctx = WatchContext(activities: activities, lang: store.prefs.langCode)
        let payload = WatchWire.encode(ctx, key: WatchWire.contextKey)
        guard !payload.isEmpty else {
            appLog.error("Watch catalog could not be encoded")
            return
        }
        // applicationContext always carries the latest catalog (newer replaces
        // older), so a watch that was off still gets a fresh list when it wakes.
        let bytes = payload[WatchWire.contextKey] as? Data
        guard bytes != lastSentCatalog else { return }
        do {
            try session.updateApplicationContext(payload)
            lastSentCatalog = bytes
        } catch {
            appLog.error("Watch catalog not sent: \(String(describing: error), privacy: .public)")
        }
        #endif
    }

    /// Ask a reachable watch to start an activity (its plan/cardio id). `completion`
    /// reports, on the main queue, whether the watch acknowledged the command; it is
    /// not called at all when there is no reachable watch to ask.
    /// A rest started on the phone during a workout the watch is recording: the
    /// wrist counts it down and buzzes at the end. Nothing when it is not reachable.
    func sendRest(endsAt: Date) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage([WatchWire.restKey: endsAt.timeIntervalSince1970], replyHandler: nil, errorHandler: nil)
        #endif
    }

    func startOnWatch(activityId: String, completion: @escaping (_ acknowledged: Bool) -> Void) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage([WatchWire.startKey: activityId], replyHandler: { _ in
            DispatchQueue.main.async { completion(true) }
        }, errorHandler: { error in
            appLog.error("Start-on-watch not delivered: \(String(describing: error), privacy: .public)")
            DispatchQueue.main.async { completion(false) }
        })
        #endif
    }

    /// Route an inbound message: live telemetry updates the published sample; a
    /// finished result is either handed to an open phone live view (to merge and
    /// save once) or ingested straight into the store.
    private func handle(_ dict: [String: Any]) {
        if let sample = WatchWire.decode(WatchLiveSample.self, from: dict, key: WatchWire.liveKey) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.live = sample
                self.liveActive = !sample.ended
            }
            return
        }
        guard let result = WatchWire.decode(WatchResult.self, from: dict, key: WatchWire.resultKey) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.live = nil
            self.liveActive = false
            guard self.handledResultIds.insert(result.id).inserted else { return }
            // The in-memory set is empty after a relaunch, and the watch resends a
            // result it never saw confirmed: one already in the history stops here.
            if let id = UUID(uuidString: result.id),
               self.store?.sessions.contains(where: { $0.id == id }) == true { return }
            if self.claimedActivityId == result.activityId {
                // The phone is mid-session for this activity: the session absorbs
                // the watch's numbers and is saved once.
                self.pendingResult = result
            } else {
                self.store?.ingestWatchResult(result)
            }
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { DispatchQueue.main.async { [weak self] in self?.pushContext() } }
    }
    // iOS requires these two; re-activate so a re-paired watch keeps syncing.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message); replyHandler(["ok": true])
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { handle(userInfo) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }
}
#endif

// MARK: - Store ingestion of a watch workout
// Kept here (not in Store.swift) so the core store file is untouched by the
// wearable feature. A new field rule still applies: WatchResult ids dedupe.
extension Store {
    /// Turn a finished watch workout into a WorkoutSession. Strength sessions are
    /// pre-filled with the plan's exercises (empty sets) so the only thing left
    /// to do on the phone is type the weights; cardio sessions carry distance and
    /// the watch's measured active energy (which wins over the estimate).
    func ingestWatchResult(_ r: WatchResult) {
        // De-dupe: the same result may arrive via more than one transport.
        if let rid = UUID(uuidString: r.id), sessions.contains(where: { $0.id == rid }) { return }
        if let uuid = r.healthUUID, sessions.contains(where: { $0.allHealthUUIDs.contains(uuid) }) { return }
        let exercises = watchExercises(r)

        // The phone saved this workout before the watch's result came in: the
        // session takes what the watch measured instead of a second session
        // counting the same load and calories twice.
        if let i = sessions.firstIndex(where: { $0.date == r.date && $0.planId == r.activityId
                                                && $0.healthUUID == nil && $0.source == nil }) {
            var s = sessions[i]
            if s.durationSeconds == nil, r.durationSec > 0 { s.durationSec = r.durationSec }
            if s.avgHR == nil { s.avgHR = (r.avgHR ?? 0) > 0 ? r.avgHR : nil }
            if s.maxHRSes == nil { s.maxHRSes = (r.maxHR ?? 0) > 0 ? r.maxHR : nil }
            if (s.distanceKm ?? 0) <= 0, let d = r.distanceKm, d > 0 { s.distanceKm = d }
            if s.caloriesManual == nil, let k = r.activeKcal, k > 0 { s.caloriesManual = k }
            if s.exercises.isEmpty { s.exercises = exercises }
            s.healthUUID = r.healthUUID
            sessions[i] = s
            return
        }

        var s = WorkoutSession(date: r.date, planId: r.activityId, planName: r.name,
                               planColor: r.color, exercises: exercises)
        s.id = UUID(uuidString: r.id) ?? UUID()
        s.sport = (r.kind == WatchKind.cardio.rawValue) ? r.sport : nil
        s.durationSec = r.durationSec > 0 ? r.durationSec : nil
        s.avgHR = (r.avgHR ?? 0) > 0 ? r.avgHR : nil
        s.maxHRSes = (r.maxHR ?? 0) > 0 ? r.maxHR : nil
        s.distanceKm = (r.distanceKm ?? 0) > 0 ? r.distanceKm : nil
        if let k = r.activeKcal, k > 0 { s.caloriesManual = k }
        s.healthUUID = r.healthUUID
        sessions.append(s)
    }

    /// The strength sets logged on the wrist, with the plan's metadata; the plan's
    /// empty template when nothing was confirmed there; nothing for cardio.
    private func watchExercises(_ r: WatchResult) -> [LoggedExercise] {
        var exercises: [LoggedExercise] = []
        if r.kind == WatchKind.strength.rawValue {
            let plan = plans.first(where: { $0.id == r.activityId })
            if let rex = r.exercises, !rex.isEmpty {
                // Use the sets actually logged on the wrist, keeping the plan's
                // target/superset/method metadata when the exercise is known.
                exercises = rex.map { e in
                    let pe = plan?.exercises.first { $0.name == e.name }
                    let secs = e.seconds ?? []
                    let n = max(max(e.reps.count, e.weight.count), secs.count)
                    let sets = (0..<max(1, n)).map { i in
                        SetEntry(reps: i < e.reps.count ? e.reps[i] : "",
                                 weight: i < e.weight.count ? e.weight[i] : "",
                                 seconds: (i < secs.count ? pf(secs[i]) : 0) > 0 ? pf(secs[i]) : nil)
                    }
                    var le = LoggedExercise(name: e.name, sets: sets,
                                            target: pe.map { "\($0.sets)×\($0.reps)" } ?? "",
                                            supersetGroup: pe?.supersetGroup, method: pe?.method)
                    le.kind = e.kind ?? pe?.kind
                    le.isBodyweight = pe?.isBodyweight
                    // The wrist sends an unconfirmed set as an empty slot: not logged work.
                    le.sets = le.sets.filter { $0.filled }
                    return le
                }.filter { !$0.sets.isEmpty }
            }
            if exercises.isEmpty, let plan {
                // Nothing was confirmed on the wrist: empty sets from the plan template,
                // left to fill in on the phone.
                exercises = plan.exercises.map { pe in
                    LoggedExercise(name: pe.name,
                                   sets: (0..<max(1, pe.sets)).map { _ in SetEntry() },
                                   target: "\(pe.sets)×\(pe.reps)",
                                   supersetGroup: pe.supersetGroup, method: pe.method)
                }
            }
        }
        return exercises
    }
}

// MARK: - Timed-exercise helper (phone -> watch)
/// Whole-second string of a duration (drops a trailing .0). Used to seed the
/// wrist countdown's "last hold" placeholders from past sessions.
/// (Free-text target parsing lives on `PlanExercise.effectiveTargetSec`, so phone,
/// watch and progression all read the same number.)
func fmtSecs(_ v: Double) -> String { String(Int(v.rounded())) }
