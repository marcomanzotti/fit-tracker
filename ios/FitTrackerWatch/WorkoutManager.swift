import Foundation
import Combine
import HealthKit

// MARK: - Live workout tracking (HealthKit on the watch)
// Drives an HKWorkoutSession + HKLiveWorkoutBuilder: starts the right activity
// type for the chosen plan/cardio, streams live heart rate, active energy and
// distance, and on finish packages a WatchResult for the phone. The phone reads
// none of HealthKit — it just receives the summary over WatchConnectivity.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, requesting, active, ended }

    @Published var phase: Phase = .idle
    @Published var paused = false

    // Live metrics
    @Published var heartRate: Double = 0          // current bpm
    @Published var activeCalories: Double = 0      // kcal
    @Published var distanceMeters: Double = 0      // m
    @Published var elapsed: TimeInterval = 0       // seconds (pause-aware)

    // Summary (filled on finish)
    @Published var avgHR: Int = 0
    @Published var maxHR: Int = 0
    @Published var result: WatchResult?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var activity: WatchActivity?
    private var startDate = Date()
    private var ticker: AnyCancellable?

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Authorization
    func requestAuthorization() async -> Bool {
        guard available else { return false }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { read.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { read.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceCycling) { read.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceSwimming) { read.insert(t) }
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
    }

    // MARK: Start
    func start(_ activity: WatchActivity) async {
        guard available else { return }
        self.activity = activity
        phase = .requesting
        guard await requestAuthorization() else { phase = .idle; return }

        let config = HKWorkoutConfiguration()
        config.activityType = hkType(for: activity)
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            phase = .active
            paused = false
            startTicker()
        } catch {
            phase = .idle
        }
    }

    private func startTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, let b = self.builder else { return }
                self.elapsed = b.elapsedTime
            }
    }

    // MARK: Controls
    func togglePause() {
        guard let session else { return }
        if paused { session.resume() } else { session.pause() }
    }

    func end() {
        guard let session else { phase = .ended; return }
        session.end()   // -> stateDidChange(.ended) finalizes & builds the result
    }

    // MARK: Finalize
    private func finish() async {
        ticker?.cancel()
        guard let builder else { phase = .ended; return }
        let end = Date()
        do {
            try await builder.endCollection(at: end)
            _ = try? await builder.finishWorkout()
        } catch { /* still produce a summary from whatever we collected */ }

        let dur = Int(builder.elapsedTime.rounded())
        let kcal = Int(activeCalories.rounded())
        let km = distanceMeters > 0 ? (distanceMeters / 1000 * 100).rounded() / 100 : nil
        let a = activity
        let r = WatchResult(
            id: UUID().uuidString,
            date: wkToday(),
            kind: a?.kind ?? WatchKind.cardio.rawValue,
            activityId: a?.id ?? "",
            name: a?.name ?? wt("cardio"),
            color: a?.color ?? "ffe000",
            sport: a?.sport,
            durationSec: max(0, dur),
            avgHR: avgHR > 0 ? avgHR : nil,
            maxHR: maxHR > 0 ? maxHR : nil,
            activeKcal: kcal > 0 ? kcal : nil,
            distanceKm: km
        )
        result = r
        phase = .ended
    }

    func sendToPhone() {
        guard let r = result else { return }
        WatchLink.shared.send(r)
    }

    func reset() {
        session = nil; builder = nil; activity = nil; result = nil
        heartRate = 0; activeCalories = 0; distanceMeters = 0; elapsed = 0
        avgHR = 0; maxHR = 0; paused = false; phase = .idle
        ticker?.cancel()
    }

    // MARK: Sport -> HealthKit activity type
    private func hkType(for a: WatchActivity) -> HKWorkoutActivityType {
        if a.kindValue == .strength { return .traditionalStrengthTraining }
        switch a.sport {
        case "running":  return .running
        case "cycling":  return .cycling
        case "walking":  return .walking
        case "swimming": return .swimming
        default:         return .other
        }
    }

    fileprivate func distanceType(for a: WatchActivity?) -> HKQuantityType? {
        guard let a, a.kindValue == .cardio else { return nil }
        switch a.sport {
        case "running", "walking": return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case "cycling":            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case "swimming":           return HKObjectType.quantityType(forIdentifier: .distanceSwimming)
        default:                   return nil
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        Task { @MainActor in
            switch toState {
            case .paused:  self.paused = true
            case .running: self.paused = false
            case .ended:   await self.finish()
            default:       break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.phase = .ended }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let qType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: qType) else { continue }
            Task { @MainActor in self.apply(qType, stats) }
        }
    }

    @MainActor
    private func apply(_ qType: HKQuantityType, _ stats: HKStatistics) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        if qType == HKObjectType.quantityType(forIdentifier: .heartRate) {
            if let v = stats.mostRecentQuantity()?.doubleValue(for: bpmUnit) { heartRate = v }
            if let v = stats.averageQuantity()?.doubleValue(for: bpmUnit) { avgHR = Int(v.rounded()) }
            if let v = stats.maximumQuantity()?.doubleValue(for: bpmUnit) { maxHR = Int(v.rounded()) }
        } else if qType == HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            if let v = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) { activeCalories = v }
        } else if qType == distanceType(for: activity) {
            if let v = stats.sumQuantity()?.doubleValue(for: .meter()) { distanceMeters = v }
        }
    }
}
