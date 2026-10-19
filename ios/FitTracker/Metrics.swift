import SwiftUI

// MARK: - Phase 3 derived metrics
// Insight metrics computed from data the app already stores, each with a clear
// "what it's for" so the UI can show an explanatory "i". Strength-side metrics
// (e1RM, muscle volume) inform "should I add load?"; health-side metrics (VO2max
// estimate, HR zones, resting-HR / HRV trend) read recovery and fitness.

// MARK: e1RM (estimated one-rep max, Epley)
extension Store {
    /// Estimated 1RM for a single set via the Epley formula: w · (1 + reps/30).
    /// Returns nil for bodyweight-only sets (no external load) or empty input.
    /// Reps are capped at 12: the linear Epley model drifts high on long sets, so
    /// beyond ~12 reps the estimate is more noise than signal.
    func e1RM(weight: Double, reps: Double) -> Double? {
        guard weight > 0, reps > 0 else { return nil }
        let r = min(reps, 12)
        return weight * (1 + r / 30)
    }

    /// Best estimated 1RM ever logged for an exercise, across every set of every
    /// session (so a heavy triple can out-rank a max single). Bodyweight exercises
    /// return nil — there's no barbell load to model.
    func bestE1RM(_ name: String) -> Double? { memo("e1RM|\(name)") { computeBestE1RM(name) } }

    private func computeBestE1RM(_ name: String) -> Double? {
        if isBodyweightExercise(name) { return nil }
        var best: Double? = nil
        for s in sessions {
            for e in s.exercises where e.name == name {
                for set in e.sets {
                    if let v = e1RM(weight: pf(set.weight), reps: pf(set.reps)) {
                        best = max(best ?? 0, v)
                    }
                }
            }
        }
        return best.map { ($0 * 10).rounded() / 10 }
    }

}

// MARK: - Fitness age and relative strength
extension Store {
    /// The age whose typical VO₂max (the fair / good boundary of the Cooper
    /// norms for the user's sex) equals the user's: a VO₂max of 46 at 40 reads
    /// like an average 28-year-old. Interpolated between decades, 20–80.
    func fitnessAge() -> Int? {
        guard let vo2 = vo2maxEstimate()?.value else { return nil }
        let ages: [Double] = [25, 35, 45, 55, 65]
        let typical = ages.map { vo2Thresholds(age: Int($0))[2] }
        if vo2 >= typical[0] { return max(20, Int((25 - (vo2 - typical[0]) / (typical[0] - typical[1]) * 10).rounded())) }
        for i in 1..<ages.count where vo2 >= typical[i] {
            let f = (typical[i - 1] - vo2) / (typical[i - 1] - typical[i])
            return Int((ages[i - 1] + f * 10).rounded())
        }
        let slope = typical[3] - typical[4]
        return min(80, Int((65 + (typical[4] - vo2) / max(slope, 1) * 10).rounded()))
    }

    enum Lift: String, CaseIterable {
        case bench, squat, deadlift, press
        /// Words that identify the lift in an exercise name, in English or Italian.
        var keywords: [String] {
            switch self {
            case .bench:    return ["bench press", "panca piana", "distensioni su panca"]
            case .squat:    return ["back squat", "squat con bilanciere", "barbell squat", "squat"]
            case .deadlift: return ["deadlift", "stacco"]
            case .press:    return ["overhead press", "military press", "lento avanti", "shoulder press"]
            }
        }
        /// Estimated 1RM ÷ body weight to reach beginner, novice, intermediate,
        /// advanced, elite (adult lifters' standards, as on Strength Level).
        func standards(female: Bool) -> [Double] {
            switch (self, female) {
            case (.bench, false):    return [0.5, 0.75, 1.25, 1.75, 2.0]
            case (.bench, true):     return [0.25, 0.5, 0.75, 1.0, 1.5]
            case (.squat, false):    return [0.75, 1.25, 1.5, 2.25, 2.75]
            case (.squat, true):     return [0.5, 0.75, 1.25, 1.5, 2.0]
            case (.deadlift, false): return [1.0, 1.5, 2.0, 2.5, 3.0]
            case (.deadlift, true):  return [0.5, 1.0, 1.25, 1.75, 2.5]
            case (.press, false):    return [0.35, 0.55, 0.8, 1.05, 1.35]
            case (.press, true):     return [0.2, 0.35, 0.5, 0.75, 1.0]
            }
        }
    }

