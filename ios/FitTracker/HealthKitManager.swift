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

        group.notify(queue: .main) {
            let keys = Set(steps.keys).union(rest.keys).union(hrv.keys)
            let out = keys.sorted().map { HealthDaySample(date: $0, steps: steps[$0], restHR: rest[$0], hrvSDNN: hrv[$0]) }
            completion(out)
        }
        #else
        completion([])
        #endif
    }

    #if canImport(HealthKit)
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
