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
    /// A finished watch workout for an activity whose phone live view is open, so
    /// that view can fold it into the session it's about to save (no duplicate).
    @Published var pendingResult: WatchResult?
    /// Set by an open LiveWorkoutView to claim incoming watch data for its activity.
    var openActivityId: String?

    private weak var store: Store?
    private var bag = Set<AnyCancellable>()
    private var activated = false

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
            print("📱 WatchSync: activate() called")
        } else {
            print("📱 WatchSync: WCSession not supported")
        }
        #endif

        // Re-push the catalog whenever the plans, cardio activities or language
        // change, debounced so a burst of edits sends a single update.
        let triggers: [AnyPublisher<Void, Never>] = [
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
        guard let store, WCSession.isSupported() else {
            print("📱 WatchSync: pushContext skipped, store=\(store != nil) supported=\(WCSession.isSupported())")
            return
        }
        let session = WCSession.default
        print("📱 WatchSync: pushContext, activationState=\(session.activationState.rawValue) paired=\(session.isPaired) watchAppInstalled=\(session.isWatchAppInstalled) reachable=\(session.isReachable)")
        guard session.activationState == .activated else { return }

        var activities: [WatchActivity] = store.plans.map { plan in
            // For each exercise, attach the plan default reps + the last logged
            // session's per-set reps/weight, used as gray placeholders on the wrist.
            let last = store.lastSession(forPlan: plan.id)
            let exs = plan.exercises.map { pe -> WatchExercise in
                let logged = last?.exercises.first { $0.name == pe.name }
                return WatchExercise(id: pe.id.uuidString, name: pe.name, sets: max(1, pe.sets),
                                     reps: pe.reps,
                                     lastReps: logged?.sets.map { $0.reps } ?? [],
                                     lastWeight: logged?.sets.map { $0.weight } ?? [])
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
            print("📱 WatchSync: pushContext payload empty (encode failed)")
            return
        }
        // applicationContext always carries the latest catalog (newer replaces
        // older), so a watch that was off still gets a fresh list when it wakes.
        do {
            try session.updateApplicationContext(payload)
            print("📱 WatchSync: pushContext sent \(activities.count) activities")
        } catch {
            print("📱 WatchSync: updateApplicationContext failed: \(error)")
        }
        #endif
    }

    /// Ask a reachable watch to start an activity (its plan/cardio id).
    func startOnWatch(activityId: String) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage([WatchWire.startKey: activityId], replyHandler: nil, errorHandler: nil)
        #endif
    }

    /// Whether a reachable watch is available to receive a start command.
    var watchReachable: Bool {
        #if canImport(WatchConnectivity)
        return WCSession.isSupported() && WCSession.default.isReachable
        #else
        return false
        #endif
    }

    /// Whether a paired watch has the FitTracker companion installed (drives the
    /// "Start on Watch" affordance). Stable enough to read at render time.
    var watchAppAvailable: Bool {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return false }
        let s = WCSession.default
        return s.activationState == .activated && s.isPaired && s.isWatchAppInstalled
        #else
        return false
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
            if self.openActivityId == result.activityId {
                // The phone is mid-session for this activity: let that view absorb
                // the watch's numbers and save, so there's exactly one session.
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

        var exercises: [LoggedExercise] = []
        if r.kind == WatchKind.strength.rawValue {
            let plan = plans.first(where: { $0.id == r.activityId })
            if let rex = r.exercises, !rex.isEmpty {
                // Use the sets actually logged on the wrist, keeping the plan's
                // target/superset/method metadata when the exercise is known.
                exercises = rex.map { e in
                    let pe = plan?.exercises.first { $0.name == e.name }
                    let n = max(e.reps.count, e.weight.count)
                    let sets = (0..<max(1, n)).map { i in
                        SetEntry(reps: i < e.reps.count ? e.reps[i] : "",
                                 weight: i < e.weight.count ? e.weight[i] : "")
                    }
                    return LoggedExercise(name: e.name, sets: sets,
                                          target: pe.map { "\($0.sets)×\($0.reps)" } ?? "",
                                          supersetGroup: pe?.supersetGroup, method: pe?.method)
                }
            } else if let plan {
                // Fallback (older watch builds): empty sets from the plan template.
                exercises = plan.exercises.map { pe in
                    LoggedExercise(name: pe.name,
                                   sets: (0..<max(1, pe.sets)).map { _ in SetEntry() },
                                   target: "\(pe.sets)×\(pe.reps)",
                                   supersetGroup: pe.supersetGroup, method: pe.method)
                }
            }
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
        sessions.append(s)
    }
}