    struct LiftStrength: Identifiable {
        let lift: Lift
        let exercise: String
        let e1RM: Double
        let ratio: Double       // e1RM ÷ body weight
        var id: String { lift.rawValue }
    }

    /// The best estimated 1RM of each main lift the user has logged, as a
    /// multiple of the current body weight. Machines and dumbbells don't count.
    func relativeStrength() -> [LiftStrength] {
        let bw = lastWeight
        guard bw > 0 else { return [] }
        let names = Set(sessions.flatMap { $0.exercises.map(\.name) })
        return Lift.allCases.compactMap { lift in
            let matches = names.filter { n in
                let l = n.lowercased()
                return lift.keywords.contains { l.contains($0) }
                    && !["dumbbell", "manubri", "machine", "macchina", "smith", "incline", "inclinata"].contains { l.contains($0) }
            }
            guard let best = matches.compactMap({ n in bestE1RM(n).map { (n, $0) } }).max(by: { $0.1 < $1.1 }) else { return nil }
            return LiftStrength(lift: lift, exercise: best.0, e1RM: best.1, ratio: best.1 / bw)
        }
    }

    /// Scale for a lift's ratio: untrained … elite.
    func strengthScale(_ lift: Lift) -> InfoScale {
        let s = lift.standards(female: prefs.sex_ == "f")
        return InfoScale(from: 0, bands: [InfoBand(upTo: s[0], key: "untrained", tone: .bad),
                                          InfoBand(upTo: s[1], key: "beginner", tone: .fair),
                                          InfoBand(upTo: s[2], key: "novice", tone: .good),
                                          InfoBand(upTo: s[3], key: "intermediate", tone: .good),
                                          InfoBand(upTo: s[4], key: "advanced", tone: .great),
                                          InfoBand(upTo: s[4] * 1.25, key: "elite", tone: .great)],
                         unit: "×", decimals: 2)
    }
}

// MARK: - FFMI (fat-free mass index)
// BMI counts every kilo the same, so a lean, muscular person reads "overweight".
// FFMI measures only the lean mass against height, which is what strength training
// actually moves — it's the honest companion to body fat %.
extension Store {
    struct FFMIResult {
        var raw: Double          // fat-free mass (kg) / height² (m)
        var normalized: Double   // height-adjusted, comparable across statures
        var lean: Double         // fat-free mass in kg
    }

    /// FFMI for a given weight and body fat, defaulting to the current ones. nil
    /// without a body-fat figure — the whole point is separating lean mass from fat,
    /// which needs that split. Normalization (Kouri et al.) adds 6.1 × (1.80 −
    /// height) so a 1.65 m and a 1.95 m lifter can be compared on the same scale.
    func ffmi(weight: Double? = nil, bodyFat: Double? = nil) -> FFMIResult? {
        let h = prefs.height
        let lean: Double?
        if let w = weight, let bf = bodyFat, w > 0, bf > 0, bf < 60 {
            lean = w * (1 - bf / 100)
        } else {
            lean = fatFreeMass()
        }
        guard h > 1.0, h < 2.5, let lean, lean > 0 else { return nil }
        let raw = lean / (h * h)
        let norm = raw + 6.1 * (1.80 - h)
        return FFMIResult(raw: (raw * 10).rounded() / 10,
                          normalized: (norm * 10).rounded() / 10,
                          lean: (lean * 10).rounded() / 10)
    }

    /// Body-fat measurements, oldest first: body records (typed or Navy) and the
    /// smart-scale readings Health brings.
    private var bodyFatPoints: [(date: String, value: Double)] {
        memo("bodyFatPoints") {
            var byDate: [String: Double] = [:]
            for e in daily { if let v = e.bodyFat, v > 0, v < 60 { byDate[e.date] = v } }
            for b in body {
                if let v = b.bfManual ?? bfNavy(waist: b.waist, neck: b.neck, hip: b.hips), v > 0, v < 60 { byDate[b.date] = v }
            }
            return byDate.sorted { $0.key < $1.key }.map { (date: $0.key, value: $0.value) }
        }
    }

