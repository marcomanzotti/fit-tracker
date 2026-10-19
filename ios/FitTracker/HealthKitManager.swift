import Band10Sync
import CoreLocation
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Apple Health import (optional)
// Reads the daily metrics, the night's sleep and the overnight vitals and feeds
// them into the daily entries. Everything is optional and additive: the app works
// fully without it, and a value the user typed is never overwritten (see
// `Store.applyHealthSamples`). Wrapped in canImport so it degrades cleanly if
// HealthKit is unavailable.
struct HealthDaySample {
    var date: String
    var values: [HealthField: Double] = [:]
    /// The night ending this day, stage by stage (see `DailyEntry.sleepTimeline`).
    var sleepTimeline: [Int]?
}

// MARK: - Sleep, grouped into nights
/// One sleep-analysis sample as Health reports it.
struct SleepSample {
    enum Stage {
        case inBed, awake, asleep, core, deep, rem
        /// Code in `DailyEntry.sleepTimeline`; nil for time in bed, which is not drawn.
        var code: Int? {
            switch self {
            case .awake:  return 0
            case .core:   return 1
            case .deep:   return 2
            case .rem:    return 3
            case .asleep: return 4
            case .inBed:  return nil
            }
        }
    }
    var start: Date
    var end: Date
    var stage: Stage
    var source: String
}

/// The main sleep that ends on a day, as one source recorded it.
struct SleepNight {
    var day: String                          // yyyy-MM-dd of waking up
    var start: Date                          // first sample of the night
    var end: Date                            // last sample of the night
    var asleep: [(start: Date, end: Date)]   // merged time asleep
    var slices: [SleepSample] = []           // the night stage by stage, no overlaps
    var deepMin = 0.0, remMin = 0.0, coreMin = 0.0, awakeMin = 0.0
    var asleepHours: Double { asleep.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 3600 }
    var inBedHours: Double { end.timeIntervalSince(start) / 3600 }
    var hasStages: Bool { deepMin + remMin + coreMin > 0 }
    func isAsleep(at t: Date) -> Bool { asleep.contains { $0.start <= t && t <= $0.end } }
}

enum SleepWindows {
    /// Merges overlapping or touching windows, sorted by start.
    static func merge(_ windows: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        let sorted = windows.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        return sorted.reduce(into: []) { merged, window in
            if let last = merged.last, window.start <= last.end {
                merged[merged.count - 1].end = max(last.end, window.end)
            } else {
                merged.append(window)
            }
        }
    }

    /// Samples of one source closer than this belong to the same night.
    static let nightGap: TimeInterval = 3 * 3600

    /// One night per wake-up day, from a single source: taking one source, not
    /// the union of all of them, keeps the Watch and the band from adding up and
    /// keeps an "awake" period of the chosen source out of the time asleep.
    ///
    /// Each source's samples are grouped into nights; per day each source keeps
    /// its longest one (a nap never replaces the night). Then, between sources,
    /// a night with REM staging (Apple Watch) wins as long as it covers at least
    /// 85 % of the longest: it is the more detailed and better validated
    /// recording, while a watch that died at 3 am still loses to the band.
    static func nights(_ samples: [SleepSample], cal: Calendar) -> [SleepNight] {
        var bySource: [String: [String: SleepNight]] = [:]
        for (source, group) in Dictionary(grouping: samples, by: \.source) {
            for cluster in clusters(group) {
                guard let night = night(from: cluster, cal: cal) else { continue }
                if let current = bySource[source]?[night.day], current.asleepHours >= night.asleepHours { continue }
                bySource[source, default: [:]][night.day] = night
            }
        }
        let candidates = Dictionary(grouping: bySource.values.flatMap(\.values), by: \.day)
        return candidates.values.compactMap { nights -> SleepNight? in
            guard let longest = nights.max(by: { $0.asleepHours < $1.asleepHours }) else { return nil }
            let detailed = nights.filter { $0.remMin > 0 && $0.asleepHours >= longest.asleepHours * preferredShare }
            return detailed.max(by: { $0.asleepHours < $1.asleepHours }) ?? longest
        }
        .sorted { $0.start < $1.start }
    }

