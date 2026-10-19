import Foundation

// MARK: - Internal-load & recovery science
// Computed from the logged sessions and the daily values (typed or read from
// Apple Health).

// MARK: TRIMP (Banister, sex-weighted)
extension Store {
    /// Banister TRIMP for a session, needs avg HR + duration. Uses resting/max HR
    /// from the profile (max estimated from age if not measured).
    func trimp(_ s: WorkoutSession) -> Double? {
        guard let dur = s.durationMinutesD, dur > 0 else { return nil }
        // The exponential weights hard minutes more than easy ones, so intervals are
        // integrated over the heart-rate samples when Health has them for most of
        // the workout; the average is the fallback.
        if let histogram = s.hrHistogram, let integrated = integratedTrimp(histogram, minutes: dur, session: s) {
            return integrated
        }
        guard let hrr = hrReserve(s.avgHR, session: s) else { return nil }
        return dur * Store.banister(hrr, female: prefs.sex_ == "f")
    }

    /// Banister/Morton weight of one minute at a reserve fraction: 0.64·x·e^(1.92x)
    /// for men, 0.86·x·e^(1.67x) for women.
    private static func banister(_ hrr: Double, female: Bool) -> Double {
        hrr * (female ? 0.86 : 0.64) * exp((female ? 1.67 : 1.92) * hrr)
    }

    private static let minSampleCoverage = 0.5

    private func integratedTrimp(_ histogram: [Int: Int], minutes: Double, session s: WorkoutSession) -> Double? {
        let rest = restingHR(on: s.date), mx = Double(prefs.estMaxHR)
        let seconds = Double(histogram.values.reduce(0, +))
        let coverage = seconds / (minutes * 60)
        guard mx > rest, coverage >= Store.minSampleCoverage else { return nil }
        let female = prefs.sex_ == "f"
        let total = histogram.reduce(0.0) { sum, bin in
            let hrr = max(0, min(1, (Double(bin.key) - rest) / (mx - rest)))
            return sum + Double(bin.value) / 60 * Store.banister(hrr, female: female)
        }
        // Samples with gaps stand for the whole workout.
        return total / min(1, coverage)
    }

    private static let restingWindowDays = 7
    private static let restingMinReadings = 3

    /// Resting heart rate that counted on a day: the median of Health's readings in
    /// the week before, the profile value without at least three. Using the day's
    /// own figure keeps old sessions from moving when today's changes (a flu).
    func restingHR(on date: String) -> Double {
        memo("restingHR|\(date)") {
            guard let end = isoFormatter.date(from: date),
                  let start = Calendar.current.date(byAdding: .day, value: -Store.restingWindowDays, to: end) else {
                return Double(prefs.restHRorDefault)
            }
            let from = isoFormatter.string(from: start)
            let readings = sortedDaily.compactMap { e -> Double? in
                guard e.date >= from, e.date < date, let hr = e.restHR, hr > 0 else { return nil }
                return Double(hr)
            }.sorted()
            guard readings.count >= Store.restingMinReadings else { return Double(prefs.restHRorDefault) }
            let mid = readings.count / 2
            return readings.count % 2 == 1 ? readings[mid] : (readings[mid - 1] + readings[mid]) / 2
        }
    }

