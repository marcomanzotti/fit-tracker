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
    func formSeries(days: Int = 90) -> [FormPoint] { memo("form|\(days)") { computeFormSeries(days: days) } }

    private func computeFormSeries(days: Int) -> [FormPoint] {
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
    func recoveryEstimate() -> RecoveryEstimate? { memo("recovery") { computeRecoveryEstimate() } }

    private func computeRecoveryEstimate() -> RecoveryEstimate? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Store.recoveryWindowDays, to: Date()),
              let last = sessions.filter({ $0.date >= isoFormatter.string(from: cutoff) })
                .compactMap({ s in sessionTrimps[s.id].map { (s, $0) } })
                .max(by: { $0.0.date < $1.0.date }) else { return nil }
        let fitness = max(formSeries(days: 1).last?.fitness ?? 0, 20)
        var hours = 10 + 16 * last.1 / fitness
        if let score = readiness().score, score < Store.readinessReadyFrom { hours *= 1.2 }
        hours = min(max(hours, Store.recoveryMinHours), Store.recoveryMaxHours)
        // A session from a device knows when it ended; one logged by hand only has a date.
        let end = last.0.endTime
        let remaining = end.map { max(0, Int((hours - Date().timeIntervalSince($0) / 3600).rounded())) }
        return RecoveryEstimate(sessionDate: last.0.date, load: last.1, hours: Int(hours.rounded()), remaining: remaining)
    }
}

// MARK: Time in heart-rate zones and aerobic decoupling
/// A workout's heart rate in zones, derived from the per-bpm seconds stored on its
/// session, so changing the resting or maximum heart rate re-zones the whole
/// history without asking Health again.
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

/// Seconds at each whole bpm, each reading standing for the time until the next,
/// capped so a dropout is not credited to the last value seen.
func heartRateHistogram(_ hr: [(Date, Double)], end: Date, longestGap: TimeInterval = 120) -> [Int: Int] {
    var out: [Int: Int] = [:]
    for (i, s) in hr.enumerated() where s.1.isFinite && s.1 > 0 && s.1 < 260 {
        let next = i + 1 < hr.count ? hr[i + 1].0 : end
        let seconds = Int(min(max(0, next.timeIntervalSince(s.0)), longestGap).rounded())
        if seconds > 0 { out[Int(s.1.rounded()), default: 0] += seconds }
    }
    return out
}

/// Seconds in each of five zones (`bounds`: six edges in bpm) of a histogram.
func zoneSeconds(_ histogram: [Int: Int], bounds: [Int]) -> [Double] {
    var zones = [Double](repeating: 0, count: 5)
    for (bpm, seconds) in histogram {
        let zone = max(0, min(4, bounds.lastIndex { $0 <= bpm } ?? 0))
        zones[zone] += Double(seconds)
    }
    return zones
}

extension Store {
    private static let intensityDays = 56
    /// How far back the heart rate of linked workouts is read: the sync window.
    private static let heartRateReadDays = 90

    /// Zones and drift of the workouts of the last eight weeks that carry heart rate.
    var workoutIntensity: [WorkoutIntensity] {
        memo("workoutIntensity") {
            let zones = hrZones()
            guard zones.count == 5 else { return [] }
            let bounds = zones.map(\.lower) + [zones[4].upper]
            let from = Calendar.current.date(byAdding: .day, value: -Store.intensityDays, to: Date())
                .map { isoFormatter.string(from: $0) } ?? ""
            return sessions.compactMap { s -> WorkoutIntensity? in
                guard s.date >= from, let h = s.hrHistogram, !h.isEmpty else { return nil }
                let end = s.endTime ?? isoFormatter.date(from: s.date) ?? Date()
                return WorkoutIntensity(date: s.date, end: end, sport: s.sportType.rawValue,
                                        zoneSeconds: zoneSeconds(h, bounds: bounds), decoupling: s.decoupling)
            }.sorted { $0.end < $1.end }
        }
    }

