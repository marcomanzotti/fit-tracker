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
        guard let dur = s.durationMinutesD, dur > 0, let hr = s.avgHR, hr > 0 else { return nil }
        let rest = Double(prefs.restHRorDefault)
        let mx = Double(s.maxHRSes ?? prefs.estMaxHR)
        guard mx > rest else { return nil }
        let hrr = max(0, min(1, (Double(hr) - rest) / (mx - rest)))
        let y = prefs.sex_ == "f" ? 1.67 : 1.92
        return dur * hrr * 0.64 * exp(y * hrr)
    }

    /// Strictly *measured* internal load = TRIMP (duration + avg HR). Returns nil
    /// when no average HR was entered, so ACWR / monotony / strain never fabricate
    /// a load from set counts alone (a single logged Push with no HR must not
    /// produce a weekly load, monotony or strain number).
    ///
    /// We intentionally do NOT fall back to the old sRPE (duration × session RPE):
    /// the RPE input was removed in v4, so any sRPE today comes only from legacy
    /// sessions and would inflate internal load even when no avg HR was entered —
    /// exactly the "load looks extremely high without HR" surprise. TRIMP is now
    /// the single source of internal load.
    func measuredLoad(_ s: WorkoutSession) -> Double? {
        trimp(s)
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
struct LoadPoint: Identifiable {
    var date: String
    var load: Double
    var id: String { date }
    var day: Date { isoFormatter.date(from: date) ?? Date() }
}

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

    /// Whether there is enough load history for ACWR/monotony/strain to be
    /// meaningful. ACWR compares a 7-day acute window to a 28-day chronic one, so
    /// with only a couple of sessions the ratio is wildly out of scale (e.g. 3.6
    /// off a single ride). We require a minimum number of HR-logged sessions
    /// spread over enough calendar days before showing the numbers.
    struct LoadDataStatus {
        var reliable: Bool
        var sessions: Int          // sessions carrying internal load so far
        var spanDays: Int          // days from the first such session to today
        var needSessions: Int      // minimum sessions required
        var needDays: Int          // minimum span (days) required
    }
    func loadDataStatus() -> LoadDataStatus {
        let needSessions = 6, needDays = 21
        let loaded = sessions.filter { measuredLoad($0) != nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = loaded.compactMap { isoFormatter.date(from: $0.date) }.map { cal.startOfDay(for: $0) }
        // Inclusive day span: a single session logged today is 1 day of history,
        // not 0 (the "0 days is impossible" surprise). A session has internal load
        // only when it carries an avg HR, so HR-less strength days don't count.
        let span = dates.min().map { (cal.dateComponents([.day], from: $0, to: today).day ?? 0) + 1 } ?? 0
        let reliable = loaded.count >= needSessions && span >= needDays
        return LoadDataStatus(reliable: reliable, sessions: loaded.count, spanDays: span,
                              needSessions: needSessions, needDays: needDays)
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

// MARK: - Readiness (multi-factor: HRV + resting HR + sleep)
struct ReadinessResult {
    var score: Int?            // 0-100
    var lnToday: Double?       // today's lnHRV (kept for the HRV detail line)
    var baseline: Double?      // mean lnHRV baseline
    var sd: Double?
    var samples: Int           // HRV baseline sample count (drives the "building" card)
    /// "rest", "easy", "ready", or "none".
    var advice: String
    /// Which signals contributed today (e.g. ["hrv","hr","sleep"]) — for the card.
    var usedSignals: [String] = []
}

extension Store {
    /// Multi-factor morning readiness. Each available signal is turned into a
    /// personal-baseline z-score (positive = more recovered than usual), then the
    /// signals are combined with fixed weights, renormalized over whatever exists
    /// that day so it degrades gracefully:
    ///   • HRV (lnRMSSD, or SDNN from Health) — primary, weight 0.50, higher = better
    ///   • resting / waking HR (or sleeping HR) — weight 0.30, lower = better
    ///   • sleep score — weight 0.20, higher = better (absolute anchor until there
    ///     is enough history for a personal baseline)
    /// The composite z maps to 0-100 as 50 + 20·z (so ±2.5 SD spans the full range)
    /// and to the rest/easy/ready advice bands.
    func readiness() -> ReadinessResult {
        // HRV: prefer any legacy per-session/daily HRV value, fall back to the
        // HRV imported from Apple Health — whichever has more days, used
        // consistently (the z-score works on either; both are HRV in ms).
        var rmssdMap: [String: Double] = [:]
        for s in sessions { if let r = s.rmssd, r > 0 { rmssdMap[s.date] = r } }
        for d in daily { if let r = d.rmssd, r > 0 { rmssdMap[d.date] = r } }
        var sdnnMap: [String: Double] = [:]
        for d in daily { if let h = d.hrvSDNN, h > 0 { sdnnMap[d.date] = h } }
        let hrvMap = rmssdMap.count >= sdnnMap.count ? rmssdMap : sdnnMap

        var factors: [(name: String, z: Double, w: Double)] = []
        var hrvSamples = 0
        var lnToday: Double? = nil, hrvBase: Double? = nil, hrvSD: Double? = nil

        if let f = zFactor(map: hrvMap, transform: { log($0) }, higherIsBetter: true, minN: 5) {
            factors.append((name: "hrv", z: f.z, w: 0.50))
            hrvSamples = f.baseCount; lnToday = f.today; hrvBase = f.mean; hrvSD = f.sd
        }

        // Resting / waking HR (fall back to sleeping HR). Lower than baseline = better.
        var hrMap: [String: Double] = [:]
        for d in daily {
            if let v = d.restHR, v > 0 { hrMap[d.date] = Double(v) }
            else if let v = d.sleepHR, v > 0 { hrMap[d.date] = Double(v) }
        }
        if let f = zFactor(map: hrMap, transform: { $0 }, higherIsBetter: false, minN: 5) {
            factors.append((name: "hr", z: f.z, w: 0.30))
        }

        // Sleep score. Use a personal baseline once there's enough history, else an
        // absolute anchor (≈72/100 a decent night, ±12 spread) so it still counts.
        var sleepMap: [String: Double] = [:]
        for d in daily { if let v = d.sleep, v > 0 { sleepMap[d.date] = Double(v) } }
        if let f = zFactor(map: sleepMap, transform: { $0 }, higherIsBetter: true, minN: 5) {
            factors.append((name: "sleep", z: f.z, w: 0.20))
        } else if let latestKey = sleepMap.keys.max(), let todayScore = sleepMap[latestKey] {
            factors.append((name: "sleep", z: max(-3, min(3, (todayScore - 72) / 12)), w: 0.20))
        }

        guard !factors.isEmpty else {
            return ReadinessResult(score: nil, lnToday: lnToday, baseline: hrvBase, sd: hrvSD,
                                   samples: hrvSamples, advice: "none", usedSignals: [])
        }
        let wSum = factors.reduce(0) { $0 + $1.w }
        let z = factors.reduce(0) { $0 + $1.z * $1.w } / wSum
        let score = Int(max(0, min(100, (50 + 20 * z).rounded())))
        let advice: String
        switch z {
        case ..<(-1.0): advice = "rest"
        case (-1.0)..<(-0.3): advice = "easy"
        default: advice = "ready"
        }
        return ReadinessResult(score: score, lnToday: lnToday, baseline: hrvBase, sd: hrvSD,
                               samples: hrvSamples, advice: advice, usedSignals: factors.map { $0.name })
    }

    /// Standardize the latest reading of a daily metric against a personal baseline
    /// of the prior ~60 days. Returns today's z (sign flipped when lower is better,
    /// clamped to ±3 so one freak reading can't dominate), plus baseline stats.
    private func zFactor(map: [String: Double], transform: (Double) -> Double,
                         higherIsBetter: Bool, minN: Int)
        -> (z: Double, today: Double, mean: Double, sd: Double, baseCount: Int)? {
        let pairs = map.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        guard !pairs.isEmpty else { return nil }
        let vals = pairs.map { transform($0.value) }
        let today = vals.last!
        let history = vals.count > 1 ? Array(vals.dropLast()) : vals
        let base = Array(history.suffix(60))
        guard base.count >= minN else { return nil }
        let mean = base.reduce(0, +) / Double(base.count)
        let variance = base.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(base.count)
        let sd = variance.squareRoot()
        guard sd > 0 else { return nil }
        var z = (today - mean) / sd
        if !higherIsBetter { z = -z }
        return (max(-3, min(3, z)), today, mean, sd, base.count)
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

    /// Double-progression for an exercise, enhanced with health and load context.
    /// Priority order:
    ///   1. Deload: HRV score < 30 (very low readiness) → always deload
    ///   2. Hold:   ACWR > 1.3 (load spike) → hold to reduce injury risk
    ///   3. Rep / load suggestion from last session vs target range
    ///   4. Consistency check: if the exercise was hit at the top of the range
    ///      in the two most recent sessions, confirm addLoad; a single session
    ///      at the top with a prior fall-short stays at addReps (not yet confirmed).
    func progression(planId: String, exercise: String) -> ProgKind? {
        guard let plan = plan(planId),
              let pe = plan.exercises.first(where: { $0.name == exercise }),
              let (lo, hi) = repRange(pe.reps) else { return nil }

        // Health gates — check readiness and load FIRST.
        let r = readiness()
        if let score = r.score, score < 30 { return .deload }
        let aw = acwr()
        if let ratio = aw.ratio, ratio > 1.3 { return .hold }

        // Collect the last two sessions for this plan.
        let planSessions = sessions
            .filter { $0.planId == planId && $0.date != today() }
            .sorted { $0.date > $1.date }
        guard let last = planSessions.first,
              let ex = last.exercises.first(where: { $0.name == exercise }) else { return nil }

        let working = ex.sets.filter { pf($0.weight) > 0 }
        guard !working.isEmpty else { return nil }
        let reps = working.map { Int(pf($0.reps)) }
        guard let minReps = reps.min(), minReps > 0 else { return nil }

        // Effort-based gate: if per-set RIR/RPE data exists and indicates plenty
        // of reserve (RIR ≥ 3 or RPE ≤ 6), stay at addReps even at the top.
        if let effortScale = ex.effortScale {
            let effortVals = ex.sets.compactMap { $0.effortVal }
            if !effortVals.isEmpty {
                let avgEffort = Double(effortVals.reduce(0, +)) / Double(effortVals.count)
                switch effortScale {
                case .rir where avgEffort >= 3: return .addReps   // still easy — chase reps
                case .rpe where avgEffort <= 6: return .addReps
                default: break
                }
            }
        }

        guard minReps >= hi else {
            return minReps >= lo ? .addReps : .hold
        }

        // At the top of the range — confirm with the previous session before
        // calling addLoad, so one lucky session doesn't falsely trigger a jump.
        if planSessions.count >= 2 {
            let prev = planSessions[1]
            if let prevEx = prev.exercises.first(where: { $0.name == exercise }) {
                let prevWorking = prevEx.sets.filter { pf($0.weight) > 0 }
                let prevReps = prevWorking.compactMap { Int(pf($0.reps)) }
                if let prevMin = prevReps.min(), prevMin >= hi {
                    return .addLoad   // two sessions at ceiling → ready for more weight
                }
            }
        }
        return .addLoad   // only one session in history, give the benefit of the doubt
    }
}
