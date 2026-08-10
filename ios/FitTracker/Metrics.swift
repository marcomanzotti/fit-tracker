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
    func bestE1RM(_ name: String) -> Double? {
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

    /// e1RM over time for an exercise (best set per session), oldest -> newest, for
    /// a progression chart. One point per session that has a usable loaded set.
    struct E1RMPoint: Identifiable { var date: String; var value: Double; var id: String { date } }
    func e1RMSeries(_ name: String) -> [E1RMPoint] {
        var pts: [E1RMPoint] = []
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            var best = 0.0
            for e in s.exercises where e.name == name {
                for set in e.sets { if let v = e1RM(weight: pf(set.weight), reps: pf(set.reps)) { best = max(best, v) } }
            }
            if best > 0 { pts.append(E1RMPoint(date: s.date, value: (best * 10).rounded() / 10)) }
        }
        return pts
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

    /// FFMI from the current weight and body fat. nil without a body-fat figure —
    /// the whole point is separating lean mass from fat, which needs that split.
    /// Normalization (Kouri et al.) adds 6.1 × (1.80 − height) so a 1.65 m and a
    /// 1.95 m lifter can be compared on the same scale.
    func ffmi() -> FFMIResult? {
        let h = prefs.height
        guard h > 1.0, h < 2.5, let lean = fatFreeMass(), lean > 0 else { return nil }
        let raw = lean / (h * h)
        let norm = raw + 6.1 * (1.80 - h)
        return FFMIResult(raw: (raw * 10).rounded() / 10,
                          normalized: (norm * 10).rounded() / 10,
                          lean: (lean * 10).rounded() / 10)
    }

    /// Band for a normalized FFMI, sex-adjusted (women's bands sit ~3 points lower).
    /// Above the top band is very rare without drugs, so it's labelled as the
    /// natural limit rather than as another rung to climb.
    func ffmiCategory(_ v: Double, sex: String) -> (key: String, color: Color) {
        let shift: Double = sex == "f" ? -3 : 0
        switch v {
        case ..<(18 + shift):  return ("ffmi.below", Theme.sub)
        case ..<(20 + shift):  return ("ffmi.average", Theme.blue)
        case ..<(22 + shift):  return ("ffmi.good", Theme.good)
        case ..<(23 + shift):  return ("ffmi.great", Theme.acc2)
        case ..<(26 + shift):  return ("ffmi.excellent", Theme.acc)
        default:               return ("ffmi.elite", Theme.fat)
        }
    }

    /// FFMI for a past day, for the trend chart: that day's weight against the
    /// current body-fat reading (Health gives weight daily, body fat rarely — so the
    /// line tracks how lean mass moved with weight, holding composition constant).
    func ffmiFor(weight: Double) -> Double? {
        let h = prefs.height
        guard h > 1.0, h < 2.5, let bf = currentBF, bf > 0, bf < 60, weight > 0 else { return nil }
        let lean = weight * (1 - bf / 100)
        return ((lean / (h * h)) * 10).rounded() / 10
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
        var sets: Int            // working sets this week
        var target: Int          // weekly working-set target for this group
        var id: String { group.rawValue }

        /// Where this week's volume sits against the target: "low" below the range,
        /// "ok" inside it, "high" above. The range is target ± half, i.e. the usual
        /// 10-20 sets/week band around a target of ~15.
        var status: String {
            let lower = Int((Double(target) * 0.67).rounded())
            let upper = Int((Double(target) * 1.33).rounded())
            if sets < lower { return "low" }
            if sets > upper { return "high" }
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
        let cal = Calendar.current
        let now = Date()
        let dow = (cal.component(.weekday, from: now) + 5) % 7
        let mon = cal.startOfDay(for: cal.date(byAdding: .day, value: -dow - offset * 7, to: now)!)
        let sun = cal.date(byAdding: .day, value: 7, to: mon)!
        var counts: [String: Int] = [:]
        for s in sessions {
            guard let d = isoFormatter.date(from: s.date), d >= mon, d < sun else { continue }
            for e in s.exercises {
                let working = e.sets.filter { $0.filled }.count
                guard working > 0 else { continue }
                let g = exerciseCategory(e.name)
                counts[g, default: 0] += working
            }
        }
        return MuscleGroup.allCases.compactMap { g in
            let n = counts[g.rawValue] ?? 0
            return n > 0 ? MuscleVolume(group: g, sets: n, target: volumeTarget(g)) : nil
        }
    }

    /// Whether the week's numbers say to back off. Deloading is warranted when the
    /// acute load has run away from the chronic baseline (ACWR high) AND training has
    /// been monotonous — the classic Foster combination that precedes overreaching.
    /// Returns nil unless the load data is trustworthy: a deload suggestion off two
    /// logged sessions would be noise.
    func deloadAdvice() -> Bool {
        guard loadDataStatus().reliable else { return false }
        let a = acwr()
        guard let ratio = a.ratio else { return false }
        let w = weekLoad(offset: 0)
        guard let mono = w.monotony else { return false }
        return ratio > 1.5 && mono > 2.0
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
    func vo2maxEstimate() -> (value: Double, estimated: Bool)? {
        if let v = latestVO2, v > 0 { return (v, false) }
        // Estimate from the most intense recent run with both distance and avg HR.
        let runs = sessions
            .filter { $0.sportType == .running }
            .sorted { $0.date > $1.date }
            .prefix(20)
        var best: Double? = nil
        for r in runs {
            guard let mins = r.durationMinutesD, mins > 0,
                  let km = r.distanceKm, km > 0,
                  let hr = r.avgHR, hr > 0 else { continue }
            // Velocity in m/min.
            let v = km * 1000 / mins
            // VO2 at this pace (ACSM running equation): 0.2·v + 3.5 (mL/kg/min).
            let vo2AtPace = 0.2 * v + 3.5
            // Scale by the fraction of HR reserve used, so an easy run isn't read as
            // a max effort: %HRR ≈ (HR - rest)/(max - rest). VO2max ≈ vo2AtPace / %VO2.
            let rest = Double(prefs.restHRorDefault)
            let mx = Double(prefs.estMaxHR)
            guard mx > rest else { continue }
            let hrr = max(0.5, min(1.0, (Double(hr) - rest) / (mx - rest)))
            let est = vo2AtPace / hrr
            best = max(best ?? 0, est)
        }
        return best.map { (($0 * 10).rounded() / 10, true) }
    }

    /// Five heart-rate training zones (% of HR reserve, Karvonen) with their bpm
    /// bounds for the user's profile. Zone 1 easy … Zone 5 max.
    struct HRZone: Identifiable { var index: Int; var lower: Int; var upper: Int; var id: Int { index } }
    func hrZones() -> [HRZone] {
        let rest = Double(prefs.restHRorDefault)
        let mx = Double(prefs.estMaxHR)
        guard mx > rest else { return [] }
        let bounds = [0.50, 0.60, 0.70, 0.80, 0.90, 1.00]
        func bpm(_ frac: Double) -> Int { Int((rest + frac * (mx - rest)).rounded()) }
        return (0..<5).map { i in HRZone(index: i + 1, lower: bpm(bounds[i]), upper: bpm(bounds[i + 1])) }
    }

    /// Which zone (1-5) a given average HR falls in, for tagging a cardio session.
    func hrZone(for bpm: Int) -> Int? {
        let zones = hrZones()
        guard !zones.isEmpty, bpm > 0 else { return nil }
        if bpm < zones[0].lower { return 1 }
        for z in zones where bpm >= z.lower && bpm <= z.upper { return z.index }
        return 5
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
        let n = Double(pts.count)
        let sx = pts.reduce(0) { $0 + $1.0 }, sy = pts.reduce(0) { $0 + $1.1 }
        let sxx = pts.reduce(0) { $0 + $1.0 * $1.0 }, sxy = pts.reduce(0) { $0 + $1.0 * $1.1 }
        let denom = n * sxx - sx * sx
        guard denom != 0 else { return VitalTrend(current: sy / n, deltaPerWeek: nil, points: pts.count, status: "none") }
        let slope = (n * sxy - sx * sy) / denom        // units/day
        let intercept = (sy - slope * sx) / n
        let lastX = pts.map { $0.0 }.max() ?? 0
        let current = intercept + slope * lastX
        let perWeek = slope * 7
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

    /// HRV trend over `days` (higher is better). Prefers SDNN from Health, falling
    /// back to any legacy RMSSD value so older data still trends.
    func hrvTrend(days: Int = 30) -> VitalTrend {
        vitalTrend({ ($0.hrvSDNN ?? $0.rmssd).flatMap { $0 > 0 ? $0 : nil } }, days: days, higherIsBetter: true)
    }
}