    /// The resting heart rate for zones and anything that is about now.
    func currentRestingHR() -> Double {
        restingHR(on: isoFormatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()))
    }

    private static let maxHRHistoryDays = 365

    /// A maximum heart rate learned from the workouts: the second highest peak of
    /// the last year when it is above the estimate. The second one, so a single
    /// strap glitch does not set it. Suggested in Settings, never applied alone.
    var suggestedMaxHR: Int? {
        memo("suggestedMaxHR") { () -> Int? in
            let cutoff = Calendar.current.date(byAdding: .day, value: -Store.maxHRHistoryDays, to: Date())
                .map { isoFormatter.string(from: $0) } ?? ""
            let peaks = sessions.compactMap { s -> Int? in
                guard s.date >= cutoff else { return nil }
                return [s.maxHRSes, s.hrHistogram?.keys.max()].compactMap { $0 }.max()
            }.filter { $0 < Store.plausibleMaxHR }.sorted(by: >)
            guard peaks.count >= 2, peaks[1] > prefs.estMaxHR else { return nil }
            return peaks[1]
        }
    }
    static let plausibleMaxHR = 230

    /// TRIMP of every stored session that has one, computed once per change.
    var sessionTrimps: [UUID: Double] {
        memo("sessionTrimps") {
            var out: [UUID: Double] = [:]
            for s in sessions { if let v = trimp(s) { out[s.id] = v } }
            return out
        }
    }

    /// Summed TRIMP per day (yyyy-MM-dd).
    var loadByDay: [String: Double] {
        memo("loadByDay") {
            let trimps = sessionTrimps
            var out: [String: Double] = [:]
            for s in sessions { if let v = trimps[s.id] { out[s.date, default: 0] += v } }
            return out
        }
    }

    /// Sum of session TRIMP in a Monday-based week (offset 0 = current week).
    func weeklyTrimp(offset: Int = 0) -> Double {
        // ISO dates sort as text: no date parsing per session.
        let from = isoFormatter.string(from: weekStart(offset: offset))
        let to = isoFormatter.string(from: weekStart(offset: offset - 1))
        return loadByDay.reduce(0) { $1.key >= from && $1.key < to ? $0 + $1.value : $0 }
    }

    /// TRIMP of the most recent session that has one (nil if no HR logged yet).
    func lastSessionTrimp() -> (value: Double, date: String)? {
        let trimps = sessionTrimps
        return sessions.filter { trimps[$0.id] != nil }.max { $0.date < $1.date }.flatMap { s in trimps[s.id].map { ($0, s.date) } }
    }

    /// True once any session carries the avg-HR needed to compute TRIMP.
    var hasAnyTrimp: Bool { !sessionTrimps.isEmpty }
}

// MARK: - Daily load series
struct LoadPoint: Identifiable {
    var date: String
    var load: Double
    var id: String { date }
    var day: Date { isoFormatter.date(from: date) ?? Date() }
}

struct ACWRResult {
    var ratio: Double?
    /// "low" (detraining), "ok" (sweet spot), "high" (danger), or "none".
    var zone: String
}

extension Store {
    /// Daily summed load for the last `days` days, oldest -> newest, zero-filled.
    func dailyLoadSeries(days: Int) -> [LoadPoint] { memo("dailyLoad|\(days)") { computeDailyLoad(days: days) } }

