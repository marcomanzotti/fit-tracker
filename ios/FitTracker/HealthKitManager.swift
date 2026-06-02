import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Apple Health import (optional)
// Reads steps, resting heart rate and HRV (SDNN) and feeds them into the daily
// entries. Everything is optional and additive: the app works fully without it,
// and imported values only fill gaps — they never overwrite what you typed by
// hand. Wrapped in canImport so it degrades cleanly if HealthKit is unavailable.
struct HealthDaySample {
    var date: String
    var steps: Int?
    var restHR: Int?
    var hrvSDNN: Double?
    var activeKcal: Int?
    var exerciseMin: Int?
}

// MARK: - A workout read back from Apple Health
// Any watch that pairs with the iPhone (Apple Watch, Garmin, Fitbit, Polar,
// Coros, Huawei, Amazfit, …) writes its sessions into Apple Health as HKWorkout
// records. We read those and turn them into the app's own WorkoutSession, so the
// app supports every paired wearable without any vendor SDK.
struct HealthWorkout {
    var uuid: String          // HKWorkout UUID — dedupe key
    var date: String          // yyyy-MM-dd of the start
    var sport: String         // Sport raw value (running/cycling/…/strength/other)
    var durationSec: Int
    var kcal: Int?            // active energy burned
    var distanceKm: Double?
    var avgHR: Int?
    var maxHR: Int?
    var fromThisApp: Bool     // recorded by FitTracker itself (our Apple Watch app)
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Ask the user to grant read access to steps / resting HR / HRV.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        #if canImport(HealthKit)
        guard isAvailable else { completion(false); return }
        var types = Set<HKObjectType>()
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceCycling) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceSwimming) { types.insert(t) }
        types.insert(HKObjectType.workoutType())
        store.requestAuthorization(toShare: nil, read: types) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
        #else
        completion(false)
        #endif
    }

    /// Pull daily aggregates for the last `days` days and return one sample per day.
    func fetch(days: Int, completion: @escaping ([HealthDaySample]) -> Void) {
        #if canImport(HealthKit)
        guard isAvailable else { completion([]); return }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else { completion([]); return }

        var steps: [String: Int] = [:]
        var rest: [String: Int] = [:]
        var hrv: [String: Double] = [:]
        var energy: [String: Int] = [:]
        var exMin: [String: Int] = [:]
        let group = DispatchGroup()

        // Steps: summed per day.
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            collect(t, unit: HKUnit.count(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map { steps[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // Resting HR: daily average.
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            group.enter()
            collect(t, unit: HKUnit.count().unitDivided(by: .minute()), options: .discreteAverage, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { rest[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // HRV SDNN: daily average in milliseconds.
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            group.enter()
            collect(t, unit: HKUnit.secondUnit(with: .milli), options: .discreteAverage, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { hrv[k] = (v * 10).rounded() / 10 }
                group.leave()
            }
        }

        // Active energy burned: summed per day (kcal).
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            collect(t, unit: .kilocalorie(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { energy[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // Exercise minutes: summed per day.
        if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            group.enter()
            collect(t, unit: .minute(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { exMin[k] = Int(v.rounded()) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let keys = Set(steps.keys).union(rest.keys).union(hrv.keys).union(energy.keys).union(exMin.keys)
            let out = keys.sorted().map {
                HealthDaySample(date: $0, steps: steps[$0], restHR: rest[$0], hrvSDNN: hrv[$0],
                                activeKcal: energy[$0], exerciseMin: exMin[$0])
            }
            completion(out)
        }
        #else
        completion([])
        #endif
    }

    /// Pull HKWorkout records for the last `days` days — these come from ANY watch
    /// paired with the iPhone (Apple Watch, Garmin, Fitbit, Polar, …) via Health.
    func fetchWorkouts(days: Int, completion: @escaping ([HealthWorkout]) -> Void) {
        #if canImport(HealthKit)
        guard isAvailable else { completion([]); return }
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: end)) else { completion([]); return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let bundle = Bundle.main.bundleIdentifier ?? "com.marco.manzotti.fittracker"
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            let out = workouts.map { w -> HealthWorkout in self.summarize(w, appBundle: bundle) }
            DispatchQueue.main.async { completion(out) }
        }
        store.execute(query)
        #else
        completion([])
        #endif
    }

    #if canImport(HealthKit)
    /// Reduce one HKWorkout to the fields the app stores in a WorkoutSession.
    private func summarize(_ w: HKWorkout, appBundle: String) -> HealthWorkout {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        var avg: Int? = nil, mx: Int? = nil
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
           let stats = w.statistics(for: hrType) {
            if let a = stats.averageQuantity()?.doubleValue(for: bpmUnit), a > 0 { avg = Int(a.rounded()) }
            if let m = stats.maximumQuantity()?.doubleValue(for: bpmUnit), m > 0 { mx = Int(m.rounded()) }
        }
        var kcal: Int? = nil
        if let eType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
           let v = w.statistics(for: eType)?.sumQuantity()?.doubleValue(for: .kilocalorie()), v > 0 {
            kcal = Int(v.rounded())
        } else if let v = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()), v > 0 {
            kcal = Int(v.rounded())
        }
        var km: Double? = nil
        if let v = w.totalDistance?.doubleValue(for: .meter()), v > 0 {
            km = (v / 1000 * 100).rounded() / 100
        }
        let src = w.sourceRevision.source.bundleIdentifier
        return HealthWorkout(
            uuid: w.uuid.uuidString,
            date: isoFormatter.string(from: w.startDate),
            sport: Self.sport(for: w.workoutActivityType),
            durationSec: Int(w.duration.rounded()),
            kcal: kcal, distanceKm: km, avgHR: avg, maxHR: mx,
            fromThisApp: src == appBundle || src.hasPrefix("com.marco.manzotti.fittracker"))
    }

    /// Map an HKWorkoutActivityType to the app's Sport raw value.
    private static func sport(for t: HKWorkoutActivityType) -> String {
        switch t {
        case .running:  return "running"
        case .walking, .hiking: return "walking"
        case .cycling, .handCycling: return "cycling"
        case .swimming: return "swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .crossTraining:
            return "strength"
        default: return "other"
        }
    }

    /// Run a statistics-collection query bucketed by day, return [yyyy-MM-dd: value].
    private func collect(_ type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions,
                         start: Date, end: Date, cal: Calendar,
                         done: @escaping ([String: Double]) -> Void) {
        let anchor = cal.startOfDay(for: start)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start,
                                                    end: cal.date(byAdding: .day, value: 1, to: end),
                                                    options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: options, anchorDate: anchor, intervalComponents: interval)
        query.initialResultsHandler = { _, results, _ in
            var map: [String: Double] = [:]
            results?.enumerateStatistics(from: anchor, to: end) { stat, _ in
                let qty = options == .cumulativeSum ? stat.sumQuantity() : stat.averageQuantity()
                if let qty { map[isoFormatter.string(from: stat.startDate)] = qty.doubleValue(for: unit) }
            }
            DispatchQueue.main.async { done(map) }
        }
        store.execute(query)
    }
    #endif
}
