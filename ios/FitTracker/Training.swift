import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Training science beyond the weekly load
// Fitness / fatigue / form, the recovery a session asks for, time in heart-rate
// zones and aerobic decoupling. All of it comes from TRIMP (Science.swift) and,
// for zones and decoupling, from the heart rate Health recorded during workouts.

// MARK: Fitness, fatigue, form (Banister impulse-response, the "PMC")
struct FormPoint: Identifiable {
    let day: Date
    let fitness: Double     // chronic load, 42-day time constant (CTL)
    let fatigue: Double     // acute load, 7-day time constant (ATL)
    let form: Double        // yesterday's fitness − fatigue (TSB)
    var id: Date { day }
}

extension Store {
    static let fitnessDays = 42.0
    static let fatigueDays = 7.0

    /// One point per day for the last `days`. The averages start three fitness
    /// constants earlier so the first day shown is not a cold start from zero.
    /// Form uses the day before: a session done today has not made you fresher.
    func formSeries(days: Int = 90) -> [FormPoint] {
        let warmUp = Int(Store.fitnessDays) * 3
        var fitness = 0.0, fatigue = 0.0
        var out: [FormPoint] = []
        for (i, p) in dailyLoadSeries(days: days + warmUp).enumerated() {
            let form = fitness - fatigue
            fitness += (p.load - fitness) / Store.fitnessDays
            fatigue += (p.load - fatigue) / Store.fatigueDays
            if i >= warmUp { out.append(FormPoint(day: p.day, fitness: fitness, fatigue: fatigue, form: form)) }
        }
        return out
    }
}

// MARK: Recovery after a session
struct RecoveryEstimate {
    let sessionDate: String
    let load: Double
    let hours: Int          // total estimated recovery
    let remaining: Int?     // hours left, when the session's end is known
}

extension Store {
    private static let recoveryMinHours = 8.0
    private static let recoveryMaxHours = 72.0
    private static let recoveryWindowDays = 3

    /// How long the last session with heart rate asks for. A session as heavy as
    /// an average training day (load ≈ fitness) needs about a day; twice that
    /// about 40 h. Fitness shortens it, a low readiness lengthens it by a fifth.
    /// A rule of thumb in the spirit of Firstbeat's recovery time, shown as an
    /// estimate.
    func recoveryEstimate() -> RecoveryEstimate? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Store.recoveryWindowDays, to: Date()),
              let last = sessions.filter({ $0.date >= isoFormatter.string(from: cutoff) })
                .compactMap({ s in trimp(s).map { (s, $0) } })
                .max(by: { $0.0.date < $1.0.date }) else { return nil }
        let fitness = max(formSeries(days: 1).last?.fitness ?? 0, 20)
        var hours = 10 + 16 * last.1 / fitness
        if let score = readiness().score, score < Store.readinessReadyFrom { hours *= 1.2 }
        hours = min(max(hours, Store.recoveryMinHours), Store.recoveryMaxHours)
        // Health knows when a workout ended; a session logged by hand only has a date.
        let end = workoutIntensity.filter { $0.date == last.0.date }.map(\.end).max()
        let remaining = end.map { max(0, Int((hours - Date().timeIntervalSince($0) / 3600).rounded())) }
        return RecoveryEstimate(sessionDate: last.0.date, load: last.1, hours: Int(hours.rounded()), remaining: remaining)
    }
}

// MARK: Time in heart-rate zones and aerobic decoupling
struct WorkoutIntensity {
    let date: String
    let end: Date
    let sport: String
    let zoneSeconds: [Double]   // Z1…Z5 (below Z1 counts as Z1)
    let decoupling: Double?     // %, runs of 30 min or more with distance
}

struct IntensityWeek: Identifiable {
    let start: Date
    let zoneSeconds: [Double]
    var id: Date { start }
    var total: Double { zoneSeconds.reduce(0, +) }
    /// Share of easy time (Z1–Z2) and of hard time (Z4–Z5), %.
    var easyShare: Double { total > 0 ? (zoneSeconds[0] + zoneSeconds[1]) / total * 100 : 0 }
    var hardShare: Double { total > 0 ? (zoneSeconds[3] + zoneSeconds[4]) / total * 100 : 0 }
}

extension Store {
    private static let intensityDays = 56

    /// Reads the recent workouts from Health and keeps their zones and drift. Two
    /// syncs close together can answer out of order: only the latest request lands.
    func refreshWorkoutIntensity() {
        let zones = hrZones()
        guard zones.count == 5 else { return }
        let bounds = zones.map(\.lower) + [zones[4].upper]
        intensityRequest += 1
        let request = intensityRequest
        HealthKitManager.shared.fetchIntensity(days: Store.intensityDays, bounds: bounds) { [weak self] result in
            guard let self, request == self.intensityRequest else { return }
            self.workoutIntensity = result
        }
    }