    private func computeDailyLoad(days: Int) -> [LoadPoint] {
        let cal = Calendar.current
        let map = loadByDay
        var d = cal.startOfDay(for: Date())
        var stack: [LoadPoint] = []
        for _ in 0..<days {
            let key = isoFormatter.string(from: d)
            stack.append(LoadPoint(date: key, load: map[key] ?? 0))
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return Array(stack.reversed())
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
    func loadDataStatus() -> LoadDataStatus { memo("loadDataStatus") { computeLoadDataStatus() } }

    private func computeLoadDataStatus() -> LoadDataStatus {
        let needSessions = 6, needDays = 21
        let trimps = sessionTrimps
        let loaded = sessions.filter { trimps[$0.id] != nil }
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

    /// Acute:chronic ratio from the same two averages as the form: fatigue ÷ fitness.
    /// One load model, so this and the form can never disagree.
    func acwr() -> ACWRResult { memo("acwr") { computeACWR() } }

    private func computeACWR() -> ACWRResult {
        guard let today = formSeries(days: 1).last, today.fitness > 0 else { return ACWRResult(ratio: nil, zone: "none") }
        let r = today.fatigue / today.fitness
        let zone: String
        switch r {
        case ..<0.8:        zone = "low"
        case 0.8..<1.3:     zone = "ok"
        default:            zone = "high"
        }
        return ACWRResult(ratio: (r * 100).rounded() / 100, zone: zone)
    }

    /// Form as a share of fitness, %: below −30 the load runs ahead of what the body
    /// is used to (as in intervals.icu), from −30 to −10 it is productive. A share
    /// keeps the bands the same whatever the unit of the load.
    func formPercent() -> Double? {
        memo("formPercent") { () -> Double? in
            guard let today = formSeries(days: 1).last, today.fitness > 0 else { return nil }
            return today.form / today.fitness * 100
        }
    }
    static let overreachingBelowFormPercent = -30.0
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
    ///
    /// Foster's monotony divides by the number of days in the window, but a day we
    /// have no information about must NOT be silently treated as a true zero: a
    /// Tuesday the user simply forgot to log would drag the weekly mean down and
    /// inflate monotony/strain, making one missed entry look like a recovery week.
    /// So the denominator is the number of *known* days — days with a logged
    /// session plus days explicitly marked as rest (`prefs.restDaySet`) — not a
    /// fixed 7. A fully logged week still divides by 7 (identical to classic
    /// Foster); a week with an untracked gap divides by fewer days, and an explicit
    /// rest day still counts as a legitimate zero (which is what monotony should
    /// reward). Past weeks (offset > 0) fall back to 7 when nothing is known, since
    /// we can't retroactively distinguish rest from a gap.
    func weekLoad(offset: Int) -> WeekLoad { memo("weekLoad|\(offset)") { weekLoad(offset: offset, now: Date()) } }

    func weekLoad(offset: Int, now: Date) -> WeekLoad {
        let cal = Calendar.current
        let mon = weekStart(offset: offset, now: now)
        // The week's seven dates as text, so sessions are placed without parsing.
        let dayKeys = (0..<7).map { cal.date(byAdding: .day, value: $0, to: mon).map { isoFormatter.string(from: $0) } ?? "" }
        let index = Dictionary(uniqueKeysWithValues: dayKeys.enumerated().map { ($1, $0) })
        let trimps = sessionTrimps
        var daily = [Double](repeating: 0, count: 7)
        var count = 0
        var trainingDays = Set<Int>()
        var knownDays = Set<Int>()                 // days we have real information about
        for s in sessions {
            guard let l = trimps[s.id], let diff = index[s.date] else { continue }
            daily[diff] += l; count += 1; trainingDays.insert(diff); knownDays.insert(diff)
        }
        // Explicit rest days are real zeros (they keep monotony honest); future days
        // of the current week aren't known yet, so they don't dilute the mean.
        let restSet = prefs.restDaySet
        for (diff, key) in dayKeys.enumerated() where restSet.contains(key) { knownDays.insert(diff) }
        // The days of this week that have already passed are known too: with no
        // session they were days without load (Foster counts them as zeros), and
        // leaving them out made two sessions in three days look like a monotony of 9.
        if offset == 0 {
            let passed = cal.dateComponents([.day], from: mon, to: cal.startOfDay(for: now)).day ?? 0
            for diff in 0..<max(0, min(7, passed)) { knownDays.insert(diff) }
        }
        // Denominator: known days for the current week; classic 7 for past weeks
        // where a gap can't be told apart from rest.
        let denom = Double(offset == 0 ? max(1, knownDays.count) : 7)
        let total = daily.reduce(0, +)
        let mean = total / denom
        // Variance over the same known-day set (or all 7 for past weeks).
        let days = offset == 0 ? Array(knownDays).sorted() : Array(0..<7)
        let variance = days.reduce(0.0) { $0 + (daily[$1] - mean) * (daily[$1] - mean) } / denom
        let sd = variance.squareRoot()
        // Monotony/strain are only meaningful with at least 2 training days in the
        // week; with a single session they are statistically degenerate, so leave
        // them nil rather than showing a misleading number.
        let monotony = (sd > 0 && trainingDays.count >= 2) ? mean / sd : nil
        let strain = monotony.map { total * $0 }
        return WeekLoad(total: total, mean: mean, sd: sd, monotony: monotony, strain: strain, sessions: count)
    }
}

// MARK: - Personal normal range (the user's own last 60 days)
/// Where a nightly value usually sits for this user: mean and SD of the readings
/// in the `baselineDays` before the day being judged.
struct PersonalRange {
    var mean: Double
    var sd: Double
    var n: Int
    func z(_ v: Double) -> Double { sd > 0 ? (v - mean) / sd : 0 }
}

/// One overnight vital of a night, judged against the personal range.
struct VitalReading: Identifiable {
    var field: HealthField
    var value: Double
    var range: PersonalRange?
    /// Distance from the mean beyond which the value is out of range.
    var band: Double
    /// "ok" | "high" | "low" | "building" (not enough nights yet)
    var status: String
    var id: String { field.rawValue }
}

extension Store {
    static let baselineDays = 60
    static let baselineMinReadings = 7
    /// Readiness is about now: the newest reading stands in for "today" only while
    /// it is at most this many days old.
    private static let readinessFreshDays = 3

    /// The newest reading of a daily value, if recent enough to describe today.
    func latestRecent(_ value: (DailyEntry) -> Double?) -> (date: String, value: Double)? {
        guard let e = sortedDaily.last(where: { (value($0) ?? 0) > 0 }), let v = value(e), isRecent(e.date) else { return nil }
        return (e.date, v)
    }

    /// The personal range of a daily value over the `baselineDays` before `day`.
    func personalRange(_ value: (DailyEntry) -> Double?, before day: String,
                       transform: (Double) -> Double = { $0 }) -> PersonalRange? {
        guard let end = isoFormatter.date(from: day),
              let start = Calendar.current.date(byAdding: .day, value: -Store.baselineDays, to: end) else { return nil }
        let from = isoFormatter.string(from: start)
        let vals = sortedDaily.compactMap { e -> Double? in
            guard e.date >= from, e.date < day, let v = value(e), v.isFinite, v != 0 else { return nil }
            return transform(v)
        }
        guard vals.count >= Store.baselineMinReadings else { return nil }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let sd = (vals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(vals.count)).squareRoot()
        return PersonalRange(mean: mean, sd: sd, n: vals.count)
    }

    private func isRecent(_ date: String) -> Bool {
        guard let day = isoFormatter.date(from: date),
              let cutoff = Calendar.current.date(byAdding: .day, value: -Store.readinessFreshDays,
                                                 to: Calendar.current.startOfDay(for: Date())) else { return false }
        return day >= cutoff
    }

    /// The overnight vitals of the latest night, each against the user's range.
    /// A value is out of range beyond 2 SD (like Apple's Vitals app), with a floor
    /// per vital so a very steady baseline does not flag noise. SpO2 below 93 % is
    /// low whatever the baseline.
    /// The night of `date`, or the latest recent one when nil.
    func nightVitals(on date: String? = nil) -> [VitalReading] {
        memo("nightVitals|\(date ?? "latest")") { computeNightVitals(on: date) }
    }

    private func computeNightVitals(on date: String?) -> [VitalReading] {
        let specs: [(HealthField, floor: Double)] = [
            (.hrvSleep, 6), (.sleepHR, 3), (.respRate, 1), (.spo2, 2), (.wristTemp, 0.5)
        ]
        let entry = date.flatMap { dailyEntry($0) }
        return specs.compactMap { field, floor in
            let reading: (date: String, value: Double)?
            if let date {
                reading = entry?[field].flatMap { $0 > 0 ? (date, $0) : nil }
            } else {
                reading = latestRecent { $0[field] }
            }
            guard let reading else { return nil }
            let range = personalRange({ $0[field] }, before: reading.date)
            let band = max(2 * (range?.sd ?? 0), floor)
            var status = "building"
            if let range {
                status = reading.value > range.mean + band ? "high" : (reading.value < range.mean - band ? "low" : "ok")
            }
            if field == .spo2, reading.value < Store.spo2LowPercent { status = "low" }
            return VitalReading(field: field, value: reading.value, range: range, band: band, status: status)
        }
    }
    static let spo2LowPercent = 93.0

    /// Vitals that point to illness or heavy stress: breathing faster or a warmer
    /// wrist than usual, or low blood oxygen.
    func vitalsWarning() -> [HealthField] {
        nightVitals().filter {
            ($0.field == .respRate && $0.status == "high") || ($0.field == .wristTemp && $0.status == "high")
                || ($0.field == .spo2 && $0.status == "low")
        }.map(\.field)
    }
}

// MARK: - Sleep score (duration, efficiency, stages, regularity)
extension Store {
    /// 0-100 score of a night. Components without data drop out and the others
    /// are reweighted, so hours alone still give a score:
    ///   • duration 50 % — full at 7–9 h (NSF), 0 at 4 h and 12 h
    ///   • efficiency 15 % — asleep ÷ in bed, full from 85 % (Ohayon 2017), 0 at 65 %
    ///   • stages 20 % — deep 13–23 % and REM 20–25 % of the time asleep (deep
    ///     alone when the device reports no REM)
    ///   • regularity 15 % — SD of the sleep midpoint over a week, full ≤ 30 min, 0 ≥ 90 min
    static func sleepScore(hours: Double, inBedHours: Double? = nil, deepMin: Double? = nil,
                           remMin: Double? = nil, coreMin: Double? = nil, midpointSD: Double? = nil) -> Int {
        func ramp(_ x: Double, zeroAt a: Double, fullAt b: Double) -> Double { max(0, min(1, (x - a) / (b - a))) }
        func inBand(_ pct: Double, _ lo: Double, _ hi: Double) -> Double {
            pct < lo ? ramp(pct, zeroAt: 0, fullAt: lo) : ramp(pct, zeroAt: hi + 15, fullAt: hi)
        }
        var parts: [(score: Double, weight: Double)] = [
            (hours < 7 ? ramp(hours, zeroAt: 4, fullAt: 7) : ramp(hours, zeroAt: 12, fullAt: 9), 0.50)
        ]
        if let bed = inBedHours, bed > 0 {
            parts.append((ramp(min(1, hours / bed), zeroAt: 0.65, fullAt: 0.85), 0.15))
        }
        let deep = deepMin ?? 0, rem = remMin ?? 0
        let staged = deep + rem + (coreMin ?? 0)
        if staged > 0 {
            // Some devices (the Xiaomi band) stage deep and light sleep but never
            // REM: a night without any REM is their limit, not a bad night.
            let deepScore = inBand(deep / staged * 100, 13, 23)
            parts.append((rem > 0 ? (deepScore + inBand(rem / staged * 100, 20, 25)) / 2 : deepScore, 0.20))
        }
        if let sd = midpointSD { parts.append((ramp(sd, zeroAt: 90, fullAt: 30), 0.15)) }
        let weight = parts.reduce(0) { $0 + $1.weight }
        return Int((parts.reduce(0) { $0 + $1.score * $1.weight } / weight * 100).rounded())
    }

    func sleepScore(of e: DailyEntry, regularity: Double?) -> Int? {
        guard let h = e.sleepHours, h > 0 else { return nil }
        return Store.sleepScore(hours: h, inBedHours: e.inBedHours, deepMin: e.sleepDeepMin.map(Double.init),
                                remMin: e.sleepREMMin.map(Double.init), coreMin: e.sleepCoreMin.map(Double.init),
                                midpointSD: regularity)
    }

    /// SD in minutes of the sleep midpoint over the week ending on `date` (at
    /// least 4 nights), or nil. `byDate` lets the importer pass its working copy.
    func sleepRegularity(endingOn date: String, in byDate: [String: DailyEntry]? = nil) -> Double? {
        guard let end = isoFormatter.date(from: date) else { return nil }
        let lookup = byDate ?? Dictionary(daily.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let mids: [Double] = (0..<Store.regularityNights).compactMap { back in
            guard let d = Calendar.current.date(byAdding: .day, value: -back, to: end),
                  let e = lookup[isoFormatter.string(from: d)],
                  let s = e.sleepStartMin, let w = e.sleepEndMin else { return nil }
            return Double(s + w) / 2
        }
        guard mids.count >= Store.regularityMinNights else { return nil }
        let mean = mids.reduce(0, +) / Double(mids.count)
        return (mids.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(mids.count)).squareRoot()
    }
    private static let regularityNights = 7
    private static let regularityMinNights = 4
}

// MARK: - Sleep debt, social jet lag, HRV stability
extension Store {
    private static let sleepDebtNights = 14

    /// Hours of sleep owed over the last two weeks: each night short of the need
    /// adds, each long night pays back; never below zero. Counted against the
    /// person's own need (7–9 h for adults, 8 by default). Nights without data
    /// are skipped, not counted as zero. nil under 7 nights.
    func sleepDebt() -> Double? {
        let nights = recentNights(Store.sleepDebtNights).compactMap(\.sleepHours)
        guard nights.count >= Store.sleepDebtNights / 2 else { return nil }
        let need = prefs.sleepNeedHours
        return max(0, nights.reduce(0) { $0 + need - $1 })
    }

    /// Social jet lag (Wittmann, Roenneberg): how far the middle of the night
    /// moves between work days and free days (nights ending on Saturday or
    /// Sunday), in minutes, over the last four weeks.
    func socialJetLag() -> Double? {
        var free: [Double] = [], work: [Double] = []
        for e in recentNights(28) {
            guard let s = e.sleepStartMin, let w = e.sleepEndMin, let d = isoFormatter.date(from: e.date) else { continue }
            let weekday = Calendar.current.component(.weekday, from: d)   // 1 Sunday … 7 Saturday
            if weekday == 1 || weekday == 7 { free.append(Double(s + w) / 2) } else { work.append(Double(s + w) / 2) }
        }
        guard free.count >= 2, work.count >= 3 else { return nil }
        return abs(free.reduce(0, +) / Double(free.count) - work.reduce(0, +) / Double(work.count))
    }

    /// Week-to-week stability of HRV (Plews): the coefficient of variation of
    /// ln HRV measured asleep over the last 7 days, %. A rising CV is an early
    /// sign the body is not coping with the load. nil under 5 readings.
    func hrvStability() -> Double? {
        let values = recentNights(7).compactMap(\.hrvSleep).filter { $0 > 0 }.map { log($0) }
        guard values.count >= 5 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let sd = (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot()
        return mean > 0 ? sd / mean * 100 : nil
    }

    /// The entries of the last `n` days, today included.
    private func recentNights(_ n: Int) -> [DailyEntry] {
        let from = Calendar.current.date(byAdding: .day, value: -(n - 1), to: Date()).map { isoFormatter.string(from: $0) } ?? ""
        return sortedDaily.filter { $0.date >= from }
    }
}

// MARK: - Readiness (HRV + resting HR + sleep, checked against overnight vitals)
struct ReadinessResult {
    var score: Int?            // 0-100
    var samples: Int           // HRV baseline readings (drives the "building" card)
    /// "rest", "easy", "ready", or "none".
    var advice: String
    /// Which signals contributed today (e.g. ["hrv","hr","sleep"]) — for the card.
    var usedSignals: [String] = []
    /// Overnight vitals outside the personal range (breathing, temperature, SpO2).
    var warnings: [HealthField] = []
}

extension Store {
    /// Morning readiness. Each signal becomes a z-score against the user's own
    /// previous 60 days (positive = more recovered than usual), combined with
    /// fixed weights renormalized over the signals present:
    ///   • HRV measured asleep, ln-transformed — 0.45. Today's reading is blended
    ///     with the 7-day mean (0.6 / 0.4) to damp single-night noise (Plews,
    ///     Buchheit)
    ///   • resting HR (sleeping HR only when there is no resting HR) — 0.25,
    ///     lower = better
    ///   • the sleep score — 0.30, against an absolute anchor (75 = neutral)
    /// The composite maps to 0-100 as 50 + 20·z. An overnight vital out of range
    /// (fast breathing, warm wrist, low SpO2) caps the day at "easy".
    func readiness() -> ReadinessResult { memo("readiness") { computeReadiness() } }

    private func computeReadiness() -> ReadinessResult {
        var factors: [(name: String, z: Double, w: Double)] = []
        var hrvSamples = 0

        // Legacy RMSSD only when sleep HRV has nothing recent to say.
        let sleepHRV: (DailyEntry) -> Double? = { $0.hrvSleep }
        let hrv = latestRecent(sleepHRV) != nil ? sleepHRV : { $0.rmssd }
        if let latest = latestRecent(hrv), let range = personalRange(hrv, before: latest.date, transform: log) {
            hrvSamples = range.n
            var z = range.z(log(latest.value))
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))
                .map { isoFormatter.string(from: $0) } ?? today()
            let week = sortedDaily.filter { $0.date >= weekStart }
                .compactMap { e -> Double? in hrv(e).flatMap { $0 > 0 ? log($0) : nil } }
            if week.count >= 3 { z = 0.6 * z + 0.4 * range.z(week.reduce(0, +) / Double(week.count)) }
            factors.append(("hrv", clampZ(z), 0.45))
        } else if let n = personalRangeCount(hrv) {
            hrvSamples = n
        }

        let rest: (DailyEntry) -> Double? = { $0.restHR.map(Double.init) }
        let hr = latestRecent(rest) != nil ? rest : { $0.sleepHR.map(Double.init) }
        if let latest = latestRecent(hr), let range = personalRange(hr, before: latest.date) {
            factors.append(("hr", clampZ(-range.z(latest.value)), 0.25))
        }

        if let latest = latestRecent({ $0.sleep.map(Double.init) }) {
            factors.append(("sleep", clampZ((latest.value - Store.sleepNeutralScore) / Store.sleepScoreSpread), 0.30))
        }

        let warnings = vitalsWarning()
        guard !factors.isEmpty else {
            return ReadinessResult(score: nil, samples: hrvSamples, advice: "none", warnings: warnings)
        }
        let wSum = factors.reduce(0) { $0 + $1.w }
        let z = factors.reduce(0) { $0 + $1.z * $1.w } / wSum
        var score = Int(max(0, min(100, (50 + 20 * z).rounded())))
        if !warnings.isEmpty { score = min(score, Store.readinessReadyFrom - 1) }
        return ReadinessResult(score: score, samples: hrvSamples, advice: Store.readinessAdvice(score),
                               usedSignals: factors.map { $0.name }, warnings: warnings)
    }

    static let readinessRestBelow = 30
    static let readinessReadyFrom = 45
    static func readinessAdvice(_ score: Int) -> String {
        score < readinessRestBelow ? "rest" : (score < readinessReadyFrom ? "easy" : "ready")
    }
    private static let sleepNeutralScore = 75.0
    private static let sleepScoreSpread = 12.0

    private func clampZ(_ z: Double) -> Double { max(-3, min(3, z)) }

    /// Readings so far of a value, for the "building baseline" card.
    private func personalRangeCount(_ value: (DailyEntry) -> Double?) -> Int? {
        let n = daily.filter { (value($0) ?? 0) > 0 }.count
        return n > 0 ? n : nil
    }
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
        // Times ("30s", "45 sec") are not rep ranges; "8-10 reps" and "3 sets" are.
        if s.lowercased().range(of: #"\d\s*(s|sec|secs|seconds)\b"#, options: .regularExpression) != nil { return nil }
        let nums = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let lo = nums.first else { return nil }
        let hi = nums.count > 1 ? nums[1] : lo
        return (lo, max(lo, hi))
    }

    /// Double-progression for an exercise, enhanced with health and load context.
    /// Priority order:
    ///   1. Deload: HRV score < 30 (very low readiness) → always deload
    ///   2. Hold:   form below −30 % of fitness (load spike) → hold to reduce injury risk
    ///   3. Rep / load suggestion from last session vs target range
    ///   4. Consistency check: if the exercise was hit at the top of the range
    ///      in the two most recent sessions, confirm addLoad; a single session
    ///      at the top with a prior fall-short stays at addReps (not yet confirmed).
    /// What recovery data says about pushing today, or nil when it has nothing
    /// trustworthy to say. The form counts only once there is enough load history
    /// for the ratio to mean something — the same test the dashboard applies before
    /// showing it (one logged ride alone gives a ratio above 3).
    private func recoveryGate() -> ProgKind? {
        memo("recoveryGate") { () -> ProgKind? in
            if let score = readiness().score, score < Store.readinessRestBelow { return .deload }
            if loadDataStatus().reliable, let form = formPercent(), form < Store.overreachingBelowFormPercent { return .hold }
            return nil
        }
    }

    func progression(planId: String, exercise: String) -> ProgKind? {
        memo("progression|\(planId)|\(exercise)") { computeProgression(planId: planId, exercise: exercise) }
    }

    private func computeProgression(planId: String, exercise: String) -> ProgKind? {
        guard let plan = plan(planId),
              let pe = plan.exercises.first(where: { $0.name == exercise }) else { return nil }

        // Health gates — check readiness and load FIRST (apply to every kind).
        if let gate = recoveryGate() { return gate }

        // Timed (isometric) and interval (HIIT) exercises progress on time / rounds,
        // not on a rep range — route them to their own logic. Classic reps fall
        // through to the established double-progression below.
        switch pe.exKind {
        case .timed:    return timedProgression(planId: planId, exercise: exercise)
        case .interval: return intervalProgression(pe)
        case .reps:     break
        }

        guard let (lo, hi) = repRange(pe.reps) else { return nil }

        // Collect the last two sessions for this plan.
        let day = today()
        let planSessions = sessions
            .filter { $0.planId == planId && $0.date != day }
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
                // Two sessions at the ceiling → ready for more weight. One at the
                // ceiling after a shortfall is not confirmed yet: keep chasing reps.
                if let prevMin = prevReps.min() { return prevMin >= hi ? .addLoad : .addReps }
            }
        }
        return .addLoad   // only one session in history, give the benefit of the doubt
    }

    /// Progression for a timed (isometric) exercise. The target hold comes from the
    /// plan's `targetSec` (older plans kept it as text in `reps`, which
    /// `effectiveTargetSec` still parses); we compare the longest hold logged last
    /// time to that target. Reaching the target → ready to add load or extend the
    /// hold (.addLoad); below it → keep chasing time (.addReps, shown as "extend the
    /// hold" in the UI). The health gates already ran in the caller.
    private func timedProgression(planId: String, exercise: String) -> ProgKind? {
        guard let plan = plan(planId),
              let pe = plan.exercises.first(where: { $0.name == exercise }) else { return nil }
        let target: Double? = pe.effectiveTargetSec > 0 ? Double(pe.effectiveTargetSec) : nil
        let day = today()
        let planSessions = sessions
            .filter { $0.planId == planId && $0.date != day }
            .sorted { $0.date > $1.date }
        guard let last = planSessions.first,
              let ex = last.exercises.first(where: { $0.name == exercise }) else { return nil }
        let held = ex.maxSeconds
        guard held > 0 else { return nil }
        // Below target → extend the hold. At/above → ready for more load/time,
        // confirmed by the previous session so one strong hold doesn't over-trigger.
        guard let target, held >= target else { return .addReps }
        if planSessions.count >= 2,
           let prevEx = planSessions[1].exercises.first(where: { $0.name == exercise }),
           prevEx.maxSeconds > 0 {
            return prevEx.maxSeconds >= target ? .addLoad : .addReps
        }
        return .addLoad
    }

    /// Progression for an interval (HIIT) exercise — chase rounds. If last session's
    /// rounds met or beat the plan target, add a round (.addLoad); otherwise hold the
    /// current prescription and build consistency (.addReps = "add a round" in UI).
    private func intervalProgression(_ pe: PlanExercise) -> ProgKind? {
        guard let target = pe.rounds, target > 0 else { return nil }
        // Most recent logged rounds for this exercise across any prior session.
        let day = today()
        let recent = sessions
            .filter { $0.date != day }
            .sorted { $0.date > $1.date }
            .compactMap { s in s.exercises.first { $0.name == pe.name }?.rounds }
        guard let lastRounds = recent.first else { return nil }
        return lastRounds >= target ? .addLoad : .addReps
    }

}