    /// Body fat on a day: the measurement of that day, or a line between the two
    /// around it. nil outside the measured period — the lean mass of a day with no
    /// measurement near it would only be the weight chart again.
    func bodyFat(on date: String) -> Double? {
        let points = bodyFatPoints
        guard let next = points.firstIndex(where: { $0.date >= date }) else { return nil }
        if points[next].date == date { return points[next].value }
        guard next > 0 else { return nil }
        let a = points[next - 1], b = points[next]
        let span = chartDay(b.date).timeIntervalSince(chartDay(a.date))
        guard span > 0 else { return nil }
        let t = chartDay(date).timeIntervalSince(chartDay(a.date)) / span
        return a.value + (b.value - a.value) * t
    }

    /// Normalised FFMI for a past day, for the trend chart: that day's weight with
    /// that day's body fat. Same scale as the card and the "i" sheet.
    func ffmiTrend(on date: String, weight: Double) -> Double? {
        guard weight > 0, let bf = bodyFat(on: date) else { return nil }
        return ffmi(weight: weight, bodyFat: bf)?.normalized
    }
}

// MARK: - Barbell plate maths + warm-up ramp
extension Store {
    struct PlateLoad {
        var plates: [Double]     // plates for ONE side, heaviest first
        var achieved: Double     // total bar weight these plates actually make
        var exact: Bool          // false when the gym's plates can't hit the target
    }

    /// Which plates to hang on each side for a target bar weight. Greedy from the
    /// heaviest denomination, which is optimal for the doubling-style plate sets
    /// every gym uses. `exact` is false when the target isn't reachable, so the UI
    /// can name the closest weight instead of silently loading something else.
    func plateBreakdown(target: Double, bar: Double? = nil, available: [Double]? = nil) -> PlateLoad? {
        let barKg = bar ?? prefs.bar
        let denoms = (available ?? prefs.plateSet).sorted(by: >)
        guard target > 0, !denoms.isEmpty else { return nil }
        guard target >= barKg else {
            // Below bar weight there is nothing to load — a dumbbell or a machine.
            return PlateLoad(plates: [], achieved: barKg, exact: abs(target - barKg) < 0.01)
        }
        var perSide = (target - barKg) / 2
        var out: [Double] = []
        for d in denoms {
            while perSide >= d - 0.001 {
                out.append(d)
                perSide -= d
            }
        }
        let achieved = barKg + out.reduce(0, +) * 2
        return PlateLoad(plates: out, achieved: (achieved * 100).rounded() / 100,
                         exact: abs(achieved - target) < 0.01)
    }

    struct WarmupStep: Identifiable {
        var pct: Double
        var reps: Int
        var weight: Double
        var id: Double { pct }
    }

    /// A standard ramp to the working weight: enough to groove the movement and wake
    /// the nervous system without spending the session's energy. Each step is rounded
    /// down to something the available plates can actually make, and steps that land
    /// at or below the empty bar are dropped.
    func warmupRamp(working: Double) -> [WarmupStep] {
        guard working > prefs.bar else { return [] }
        let plan: [(Double, Int)] = [(0.4, 5), (0.6, 3), (0.8, 1)]
        return plan.compactMap { pct, reps in
            let raw = working * pct
            guard raw > prefs.bar else { return nil }
            let w = plateBreakdown(target: raw)?.achieved ?? raw
            guard w > prefs.bar else { return nil }
            return WarmupStep(pct: pct, reps: reps, weight: w)
        }
    }
}

// MARK: - Weekly volume per muscle group (sets/week)
extension Store {
    struct MuscleVolume: Identifiable {
        var group: MuscleGroup
        var sets: Double         // working sets this week; secondary muscles count half
        var target: Int          // weekly working-set target for this group
        var id: String { group.rawValue }

        /// Where this week's volume sits against the target: "low" below the range,
        /// "ok" inside it, "high" above. The range is target ± half, i.e. the usual
        /// 10-20 sets/week band around a target of ~15.
        var status: String {
            if sets < Double(range.low) { return "low" }
            if sets > Double(range.high) { return "high" }
            return "ok"
        }
        var range: (low: Int, high: Int) {
            (Int((Double(target) * 0.67).rounded()), Int((Double(target) * 1.33).rounded()))
        }
    }