    /// Reads, once per workout, the heart rate of the sessions linked to Health and
    /// keeps it on the session. A sync used to query every workout of the last
    /// eight weeks again; now only the new ones are asked for.
    func readWorkoutHeartRate(completion: @escaping () -> Void = {}) {
        let from = Calendar.current.date(byAdding: .day, value: -Store.heartRateReadDays, to: Date())
            .map { isoFormatter.string(from: $0) } ?? ""
        let pending = sessions.filter { $0.hrHistogram == nil && $0.date >= from }.compactMap { s in
            s.healthUUID.map { (s.id, $0) }
        }
        guard !pending.isEmpty, !readingWorkoutHeartRate else { completion(); return }
        readingWorkoutHeartRate = true
        Task {
            var read: [UUID: WorkoutHeartRate] = [:]
            for (id, uuid) in pending {
                read[id] = await HealthKitManager.shared.heartRate(ofWorkout: uuid)
            }
            let found = read
            await MainActor.run {
                var list = self.sessions
                for i in list.indices {
                    guard let hr = found[list[i].id] else { continue }
                    list[i].hrHistogram = hr.histogram
                    list[i].decoupling = hr.decoupling
                }
                if list != self.sessions { self.sessions = list }
                self.readingWorkoutHeartRate = false
                completion()
            }
        }
    }

    /// Monday-based weeks, oldest first, only those with workout heart rate.
    func intensityWeeks() -> [IntensityWeek] { memo("intensityWeeks") { computeIntensityWeeks() } }

    private func computeIntensityWeeks() -> [IntensityWeek] {
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

/// What one workout's heart rate tells, read from Health once.
struct WorkoutHeartRate {
    var histogram: [Int: Int]   // empty when the workout has no heart rate
    var decoupling: Double?
}

#if canImport(HealthKit)
extension HealthKitManager {
    private static let longestSampleGap: TimeInterval = 120
    private static let decouplingMinSeconds: TimeInterval = 30 * 60

    /// The heart rate of one workout as per-bpm seconds, and for a run of 30 min
    /// or more its aerobic decoupling. nil when Health could not be read (it is
    /// asked again next time); an empty histogram when there is no heart rate.
    func heartRate(ofWorkout uuid: String) async -> WorkoutHeartRate? {
        guard isAvailable, let id = UUID(uuidString: uuid), let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        do {
            let found = try await HKSampleQueryDescriptor(
                predicates: [.workout(HKQuery.predicateForObject(with: id))], sortDescriptors: [], limit: 1
            ).result(for: store)
            guard let w = found.first else { return WorkoutHeartRate(histogram: [:]) }
            let window = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
            let all = try await HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: hrType, predicate: window)], sortDescriptors: [SortDescriptor(\.startDate)]
            ).result(for: store)
            // The workout's own source when it wrote heart rate: a second device
            // worn at the same time must not interleave its readings.
            let own = all.filter { $0.sourceRevision.source == w.sourceRevision.source }
            let bpm = HKUnit.count().unitDivided(by: .minute())
            let hr = (own.count >= 2 ? own : all).map { ($0.startDate, $0.quantity.doubleValue(for: bpm)) }
            guard hr.count >= 2 else { return WorkoutHeartRate(histogram: [:]) }
            let histogram = heartRateHistogram(hr, end: w.endDate, longestGap: Self.longestSampleGap)
            guard w.workoutActivityType == .running, w.duration >= Self.decouplingMinSeconds else {
                return WorkoutHeartRate(histogram: histogram)
            }
            return WorkoutHeartRate(histogram: histogram, decoupling: try await decoupling(of: w, heartRate: hr))
        } catch {
            appLog.error("Workout heart rate unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Friel's aerobic decoupling: efficiency (distance per heartbeat) of the
    /// second half against the first. Under 5 % the aerobic base held for the
    /// whole run.
    private func decoupling(of w: HKWorkout, heartRate: [(Date, Double)]) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let window = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
        let samples = try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: window)], sortDescriptors: []
        ).result(for: store)
        let mid = w.startDate.addingTimeInterval(w.duration / 2)
        var meters = [0.0, 0.0]
        for s in samples { meters[s.startDate < mid ? 0 : 1] += s.quantity.doubleValue(for: .meter()) }
        func meanHR(firstHalf: Bool) -> Double? {
            let v = heartRate.filter { ($0.0 < mid) == firstHalf }.map(\.1)
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        guard meters[0] > 0, meters[1] > 0,
              let hr1 = meanHR(firstHalf: true), let hr2 = meanHR(firstHalf: false) else { return nil }
        let ef1 = meters[0] / hr1, ef2 = meters[1] / hr2   // equal halves: time cancels out
        return (ef1 - ef2) / ef1 * 100
    }
}
#endif
