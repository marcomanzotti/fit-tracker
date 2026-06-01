import Foundation

// MARK: - Internal-load & recovery science
// All metrics are computed from manually entered data (RPE, duration, avg HR,
// RMSSD). Anything requiring a raw beat-to-beat R-R stream (DFA-alpha1, true
// beat-to-beat RMSSD) needs a BLE chest strap and is intentionally stubbed.

// MARK: TRIMP (Banister, sex-weighted)
extension Store {
    /// Banister TRIMP for a session, needs avg HR + duration. Uses resting/max HR
    /// from the profile (max estimated from age if not measured).
    func trimp(_ s: WorkoutSession) -> Double? {
        guard let dur = s.durationMin, dur > 0, let hr = s.avgHR, hr > 0 else { return nil }
        let rest = Double(prefs.restHRorDefault)
        let mx = Double(s.maxHRSes ?? prefs.estMaxHR)
        guard mx > rest else { return nil }
        let hrr = max(0, min(1, (Double(hr) - rest) / (mx - rest)))
        let y = prefs.sex_ == "f" ? 1.67 : 1.92
        return Double(dur) * hrr * 0.64 * exp(y * hrr)
    }

    /// Strictly *measured* internal load: sRPE (duration × session RPE) or, if
    /// that's missing, TRIMP (duration + avg HR). Returns nil when the user has
    /// entered no intensity data, so ACWR / monotony / strain never fabricate a
    /// load from set counts alone (a single logged Push with no RPE/HR must not
    /// produce a weekly load, monotony or strain number).
    func measuredLoad(_ s: WorkoutSession) -> Double? {
        if let srpe = s.sRPE { return srpe }
        if let t = trimp(s) { return t }
        return nil
    }

    /// Any session that carries a usable internal-load signal.
    func hasMeasuredLoad(_ s: WorkoutSession) -> Bool { measuredLoad(s) != nil }

    /// Sum of session TRIMP in a Monday-based week (offset 0 = current week).
    func weeklyTrimp(offset: Int = 0) -> Double {
        let cal = Calendar.current
        let now = Date()
        let dow = (cal.component(.weekday, from: now) + 5) % 7   // Monday = 0
        let mon = cal.startOfDay(for: cal.date(byAdding: .day, value: -dow - offset * 7, to: now)!)
        let sun = cal.date(byAdding: .day, value: 7, to: mon)!
        var total = 0.0
        for s in sessions {
            guard let v = trimp(s), let d = isoFormatter.date(from: s.date) else { continue }
            if d >= mon && d < sun { total += v }
        }
        return total
    }

    /// TRIMP of the most recent session that has one (nil if no HR logged yet).
    func lastSessionTrimp() -> (value: Double, date: String)? {
        for s in sessions.sorted(by: { $0.date > $1.date }) {
            if let v = trimp(s) { return (v, s.date) }
        }
        return nil
    }

    /// True once any session carries the avg-HR needed to compute TRIMP.
    var hasAnyTrimp: Bool { sessions.contains { trimp($0) != nil } }
}

// MARK: - Daily load series + ACWR (EWMA method)
struct LoadPoint: Identifiable { var date: String; var load: Double; var id: String { date } }

struct ACWRResult {
    var ratio: Double?
    var acute: Double
    var chronic: Double
    /// "low" (detraining), "ok" (sweet spot), "high" (danger), or "none".
    var zone: String
}