    /// Weekly working-set target for a muscle group. The literature's hypertrophy
    /// band is ~10-20 sets/week for the big movers; small groups (arms, core) get
    /// plenty of indirect work, so their direct target sits lower. The user can
    /// override any of them.
    func volumeTarget(_ g: MuscleGroup) -> Int {
        if let v = prefs.volumeTargets?[g.rawValue], v > 0 { return v }
        switch g {
        case .chest, .back, .legs, .shoulders: return 15
        case .arms, .core:                     return 10
        case .fullbody:                        return 12
        case .cardio, .other:                  return 0     // not a hypertrophy target
        }
    }

    /// Working sets per muscle group in a Monday-based week (offset 0 = current).
    /// A "working set" is a logged set carrying reps or a hold; each exercise's
    /// muscle group comes from the library/plan classification. This is the
    /// standard hypertrophy dashboard ("am I hitting ~10-20 sets/muscle/week?").
    func weeklyMuscleVolume(offset: Int = 0) -> [MuscleVolume] {
        memo("muscleVolume|\(offset)") { computeMuscleVolume(offset: offset) }
    }

    private func computeMuscleVolume(offset: Int) -> [MuscleVolume] {
        let from = isoFormatter.string(from: weekStart(offset: offset))
        let to = isoFormatter.string(from: weekStart(offset: offset - 1))
        var counts: [String: Double] = [:]
        for s in sessions {
            guard s.date >= from, s.date < to else { continue }
            for e in s.exercises {
                let working = Double(e.sets.filter { $0.filled }.count)
                guard working > 0 else { continue }
                let g = exerciseCategory(e.name)
                counts[g, default: 0] += working
                // A press also works the arms and shoulders: half a set each.
                if let primary = MuscleGroup(rawValue: g) {
                    for other in Store.secondaryGroups(of: e.name, primary: primary) {
                        counts[other.rawValue, default: 0] += working * Store.secondaryWeight
                    }
                }
            }
        }
        return MuscleGroup.allCases.compactMap { g in
            let n = counts[g.rawValue] ?? 0
            return n > 0 ? MuscleVolume(group: g, sets: n, target: volumeTarget(g)) : nil
        }
    }

    /// Whether the week's numbers say to back off. Deloading is warranted when the
    /// form has dropped into overreaching (below −30 % of fitness) AND training has
    /// been monotonous — the classic Foster combination that precedes overreaching.
    /// False unless the load data is trustworthy: a deload suggestion off two
    /// logged sessions would be noise. The single source for the deload warning.
    func deloadAdvice() -> Bool {
        guard loadDataStatus().reliable, let form = formPercent(),
              form < Store.overreachingBelowFormPercent,
              let mono = weekLoad(offset: 0).monotony else { return false }
        return mono > 2.0
    }
}

// MARK: - The week in numbers
/// One Monday–Sunday week: what was trained, how much, how the nights went, where
/// the weight moved and which records fell. Shown in Stats and announced on Monday.
struct WeeklySummary {
    let start: Date
    let sessions: Int
    let volume: Double
    let trimp: Double
    let sleepHours: Double?
    /// Average weight of the week against the week before; nil without both.
    let weightChange: Double?
    let records: Int
    var isEmpty: Bool { sessions == 0 && sleepHours == nil && weightChange == nil }
}

extension Store {
    func weeklySummary(offset: Int = 1) -> WeeklySummary { memo("weeklySummary|\(offset)") { computeWeeklySummary(offset) } }

    private func computeWeeklySummary(_ offset: Int) -> WeeklySummary {
        let start = weekStart(offset: offset)
        func range(_ o: Int) -> ClosedRange<String> {
            isoFormatter.string(from: weekStart(offset: o))...isoFormatter.string(from: weekStart(offset: o - 1).addingTimeInterval(-1))
        }
        let week = range(offset), before = range(offset + 1)
        let done = sessions.filter { week.contains($0.date) }
        let trimps = sessionTrimps
        let days = sortedDaily.filter { week.contains($0.date) }
        let weightNow = average(days.compactMap(\.weight))
        let weightBefore = average(sortedDaily.filter { before.contains($0.date) }.compactMap(\.weight))
        return WeeklySummary(
            start: start, sessions: done.count,
            volume: done.reduce(0) { $0 + $1.volume },
            trimp: done.reduce(0) { $0 + (trimps[$1.id] ?? 0) },
            sleepHours: average(days.compactMap(\.sleepHours).filter { $0 > 0 }),
            weightChange: zip2(weightNow, weightBefore).map { (($0 - $1) * 10).rounded() / 10 },
            records: prTimeline(limit: 500).filter { week.contains($0.date) && $0.delta != nil }.count)
    }

