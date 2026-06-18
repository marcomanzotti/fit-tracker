import Foundation

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

// MARK: - Weekly volume per muscle group (sets/week)
extension Store {
    struct MuscleVolume: Identifiable {
        var group: MuscleGroup
        var sets: Int            // working sets this week
        var id: String { group.rawValue }
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
            return n > 0 ? MuscleVolume(group: g, sets: n) : nil
        }
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