extension Store {
    /// Daily summed load for the last `days` days, oldest -> newest, zero-filled.
    func dailyLoadSeries(days: Int) -> [LoadPoint] {
        let cal = Calendar.current
        var map: [String: Double] = [:]
        for s in sessions { if let l = measuredLoad(s) { map[s.date, default: 0] += l } }
        var d = cal.startOfDay(for: Date())
        var stack: [LoadPoint] = []
        for _ in 0..<days {
            let key = isoFormatter.string(from: d)
            stack.append(LoadPoint(date: key, load: map[key] ?? 0))
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return Array(stack.reversed())
    }

    /// Exponentially weighted moving average over a daily series.
    private func ewma(_ values: [Double], days: Int) -> Double {
        guard !values.isEmpty else { return 0 }
        let lambda = 2.0 / (Double(days) + 1.0)
        var e = values[0]
        for v in values.dropFirst() { e = v * lambda + e * (1 - lambda) }
        return e
    }

    /// ACWR with the EWMA method (acute = 7d, chronic = 28d).
    func acwr() -> ACWRResult {
        let series = dailyLoadSeries(days: 42).map { $0.load }
        guard series.contains(where: { $0 > 0 }) else {
            return ACWRResult(ratio: nil, acute: 0, chronic: 0, zone: "none")
        }
        let acute = ewma(series, days: 7)
        let chronic = ewma(series, days: 28)
        guard chronic > 0 else { return ACWRResult(ratio: nil, acute: acute, chronic: chronic, zone: "none") }
        let r = acute / chronic
        let zone: String
        switch r {
        case ..<0.8:        zone = "low"
        case 0.8..<1.3:     zone = "ok"
        case 1.3..<1.5:     zone = "high"
        default:            zone = "high"
        }
        return ACWRResult(ratio: (r * 100).rounded() / 100, acute: acute, chronic: chronic, zone: zone)
    }
}

// MARK: - Weekly monotony & strain (Foster)
struct WeekLoad {
    var total: Double
    var mean: Double
    var sd: Double
    var monotony: Double?      // mean / sd (high = too flat / monotonous)
    var strain: Double?        // total × monotony
    var sessions: Int
}

extension Store {
    /// Monday-based week, offset 0 = current week.
    func weekLoad(offset: Int) -> WeekLoad {
        let cal = Calendar.current
        let now = Date()
        let dow = (cal.component(.weekday, from: now) + 5) % 7    // Monday = 0
        let mon = cal.startOfDay(for: cal.date(byAdding: .day, value: -dow - offset * 7, to: now)!)
        var daily = [Double](repeating: 0, count: 7)
        var count = 0
        var trainingDays = Set<Int>()
        for s in sessions {
            guard let l = measuredLoad(s), let d = isoFormatter.date(from: s.date) else { continue }
            let day = cal.startOfDay(for: d)
            let diff = cal.dateComponents([.day], from: mon, to: day).day ?? -1
            if diff >= 0 && diff < 7 { daily[diff] += l; count += 1; trainingDays.insert(diff) }
        }
        let total = daily.reduce(0, +)
        let mean = total / 7
        let variance = daily.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / 7
        let sd = variance.squareRoot()
        // Monotony/strain are only meaningful with at least 2 training days in the
        // week; with a single session they are statistically degenerate, so leave
        // them nil rather than showing a misleading number.
        let monotony = (sd > 0 && trainingDays.count >= 2) ? mean / sd : nil
        let strain = monotony.map { total * $0 }
        return WeekLoad(total: total, mean: mean, sd: sd, monotony: monotony, strain: strain, sessions: count)
    }
}

// MARK: - Readiness from HRV (lnRMSSD vs rolling baseline)
struct ReadinessResult {
    var score: Int?            // 0-100
    var lnToday: Double?
    var baseline: Double?      // mean lnRMSSD
    var sd: Double?
    var samples: Int
    /// "rest", "easy", "ready", or "none".
    var advice: String
}

extension Store {
    /// Reads RMSSD typed into daily check-ins (and sessions), builds a ~60-day
    /// lnRMSSD baseline, returns today's reading as a 0-100 readiness score.
    func readiness() -> ReadinessResult {
        // Collect a single, consistent HRV source. Manual RMSSD is preferred; if
        // there isn't enough of it, fall back to SDNN imported from Apple Health.
        // The readiness math is a personal-baseline z-score of ln(HRV), so it works
        // on either metric as long as one source is used consistently.
        var rmssdMap: [String: Double] = [:]
        for s in sessions { if let r = s.rmssd, r > 0 { rmssdMap[s.date] = r } }
        for d in daily { if let r = d.rmssd, r > 0 { rmssdMap[d.date] = r } }
        var sdnnMap: [String: Double] = [:]
        for d in daily { if let h = d.hrvSDNN, h > 0 { sdnnMap[d.date] = h } }
        let map = rmssdMap.count >= sdnnMap.count ? rmssdMap : sdnnMap
        let pairs = map.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        guard pairs.count >= 1 else {
            return ReadinessResult(score: nil, lnToday: nil, baseline: nil, sd: nil, samples: 0, advice: "none")
        }
        let lns = pairs.map { log($0.value) }
        let lnToday = lns.last!
        // baseline excludes today's point when we have enough history
        let history = lns.count > 1 ? Array(lns.dropLast()) : lns
        let base = Array(history.suffix(60))
        let mean = base.reduce(0, +) / Double(base.count)
        let variance = base.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(base.count)
        let sd = variance.squareRoot()
        guard base.count >= 5, sd > 0 else {
            return ReadinessResult(score: nil, lnToday: lnToday, baseline: mean, sd: sd, samples: base.count, advice: "none")
        }
        let z = (lnToday - mean) / sd
        let score = Int(max(0, min(100, (50 + 20 * z).rounded())))
        let advice: String
        switch z {
        case ..<(-1.0): advice = "rest"
        case (-1.0)..<(-0.3): advice = "easy"
        default: advice = "ready"
        }
        return ReadinessResult(score: score, lnToday: lnToday, baseline: mean, sd: sd, samples: base.count, advice: advice)
    }

    /// DFA-alpha1 aerobic-threshold estimation requires a continuous R-R interval
    /// stream from a chest strap. Stubbed until BLE support lands.
    func dfaAlpha1Available() -> Bool { false }
}

// MARK: - Progressive overload (double progression)
enum ProgKind: String {
    case addLoad, addReps, hold, deload
    var key: String {
        switch self {
        case .addLoad: return "wk.add_load"
        case .addReps: return "wk.add_reps"
        case .hold:    return "wk.hold"
        case .deload:  return "wk.deload_ex"
        }
    }
}

extension Store {
    /// Parse a target like "8-10" or "10" into a rep range. Returns nil for
    /// time/asymmetric targets ("30s/lato") we shouldn't auto-progress.
    func repRange(_ s: String) -> (Int, Int)? {
        if s.lowercased().contains("s") { return nil }       // seconds-based
        let nums = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let lo = nums.first else { return nil }
        let hi = nums.count > 1 ? nums[1] : lo
        return (lo, max(lo, hi))
    }

    /// Suggest whether to add load, add reps, hold, or deload an exercise, based
    /// on the last logged session vs the plan's target rep range (double progression).
    func progression(planId: String, exercise: String) -> ProgKind? {
        guard let plan = plan(planId),
              let pe = plan.exercises.first(where: { $0.name == exercise }),
              let (lo, hi) = repRange(pe.reps),
              let last = lastSession(forPlan: planId),
              let ex = last.exercises.first(where: { $0.name == exercise }) else { return nil }
        let working = ex.sets.filter { pf($0.weight) > 0 }
        guard !working.isEmpty else { return nil }
        let reps = working.map { Int(pf($0.reps)) }
        guard let minReps = reps.min(), minReps > 0 else { return nil }
        if minReps >= hi { return .addLoad }               // topped the range -> heavier
        if minReps >= lo { return .addReps }               // in range -> chase more reps
        return .hold                                        // missed the bottom -> hold form
    }
}
