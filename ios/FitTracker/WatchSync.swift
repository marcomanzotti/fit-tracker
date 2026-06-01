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
        guard let store, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var activities: [WatchActivity] = store.plans.map {
            WatchActivity(id: $0.id, kind: WatchKind.strength.rawValue, name: $0.name,
                          color: $0.color, sub: $0.sub, sport: nil)
        }
        activities += store.cardioTypes.map {
            WatchActivity(id: "cardio-\($0.id)", kind: WatchKind.cardio.rawValue, name: $0.name,
                          color: $0.color, sub: $0.sportType.label, sport: $0.sport)
        }
        let ctx = WatchContext(activities: activities, lang: store.prefs.langCode)
        let payload = WatchWire.encode(ctx, key: WatchWire.contextKey)
        guard !payload.isEmpty else { return }
        // applicationContext always carries the latest catalog (newer replaces
        // older), so a watch that was off still gets a fresh list when it wakes.
        try? session.updateApplicationContext(payload)
        #endif
    }

    /// Ingest a finished watch workout on the main thread.
    private func handle(_ dict: [String: Any]) {
        guard let result = WatchWire.decode(WatchResult.self, from: dict, key: WatchWire.resultKey) else { return }
        DispatchQueue.main.async { [weak self] in self?.store?.ingestWatchResult(result) }
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
        if r.kind == WatchKind.strength.rawValue, let plan = plans.first(where: { $0.id == r.activityId }) {
            exercises = plan.exercises.map { pe in
                LoggedExercise(name: pe.name,
                               sets: (0..<max(1, pe.sets)).map { _ in SetEntry() },
                               target: "\(pe.sets)×\(pe.reps)",
                               supersetGroup: pe.supersetGroup, method: pe.method)
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