    /// How much of the longest night a fully staged one must cover to be preferred.
    static let preferredShare = 0.85

    /// The night whose span contains `t` (nights sorted by start).
    static func night(at t: Date, in nights: [SleepNight]) -> SleepNight? {
        var lo = 0, hi = nights.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if nights[mid].start <= t { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0, t <= nights[lo - 1].end else { return nil }
        return nights[lo - 1]
    }

    private static func clusters(_ samples: [SleepSample]) -> [[SleepSample]] {
        var out: [[SleepSample]] = []
        var clusterEnd = Date.distantPast
        for s in samples.sorted(by: { $0.start < $1.start }) where s.end > s.start {
            if !out.isEmpty, s.start <= clusterEnd.addingTimeInterval(nightGap) {
                out[out.count - 1].append(s)
                clusterEnd = max(clusterEnd, s.end)
            } else {
                out.append([s])
                clusterEnd = s.end
            }
        }
        return out
    }

    private static func night(from cluster: [SleepSample], cal: Calendar) -> SleepNight? {
        let asleepStages: Set<SleepSample.Stage> = [.asleep, .core, .deep, .rem]
        let slices = paint(cluster)
        let asleep = merge(slices.filter { asleepStages.contains($0.stage) }.map { ($0.start, $0.end) })
        guard !asleep.isEmpty,
              let start = cluster.map(\.start).min(), let end = cluster.map(\.end).max() else { return nil }
        let wake = cal.dateComponents([.year, .month, .day], from: end)
        var night = SleepNight(day: String(format: "%04d-%02d-%02d", wake.year ?? 0, wake.month ?? 0, wake.day ?? 0),
                               start: start, end: end, asleep: asleep, slices: slices)
        for s in slices {
            let minutes = s.end.timeIntervalSince(s.start) / 60
            switch s.stage {
            case .deep:  night.deepMin += minutes
            case .rem:   night.remMin += minutes
            case .core:  night.coreMin += minutes
            case .awake: night.awakeMin += minutes
            case .inBed, .asleep: break
            }
        }
        return night
    }

    /// One source's night as non-overlapping slices. Where its samples overlap,
    /// a sleep stage beats "in bed", and between stages the one that started
    /// later wins: a source that re-scores the night (the Xiaomi band did, every
    /// half hour) must not count the same minutes twice.
    static func paint(_ samples: [SleepSample]) -> [SleepSample] {
        let sorted = samples.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        let bounds = Array(Set(sorted.flatMap { [$0.start, $0.end] })).sorted()
        func beats(_ a: SleepSample, _ b: SleepSample) -> Bool {
            (a.stage == .inBed) != (b.stage == .inBed) ? b.stage == .inBed : a.start > b.start
        }
        var slices: [SleepSample] = []
        var active: [SleepSample] = []
        var next = 0
        for (from, to) in zip(bounds, bounds.dropFirst()) {
            while next < sorted.count, sorted[next].start <= from {
                active.append(sorted[next])
                next += 1
            }
            active.removeAll { $0.end <= from }
            guard let top = active.reduce(nil, { best, s in best.map { beats(s, $0) ? s : $0 } ?? s }) else { continue }
            if let last = slices.last, last.stage == top.stage, last.end == from {
                slices[slices.count - 1].end = to
            } else {
                slices.append(SleepSample(start: from, end: to, stage: top.stage, source: top.source))
            }
        }
        return slices
    }
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
    var measures: WorkoutMeasures
    var fromThisApp: Bool     // recorded or exported by FitTracker itself (not the band it syncs)
    var sourceName: String    // origin app name ("Garmin Connect", "Polar Flow", …)
    var start: Date? = nil
    var end: Date? = nil

    var durationSec: Int { measures.durationSec }
    var kcal: Int? { measures.kcal }
    var distanceKm: Double? { measures.distanceKm }
    var avgHR: Int? { measures.avgHR }
    var maxHR: Int? { measures.maxHR }
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    #if canImport(HealthKit)
    /// Internal so the training queries in Training.swift share the same store.
    let store = HKHealthStore()
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Ask for read access to every metric the app uses, plus write access for
    /// workouts and active energy so logged sessions can be pushed back into
    /// Health. Asking for write here (rather than at export time) means the
    /// permission sheet appears once; iOS never reveals whether write was granted,
    /// so the export path treats a failed save as "not permitted" and says so.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        #if canImport(HealthKit)
        guard isAvailable else { completion(false); return }
        var share = Set<HKSampleType>()
        share.insert(HKObjectType.workoutType())
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { share.insert(t) }
        // What the Xiaomi band records (Band10Sync): asked here too, so that a
        // single permission sheet covers everything FitTracker writes.
        for id in [HKQuantityTypeIdentifier.stepCount, .distanceWalkingRunning, .heartRate, .restingHeartRate, .oxygenSaturation] {
            if let t = HKObjectType.quantityType(forIdentifier: id) { share.insert(t) }
        }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { share.insert(t) }
        // An imported file goes into Health with its distance and route.
        for id in [HKQuantityTypeIdentifier.distanceCycling, .distanceSwimming] {
            if let t = HKObjectType.quantityType(forIdentifier: id) { share.insert(t) }
        }
        share.insert(HKSeriesType.workoutRoute())

        var read = Set<HKObjectType>([HKObjectType.workoutType()]).union(Self.workoutReadTypes)
        let quantities = Self.dailyStats.map(\.id) + Self.nightVitals.map(\.id)
            + [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
        for id in quantities {
            if let t = HKObjectType.quantityType(forIdentifier: id) { read.insert(t) }
        }
        for id in [HKCategoryTypeIdentifier.sleepAnalysis, .appleStandHour] {
            if let t = HKObjectType.categoryType(forIdentifier: id) { read.insert(t) }
        }
        store.requestAuthorization(toShare: share, read: read) { ok, _ in
            DispatchQueue.main.async {
                completion(ok)
                // Band files waiting for this permission go to Health at once.
                Task { await BandSyncEngine.fitTracker.importPending() }
            }
        }
        #else
        completion(false)
        #endif
    }

    /// Pull daily values for the last `days` days and return one sample per day.
    /// Only the categories the user selected are queried (`categories` holds keys
    /// from `HealthCategory`).
    func fetch(days: Int, categories: Set<String> = Set(HealthCategory.allKeys),
               completion: @escaping (_ samples: [HealthDaySample], _ complete: Bool) -> Void) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else { completion([], false); return }
        fetch(from: start, to: end, categories: categories, completion: completion)
    }