    /// Monday-based weeks, oldest first, only those with workout heart rate.
    func intensityWeeks() -> [IntensityWeek] {
        var byWeek: [Date: [Double]] = [:]
        for w in workoutIntensity {
            guard let d = isoFormatter.date(from: w.date) else { continue }
            let start = weekStart(now: d)
            byWeek[start] = zip(byWeek[start] ?? [0, 0, 0, 0, 0], w.zoneSeconds).map(+)
        }
        return byWeek.keys.sorted().map { IntensityWeek(start: $0, zoneSeconds: byWeek[$0] ?? []) }
            .filter { $0.total > 0 }
    }

    /// The latest run long enough to measure aerobic decoupling.
    var lastDecoupling: (date: String, value: Double)? {
        workoutIntensity.filter { $0.decoupling != nil }.max { $0.end < $1.end }
            .flatMap { w in w.decoupling.map { (w.date, $0) } }
    }
}

#if canImport(HealthKit)
extension HealthKitManager {
    private static let longestSampleGap: TimeInterval = 120
    private static let decouplingMinSeconds: TimeInterval = 30 * 60

    /// Zones (by the `bounds` in bpm, six edges for five zones) and, for runs,
    /// aerobic decoupling of every workout of the last `days`, from any source.
    func fetchIntensity(days: Int, bounds: [Int], completion: @escaping ([WorkoutIntensity]) -> Void) {
        guard isAvailable, let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            completion([]); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            let group = DispatchGroup()
            let lock = NSLock()
            var out: [WorkoutIntensity] = []
            for w in workouts {
                group.enter()
                self.intensity(of: w, bounds: bounds) { result in
                    if let result { lock.lock(); out.append(result); lock.unlock() }
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion(out.sorted { $0.end < $1.end }) }
        }
        store.execute(query)
    }

    private func intensity(of w: HKWorkout, bounds: [Int], done: @escaping (WorkoutIntensity?) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { done(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: sort) { _, samples, _ in
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let hr = ((samples as? [HKQuantitySample]) ?? []).map { ($0.startDate, $0.quantity.doubleValue(for: bpmUnit)) }
            guard hr.count >= 2 else { done(nil); return }
            let zones = hrZoneSeconds(hr, end: w.endDate, bounds: bounds, longestGap: Self.longestSampleGap)
            let date = isoFormatter.string(from: w.startDate)
            let sport = Self.sportName(w.workoutActivityType)
            guard sport == "running", w.duration >= Self.decouplingMinSeconds else {
                done(WorkoutIntensity(date: date, end: w.endDate, sport: sport, zoneSeconds: zones, decoupling: nil))
                return
            }
            self.decoupling(of: w, heartRate: hr) { value in
                done(WorkoutIntensity(date: date, end: w.endDate, sport: sport, zoneSeconds: zones, decoupling: value))
            }
        }
        store.execute(query)
    }

    private static func sportName(_ t: HKWorkoutActivityType) -> String {
        switch t {
        case .running:  return "running"
        case .cycling:  return "cycling"
        case .walking, .hiking: return "walking"
        case .swimming: return "swimming"
        default:        return "other"
        }
    }

    /// Friel's aerobic decoupling: efficiency (distance per heartbeat) of the
    /// second half against the first. Under 5 % the aerobic base held for the
    /// whole run.
    private func decoupling(of w: HKWorkout, heartRate: [(Date, Double)], done: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { done(nil); return }
        let predicate = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, _ in
            let mid = w.startDate.addingTimeInterval(w.duration / 2)
            var meters = [0.0, 0.0]
            for s in (samples as? [HKQuantitySample]) ?? [] {
                meters[s.startDate < mid ? 0 : 1] += s.quantity.doubleValue(for: .meter())
            }
            func meanHR(firstHalf: Bool) -> Double? {
                let v = heartRate.filter { ($0.0 < mid) == firstHalf }.map(\.1)
                return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
            }
            guard meters[0] > 0, meters[1] > 0,
                  let hr1 = meanHR(firstHalf: true), let hr2 = meanHR(firstHalf: false) else { done(nil); return }
            let ef1 = meters[0] / hr1, ef2 = meters[1] / hr2   // equal halves: time cancels out
            done((ef1 - ef2) / ef1 * 100)
        }
        store.execute(query)
    }
}
#endif