    private func zip2(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}

// MARK: - Personal-record timeline
extension Store {
    /// One moment a record was set. `delta` is the improvement over the previous
    /// best (nil for the first one, which isn't an improvement over anything).
    struct PREvent: Identifiable {
        var id = UUID()
        var date: String
        var exercise: String
        var kind: String       // "weight" | "e1rm" | "hold"
        var value: Double
        var delta: Double?
        var unit: String { kind == "hold" ? "s" : "kg" }
        var labelKey: String {
            switch kind {
            case "e1rm": return "st.pr_e1rm"
            case "hold": return "st.pr_hold"
            default:     return "st.pr_weight"
            }
        }
    }

    /// Every record-setting moment, newest first. Walks the sessions in order and
    /// emits an event whenever an exercise's top weight, best estimated 1RM or
    /// longest hold beats its own previous best — so the list is the history of
    /// actually getting stronger, not a snapshot of current maxima.
    func prTimeline(limit: Int = 60) -> [PREvent] {
        var bestWeight: [String: Double] = [:]
        var bestE1RM: [String: Double] = [:]
        var bestHold: [String: Double] = [:]
        var out: [PREvent] = []

        for s in sessions.sorted(by: { $0.date < $1.date }) {
            for e in s.exercises {
                let name = e.name
                switch e.exKind {
                case .timed:
                    let hold = e.maxSeconds
                    if hold > 0, hold > (bestHold[name] ?? 0) {
                        let prev = bestHold[name]
                        out.append(PREvent(date: s.date, exercise: name, kind: "hold",
                                           value: hold, delta: prev.map { hold - $0 }))
                        bestHold[name] = hold
                    }
                case .reps:
                    let w = e.maxWeight
                    if w > 0, w > (bestWeight[name] ?? 0) {
                        let prev = bestWeight[name]
                        out.append(PREvent(date: s.date, exercise: name, kind: "weight",
                                           value: w, delta: prev.map { w - $0 }))
                        bestWeight[name] = w
                    }
                    // Best single-set e1RM in this session: a heavy triple can be a
                    // bigger record than a lighter single, which top weight misses.
                    let e1 = e.sets.compactMap { e1RM(weight: pf($0.weight), reps: pf($0.reps)) }.max() ?? 0
                    if e1 > 0, e1 > (bestE1RM[name] ?? 0) + 0.05 {
                        let prev = bestE1RM[name]
                        out.append(PREvent(date: s.date, exercise: name, kind: "e1rm",
                                           value: (e1 * 10).rounded() / 10,
                                           delta: prev.map { ((e1 - $0) * 10).rounded() / 10 }))
                        bestE1RM[name] = e1
                    }
                case .interval:
                    break   // rounds are a prescription, not a record
                }
            }
        }
        return Array(out.reversed().prefix(limit))
    }
}

// MARK: - VO2max estimate from running + HR zones
extension Store {
    /// Latest VO2max: Apple Health's value wins (it's measured); otherwise estimate
    /// from the best recent run using the Daniels/Gilbert velocity model via a
    /// HR-fraction proxy. Returns (value, estimated) so the UI can badge an estimate.
    func vo2maxEstimate() -> (value: Double, estimated: Bool)? { memo("vo2max") { computeVO2max() } }