    /// Pull daily values for an explicit day range (both ends are day starts, `to`
    /// inclusive). `complete` is false when any query failed (locked phone, partial
    /// access): the samples returned are then only part of the picture, not "there
    /// was nothing".
    func fetch(from start: Date, to end: Date,
               categories: Set<String> = Set(HealthCategory.allKeys),
               completion: @escaping (_ samples: [HealthDaySample], _ complete: Bool) -> Void) {
        #if canImport(HealthKit)
        guard isAvailable else { completion([], false); return }
        let cal = Calendar.current
        var values: [String: [HealthField: Double]] = [:]
        var timelines: [String: [Int]] = [:]
        var failed = false
        // Every callback below arrives on the main queue, so these writes never race.
        func put(_ field: HealthField, _ map: [String: Double]?) {
            guard let map else { failed = true; return }
            for (day, v) in map where v.isFinite { values[day, default: [:]][field] = v }
        }
        let group = DispatchGroup()

        for stat in Self.dailyStats where categories.contains(stat.category.rawValue) {
            guard let type = HKObjectType.quantityType(forIdentifier: stat.id) else { continue }
            group.enter()
            collect(type, unit: stat.unit, options: stat.sum ? .cumulativeSum : .discreteAverage,
                    start: start, end: end, cal: cal) { map in
                put(stat.field, map?.mapValues { $0 * stat.scale }.filter { $0.value > 0 })
                group.leave()
            }
        }
        if categories.contains(HealthCategory.standHours.rawValue) {
            group.enter()
            countStandHours(start: start, end: end, cal: cal) { map in
                put(.standHours, map)
                group.leave()
            }
        }
        let nightCategories = Set([HealthCategory.sleep, .sleepHR, .hrv, .spo2, .respRate, .wristTemp].map(\.rawValue))
        if !categories.isDisjoint(with: nightCategories) {
            group.enter()
            collectNights(start: start, end: end, cal: cal, categories: categories) { byDay, nightTimelines, ok in
                if !ok { failed = true }
                for (day, fields) in byDay { values[day, default: [:]].merge(fields) { _, new in new } }
                timelines = nightTimelines
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(values.keys.sorted().map {
                HealthDaySample(date: $0, values: values[$0] ?? [:], sleepTimeline: timelines[$0])
            }, !failed)
        }
        #else
        completion([], false)
        #endif
    }

    /// Pull HKWorkout records from ANY watch paired with the iPhone (Apple Watch,
    /// Garmin, Fitbit, Polar, …): the last `days` days, or only those that start on
    /// `onDate` (the calendar's manual import, when the automatic match missed one).
    func fetchWorkouts(days: Int = 0, onDate: String? = nil, completion: @escaping ([HealthWorkout]) -> Void) {
        #if canImport(HealthKit)
        let cal = Calendar.current
        let range: (start: Date, end: Date)?
        if let onDate {
            range = isoFormatter.date(from: onDate).flatMap { d in
                let start = cal.startOfDay(for: d)
                return cal.date(byAdding: .day, value: 1, to: start).map { (start, $0) }
            }
        } else {
            range = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())).map { ($0, Date()) }
        }
        guard isAvailable, let range else { completion([]); return }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let bundle = Bundle.main.bundleIdentifier ?? "com.marco.manzotti.fittracker"
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let out = ((samples as? [HKWorkout]) ?? []).map { self.summarize($0, appBundle: bundle) }
            DispatchQueue.main.async { completion(out) }
        }
        store.execute(query)
        #else
        completion([])
        #endif
    }

    // MARK: Writing a session back into Health
    /// Save a logged session as an HKWorkout so it counts toward the activity rings
    /// and shows up in Fitness, with the GPS track of a live cardio session. Returns
    /// the new workout's UUID so the caller can record it and never write the same
    /// session twice. The caller passes the real start and end when the session was
    /// live, else the end is "now" and the start `end - duration`: back-dating a
    /// guess would put the workout at the wrong hour in Health.
    func save(sport: Sport, start: Date, end: Date, kcal: Int?, distanceKm: Double?, route: [CLLocation],
              completion: @escaping (String?) -> Void) {
        #if canImport(HealthKit)
        Task {
            var samples: [HKSample] = []
            if let kcal, kcal > 0, let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                samples.append(HKQuantitySample(type: t, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(kcal)),
                                                start: start, end: end))
            }
            if let km = distanceKm, km > 0, let id = Self.distanceIdentifier(for: sport),
               let t = HKObjectType.quantityType(forIdentifier: id) {
                samples.append(HKQuantitySample(type: t, quantity: HKQuantity(unit: .meter(), doubleValue: km * 1000),
                                                start: start, end: end))
            }
            let uuid: String?
            do {
                uuid = try await writeWorkout(sport: sport, start: start, end: end, samples: samples,
                                              route: route, device: .local())
            } catch {
                appLog.error("Workout not exported to Health: \(String(describing: error), privacy: .public)")
                uuid = nil
            }
            await MainActor.run { completion(uuid) }
        }
        #else
        completion(nil)
        #endif
    }

    #if canImport(HealthKit)
    /// The app's Sport mapped to the HealthKit activity type we write.
    static func activityType(for s: Sport) -> HKWorkoutActivityType {
        switch s {
        case .strength: return .traditionalStrengthTraining
        case .running:  return .running
        case .cycling:  return .cycling
        case .swimming: return .swimming
        case .walking:  return .walking
        case .other:    return .other
        }
    }

    /// Which distance quantity applies to a sport (nil when distance is meaningless).
    static func distanceIdentifier(for s: Sport) -> HKQuantityTypeIdentifier? {
        switch s {
        case .running, .walking: return .distanceWalkingRunning
        case .cycling:           return .distanceCycling
        case .swimming:          return .distanceSwimming
        default:                 return nil
        }
    }

    /// Reduce one HKWorkout to what the app keeps: core fields and every extra
    /// metric the device wrote (see `measures(of:)`). A workout from the band is
    /// written by this app but is the band's: it is named after the band and
    /// imported like any watch's.
    private func summarize(_ w: HKWorkout, appBundle: String) -> HealthWorkout {
        let src = w.sourceRevision.source.bundleIdentifier
        let band = Self.isBandWorkout(w)
        return HealthWorkout(
            uuid: w.uuid.uuidString,
            date: isoFormatter.string(from: w.startDate),
            sport: Self.sport(for: w.workoutActivityType),
            displayName: Self.displayName(for: w.workoutActivityType),
            measures: Self.measures(of: w),
            fromThisApp: !band && (src == appBundle || src.hasPrefix("com.marco.manzotti.fittracker")),
            sourceName: band ? (w.device?.name ?? "Xiaomi Smart Band") : w.sourceRevision.source.name,
            start: w.startDate, end: w.endDate)
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


    // MARK: What is read, and how
    /// A daily quantity: bucketed by calendar day, summed or averaged.
    private struct DailyStat {
        let field: HealthField
        let category: HealthCategory
        let id: HKQuantityTypeIdentifier
        let unit: HKUnit
        var sum = false
        var scale = 1.0
    }
    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static var dailyStats: [DailyStat] {
        let vo2Unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return [
            DailyStat(field: .steps, category: .steps, id: .stepCount, unit: .count(), sum: true),
            DailyStat(field: .restHR, category: .restHR, id: .restingHeartRate, unit: bpm),
            DailyStat(field: .activeKcal, category: .activeKcal, id: .activeEnergyBurned, unit: .kilocalorie(), sum: true),
            DailyStat(field: .exerciseMin, category: .exerciseMin, id: .appleExerciseTime, unit: .minute(), sum: true),
            // Apple records VO2 max sparsely: a day without a reading carries no value.
            DailyStat(field: .vo2max, category: .vo2max, id: .vo2Max, unit: vo2Unit),
            DailyStat(field: .walkingHR, category: .walkingHR, id: .walkingHeartRateAverage, unit: bpm),
            DailyStat(field: .hrRecovery, category: .hrRecovery, id: .heartRateRecoveryOneMinute, unit: bpm),
            DailyStat(field: .flights, category: .flights, id: .flightsClimbed, unit: .count(), sum: true),
            DailyStat(field: .weight, category: .weight, id: .bodyMass, unit: .gramUnit(with: .kilo)),
            DailyStat(field: .bodyFat, category: .bodyFat, id: .bodyFatPercentage, unit: .percent(), scale: 100),
            DailyStat(field: .daylightMin, category: .daylight, id: .timeInDaylight, unit: .minute(), sum: true)
        ]
    }

    /// A quantity averaged over the night it was measured in. Heart rate, HRV,
    /// SpO2 and breathing count only while asleep; the wrist temperature is one
    /// sample spanning the whole night.
    private struct NightVital {
        let field: HealthField
        let category: HealthCategory
        let id: HKQuantityTypeIdentifier
        let unit: HKUnit
        var scale = 1.0
        var wholeNight = false
    }
    private static let nightVitals = [
        NightVital(field: .sleepHR, category: .sleepHR, id: .heartRate, unit: bpm),
        NightVital(field: .hrvSleep, category: .hrv, id: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)),
        NightVital(field: .spo2, category: .spo2, id: .oxygenSaturation, unit: .percent(), scale: 100),
        NightVital(field: .respRate, category: .respRate, id: .respiratoryRate, unit: bpm),
        NightVital(field: .wristTemp, category: .wristTemp, id: .appleSleepingWristTemperature,
                   unit: .degreeCelsius(), wholeNight: true)
    ]

    /// Run a statistics-collection query bucketed by day, return [yyyy-MM-dd: value].
    private func collect(_ type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions,
                         start: Date, end: Date, cal: Calendar,
                         done: @escaping ([String: Double]?) -> Void) {
        let anchor = cal.startOfDay(for: start)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start,
                                                    end: cal.date(byAdding: .day, value: 1, to: end),
                                                    options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: options, anchorDate: anchor, intervalComponents: interval)
        // Enumerate through the day AFTER `end`: the range behaves as half-open, so
        // passing `end` itself (a day start) can drop that final bucket — which is
        // today's, the one the user checks first.
        let enumEnd = cal.date(byAdding: .day, value: 1, to: end) ?? end
        query.initialResultsHandler = { _, results, error in
            if let error {
                appLog.error("Health query for \(type.identifier, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async { done(nil) }
                return
            }
            var map: [String: Double] = [:]
            results?.enumerateStatistics(from: anchor, to: enumEnd) { stat, _ in
                let qty = options == .cumulativeSum ? stat.sumQuantity() : stat.averageQuantity()
                if let qty { map[isoFormatter.string(from: stat.startDate)] = qty.doubleValue(for: unit) }
            }
            DispatchQueue.main.async { done(map) }
        }
        store.execute(query)
    }

    /// Hours of the day in which the user stood (the Apple Watch stand ring).
    private func countStandHours(start: Date, end: Date, cal: Calendar,
                                 done: @escaping ([String: Double]?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { done([:]); return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: cal.date(byAdding: .day, value: 1, to: end),
                                                    options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error {
                appLog.error("Health stand-hour query failed: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async { done(nil) }
                return
            }
            var map: [String: Double] = [:]
            for s in (samples as? [HKCategorySample]) ?? [] where s.value == HKCategoryValueAppleStandHour.stood.rawValue {
                map[isoFormatter.string(from: s.startDate), default: 0] += 1
            }
            DispatchQueue.main.async { done(map) }
        }
        store.execute(query)
    }

    /// Days of sample queries per request: a year of band heart-rate samples
    /// (hundreds of thousands) is never held in memory at once.
    private static let chunkDays = 30

    /// The nights ending in `[start, end]`: their sleep fields, and the overnight
    /// vitals averaged over each night.
    private func collectNights(start: Date, end: Date, cal: Calendar, categories: Set<String>,
                               done: @escaping (_ byDay: [String: [HealthField: Double]],
                                                _ timelines: [String: [Int]], _ ok: Bool) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { done([:], [:], false); return }
        // The night that ends on `start` began the evening before.
        let from = cal.date(byAdding: .day, value: -1, to: start) ?? start
        let to = cal.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error {
                appLog.error("Health sleep query failed: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async { done([:], [:], false) }
                return
            }
            let sleep = ((samples as? [HKCategorySample]) ?? []).compactMap { s -> SleepSample? in
                Self.stage(s.value).map {
                    SleepSample(start: s.startDate, end: s.endDate, stage: $0, source: s.sourceRevision.source.bundleIdentifier)
                }
            }
            let first = isoFormatter.string(from: start), last = isoFormatter.string(from: end)
            let nights = SleepWindows.nights(sleep, cal: cal).filter { $0.day >= first && $0.day <= last }
            var byDay: [String: [HealthField: Double]] = [:]
            var timelines: [String: [Int]] = [:]
            if categories.contains(HealthCategory.sleep.rawValue) {
                for n in nights {
                    byDay[n.day] = Self.sleepFields(n, cal: cal)
                    timelines[n.day] = Self.timeline(n, cal: cal)
                }
            }
            let vitals = Self.nightVitals.filter { categories.contains($0.category.rawValue) }
            guard !vitals.isEmpty, !nights.isEmpty else {
                DispatchQueue.main.async { done(byDay, timelines, true) }
                return
            }
            let group = DispatchGroup()
            let lock = NSLock()
            var averages: [(field: HealthField, map: [String: Double]?)] = []
            for v in vitals {
                guard let type = HKObjectType.quantityType(forIdentifier: v.id) else { continue }
                group.enter()
                self.average(type, unit: v.unit, over: nights, wholeNight: v.wholeNight, from: from, to: to, cal: cal) { map in
                    lock.lock()
                    averages.append((v.field, map?.mapValues { $0 * v.scale }))
                    lock.unlock()
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                var ok = true
                for (field, map) in averages {
                    guard let map else { ok = false; continue }
                    for (day, value) in map { byDay[day, default: [:]][field] = value }
                }
                done(byDay, timelines, ok)
            }
        }
        store.execute(query)
    }

    /// Minutes on the clock from `midnight` (negative before it): a night that spans
    /// a clock change is an hour longer or shorter than the elapsed time says, and
    /// bedtime "at 23:30" must read 23:30 either way.
    static func clockMinutes(_ date: Date, from midnight: Date, calendar cal: Calendar) -> Double {
        let days = cal.dateComponents([.day], from: midnight, to: cal.startOfDay(for: date)).day ?? 0
        let c = cal.dateComponents([.hour, .minute], from: date)
        return Double(days * 1440 + (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    private static func sleepFields(_ n: SleepNight, cal: Calendar) -> [HealthField: Double] {
        let midnight = cal.startOfDay(for: n.end)
        var f: [HealthField: Double] = [
            .sleepHours: n.asleepHours,
            .inBedHours: n.inBedHours,
            .sleepStartMin: clockMinutes(n.start, from: midnight, calendar: cal),
            .sleepEndMin: clockMinutes(n.end, from: midnight, calendar: cal)
        ]
        if n.hasStages {
            f[.sleepDeepMin] = n.deepMin
            f[.sleepREMMin] = n.remMin
            f[.sleepCoreMin] = n.coreMin
            f[.sleepAwakeMin] = n.awakeMin
        }
        return f
    }

    /// The night as `[start, end, stage code]` triplets in minutes from the wake
    /// day's midnight (negative before it), for the stage chart.
    private static func timeline(_ n: SleepNight, cal: Calendar) -> [Int] {
        let midnight = cal.startOfDay(for: n.end)
        return n.slices.flatMap { s -> [Int] in
            guard let code = s.stage.code else { return [] }
            return [Int(clockMinutes(s.start, from: midnight, calendar: cal)),
                    Int(clockMinutes(s.end, from: midnight, calendar: cal)), code]
        }
    }

    private static func stage(_ value: Int) -> SleepSample.Stage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:             return .inBed
        case .awake:             return .awake
        case .asleepUnspecified: return .asleep
        case .asleepCore:        return .core
        case .asleepDeep:        return .deep
        case .asleepREM:         return .rem
        default:                 return nil
        }
    }

    /// Per-night average of a quantity, read in chunks of `chunkDays`. A sample
    /// counts toward the night its midpoint falls in (while asleep, unless
    /// `wholeNight`). nil when a query failed.
    private func average(_ type: HKQuantityType, unit: HKUnit, over nights: [SleepNight], wholeNight: Bool,
                         from: Date, to: Date, cal: Calendar, done: @escaping ([String: Double]?) -> Void) {
        var sum: [String: Double] = [:], count: [String: Int] = [:]
        func read(from chunkStart: Date) {
            guard chunkStart < to else {
                done(Dictionary(uniqueKeysWithValues: count.map { ($0.key, (sum[$0.key] ?? 0) / Double($0.value)) }))
                return
            }
            let chunkEnd = min(to, cal.date(byAdding: .day, value: Self.chunkDays, to: chunkStart) ?? to)
            let predicate = HKQuery.predicateForSamples(withStart: chunkStart, end: chunkEnd, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    appLog.error("Health \(type.identifier, privacy: .public) query failed: \(String(describing: error), privacy: .public)")
                    done(nil)
                    return
                }
                for s in (samples as? [HKQuantitySample]) ?? [] {
                    let t = s.startDate.addingTimeInterval(s.endDate.timeIntervalSince(s.startDate) / 2)
                    guard let night = SleepWindows.night(at: t, in: nights), wholeNight || night.isAsleep(at: t) else { continue }
                    sum[night.day, default: 0] += s.quantity.doubleValue(for: unit)
                    count[night.day, default: 0] += 1
                }
                read(from: chunkEnd)
            }
            self.store.execute(query)
        }
        read(from: from)
    }
    #endif
}
