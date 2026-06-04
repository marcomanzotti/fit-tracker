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
    var sleepHours: Double?
    var sleepHR: Int?
    var vo2max: Double?
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
    var displayName: String   // human-readable activity name ("Weight Training", "Running", …)
    var durationSec: Int
    var kcal: Int?            // active energy burned
    var distanceKm: Double?
    var avgHR: Int?
    var maxHR: Int?
    var fromThisApp: Bool     // recorded by FitTracker itself (our Apple Watch app)
    var sourceName: String    // origin app name ("Garmin Connect", "Polar Flow", …)
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
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .vo2Max) { types.insert(t) }
        types.insert(HKObjectType.workoutType())
        store.requestAuthorization(toShare: nil, read: types) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
        #else
        completion(false)
        #endif
    }

    /// Pull daily aggregates for the last `days` days and return one sample per day.
    /// Only the categories the user selected are queried (`categories` holds keys
    /// from `HealthCategory`). Defaults to all daily metrics for callers that don't
    /// pass a selection.
    func fetch(days: Int, categories: Set<String> = Set(HealthCategory.allKeys),
               completion: @escaping ([HealthDaySample]) -> Void) {
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
        var sleepHrs: [String: Double] = [:]
        var sleepHR: [String: Int] = [:]
        var vo2: [String: Double] = [:]
        let group = DispatchGroup()

        // Steps: summed per day.
        if categories.contains("steps"), let t = HKObjectType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            collect(t, unit: HKUnit.count(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map { steps[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // Resting HR: daily average.
        if categories.contains("restHR"), let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            group.enter()
            collect(t, unit: HKUnit.count().unitDivided(by: .minute()), options: .discreteAverage, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { rest[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // HRV SDNN: daily average in milliseconds.
        if categories.contains("hrv"), let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            group.enter()
            collect(t, unit: HKUnit.secondUnit(with: .milli), options: .discreteAverage, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { hrv[k] = (v * 10).rounded() / 10 }
                group.leave()
            }
        }
        // Active energy burned: summed per day (kcal).
        if categories.contains("activeKcal"), let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            collect(t, unit: .kilocalorie(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { energy[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // Exercise minutes: summed per day.
        if categories.contains("exerciseMin"), let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            group.enter()
            collect(t, unit: .minute(), options: .cumulativeSum, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { exMin[k] = Int(v.rounded()) }
                group.leave()
            }
        }
        // VO2 max: daily average (mL/kg/min). Apple records it sparsely, so a day
        // without a reading simply carries no value (the last value carries forward
        // in the UI).
        if categories.contains("vo2max"), let t = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
            group.enter()
            collect(t, unit: unit, options: .discreteAverage, start: start, end: end, cal: cal) { map in
                for (k, v) in map where v > 0 { vo2[k] = (v * 10).rounded() / 10 }
                group.leave()
            }
        }
        // Sleep duration (+ optional sleeping heart rate from the asleep windows).
        if categories.contains("sleep") || categories.contains("sleepHR") {
            group.enter()
            collectSleep(start: start, end: end, cal: cal,
                         wantHR: categories.contains("sleepHR")) { hrs, hr in
                if categories.contains("sleep") { sleepHrs = hrs }
                sleepHR = hr
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let keys = Set(steps.keys).union(rest.keys).union(hrv.keys).union(energy.keys)
                .union(exMin.keys).union(sleepHrs.keys).union(sleepHR.keys).union(vo2.keys)
            let out = keys.sorted().map {
                HealthDaySample(date: $0, steps: steps[$0], restHR: rest[$0], hrvSDNN: hrv[$0],
                                activeKcal: energy[$0], exerciseMin: exMin[$0],
                                sleepHours: sleepHrs[$0], sleepHR: sleepHR[$0], vo2max: vo2[$0])
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
            displayName: Self.displayName(for: w.workoutActivityType),
            durationSec: Int(w.duration.rounded()),
            kcal: kcal, distanceKm: km, avgHR: avg, maxHR: mx,
            fromThisApp: src == appBundle || src.hasPrefix("com.marco.manzotti.fittracker"),
            sourceName: w.sourceRevision.source.name)
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

    /// Human-readable name for the workout type — shown as the session name in
    /// the app so users can distinguish "Weight Training" from "Running" etc.
    private static func displayName(for t: HKWorkoutActivityType) -> String {
        switch t {
        case .running:                        return "Running"
        case .walking:                        return "Walking"
        case .hiking:                         return "Hiking"
        case .cycling:                        return "Cycling"
        case .handCycling:                    return "Hand Cycling"
        case .swimming:                       return "Swimming"
        case .traditionalStrengthTraining:    return "Weight Training"
        case .functionalStrengthTraining:     return "Functional Strength"
        case .coreTraining:                   return "Core Training"
        case .crossTraining:                  return "Cross Training"
        case .yoga:                           return "Yoga"
        case .pilates:                        return "Pilates"
        case .rowing:                         return "Rowing"
        case .elliptical:                     return "Elliptical"
        case .stairClimbing:                  return "Stair Climbing"
        case .stepTraining:                   return "Step Training"
        case .highIntensityIntervalTraining:  return "HIIT"
        case .flexibility:                    return "Flexibility"
        case .jumpRope:                       return "Jump Rope"
        case .boxing:                         return "Boxing"
        case .martialArts:                    return "Martial Arts"
        case .soccer:                         return "Soccer"
        case .basketball:                     return "Basketball"
        case .tennis:                         return "Tennis"
        case .golf:                           return "Golf"
        case .dance:                          return "Dance"
        case .barre:                          return "Barre"
        case .skatingSports:                  return "Skating"
        case .snowSports:                     return "Snow Sports"
        case .surfingSports:                  return "Surfing"
        case .waterFitness:                   return "Water Fitness"
        case .mindAndBody:                    return "Mind & Body"
        default:                              return "Workout"
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

    /// Sleep-analysis aggregation: total asleep hours per wake-day, and (optionally)
    /// the average heart rate measured inside those asleep windows. Each asleep
    /// sample is credited to the day it ends on (the morning you wake up).
    private func collectSleep(start: Date, end: Date, cal: Calendar, wantHR: Bool,
                              done: @escaping ([String: Double], [String: Int]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { done([:], [:]); return }
        let endPlus = cal.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endPlus, options: [])
        let q = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                              limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let cats = (samples as? [HKCategorySample]) ?? []
            var asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleep.rawValue]
            if #available(iOS 16.0, watchOS 9.0, *) {
                asleep.formUnion([
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ])
            }
            var hours: [String: Double] = [:]
            var intervals: [(start: Date, end: Date, day: String)] = []
            for s in cats where asleep.contains(s.value) {
                let day = isoFormatter.string(from: cal.startOfDay(for: s.endDate))
                hours[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
                intervals.append((s.startDate, s.endDate, day))
            }
            for k in hours.keys { hours[k] = (hours[k]! * 10).rounded() / 10 }

            guard wantHR, !intervals.isEmpty,
                  let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                DispatchQueue.main.async { done(hours, [:]) }
                return
            }
            let bpm = HKUnit.count().unitDivided(by: .minute())
            let hrQ = HKSampleQuery(sampleType: hrType, predicate: predicate,
                                    limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, hrSamples, _ in
                var sum: [String: Double] = [:], cnt: [String: Int] = [:]
                for hs in (hrSamples as? [HKQuantitySample]) ?? [] {
                    let t = hs.startDate
                    if let iv = intervals.first(where: { $0.start <= t && t <= $0.end }) {
                        sum[iv.day, default: 0] += hs.quantity.doubleValue(for: bpm)
                        cnt[iv.day, default: 0] += 1
                    }
                }
                var hr: [String: Int] = [:]
                for (k, c) in cnt where c > 0 { hr[k] = Int((sum[k]! / Double(c)).rounded()) }
                DispatchQueue.main.async { done(hours, hr) }
            }
            self.store.execute(hrQ)
        }
        store.execute(q)
    }
    #endif
}