    private func computeVO2max() -> (value: Double, estimated: Bool)? {
        if let v = latestVO2, v > 0 { return (v, false) }
        // Estimate from the most intense recent run with both distance and avg HR.
        let runs = sessions
            .filter { $0.sportType == .running }
            .sorted { $0.date > $1.date }
            .prefix(20)
        var estimates: [Double] = []
        for r in runs {
            guard let mins = r.durationMinutesD, mins >= Store.vo2MinRunMinutes,
                  let km = r.distanceKm, km > 0,
                  let hrr = hrReserve(r.avgHR, session: r), hrr >= Store.vo2MinHRR else { continue }
            // VO2 at this pace (ACSM running equation, v in m/min): 0.2·v + 3.5.
            let vo2AtPace = 0.2 * (km * 1000 / mins) + 3.5
            // %HRR tracks %VO2 *reserve* (Swain), so only the part above rest scales:
            // VO2max = 3.5 + (VO2 − 3.5) / %HRR.
            estimates.append(3.5 + (vo2AtPace - 3.5) / hrr)
        }
        // Median of the three best runs: one GPS glitch or a downhill run can't
        // set the number on its own.
        let top = estimates.sorted(by: >).prefix(3)
        guard !top.isEmpty else { return nil }
        let median = top[top.index(top.startIndex, offsetBy: top.count / 2)]
        return ((median * 10).rounded() / 10, true)
    }

    private static let vo2MinRunMinutes = 10.0
    private static let vo2MinHRR = 0.6

    /// Five heart-rate training zones (% of HR reserve, Karvonen) with their bpm
    /// bounds for the user's profile. Zone 1 easy … Zone 5 max.
    struct HRZone: Identifiable { var index: Int; var lower: Int; var upper: Int; var id: Int { index } }
    func hrZones() -> [HRZone] { memo("hrZones") { computeHRZones() } }

    private func computeHRZones() -> [HRZone] {
        let rest = currentRestingHR()
        let mx = Double(prefs.estMaxHR)
        guard mx > rest else { return [] }
        let bounds = [0.50, 0.60, 0.70, 0.80, 0.90, 1.00]
        func bpm(_ frac: Double) -> Int { Int((rest + frac * (mx - rest)).rounded()) }
        return (0..<5).map { i in HRZone(index: i + 1, lower: bpm(bounds[i]), upper: bpm(bounds[i + 1])) }
    }

}

// MARK: - Resting HR / HRV trend (recovery & fitness direction)
extension Store {
    struct VitalTrend {
        var current: Double?         // smoothed latest value
        var deltaPerWeek: Double?    // signed slope (units/week)
        var points: Int
        /// "improving" | "declining" | "stable" | "none". Direction is metric-aware:
        /// for resting HR lower is better, for HRV higher is better.
        var status: String
    }

    /// Linear-regression trend of a daily vital over the last `days`. `higherIsBetter`
    /// flips the good/bad reading (HRV up = good; resting HR down = good).
    private func vitalTrend(_ value: @escaping (DailyEntry) -> Double?, days: Int, higherIsBetter: Bool) -> VitalTrend {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
        let pts = sortedDaily.compactMap { e -> (Double, Double)? in
            guard let v = value(e), v > 0, let d = isoFormatter.date(from: e.date), d >= cutoff else { return nil }
            return (d.timeIntervalSince(cutoff) / 86400, v)
        }
        guard pts.count >= 4 else { return VitalTrend(current: pts.last?.1, deltaPerWeek: nil, points: pts.count, status: "none") }
        guard let fit = linearFit(pts) else {
            return VitalTrend(current: meanAndSD(pts.map(\.1))?.mean, deltaPerWeek: nil, points: pts.count, status: "none")
        }
        let lastX = pts.map { $0.0 }.max() ?? 0
        let current = fit.intercept + fit.slope * lastX
        let perWeek = fit.slope * 7                    // units/day → week
        let threshold = 0.02 * max(1, current)         // ~2% of the value/week = meaningful
        let status: String
        if abs(perWeek) < threshold { status = "stable" }
        else if (perWeek > 0) == higherIsBetter { status = "improving" }
        else { status = "declining" }
        return VitalTrend(current: (current * 10).rounded() / 10,
                          deltaPerWeek: (perWeek * 100).rounded() / 100,
                          points: pts.count, status: status)
    }

    /// Resting-HR trend over `days` (lower is better).
    func restingHRTrend(days: Int = 30) -> VitalTrend {
        vitalTrend({ $0.restHR.map(Double.init) }, days: days, higherIsBetter: false)
    }

    /// HRV trend over `days` (higher is better): HRV measured asleep, falling back
    /// to any legacy RMSSD value so older data still trends.
    func hrvTrend(days: Int = 30) -> VitalTrend {
        vitalTrend({ ($0.hrvSleep ?? $0.rmssd).flatMap { $0 > 0 ? $0 : nil } }, days: days, higherIsBetter: true)
    }
}
