import Foundation

// MARK: - Energy periodization & nutrition targets
// Cut / maintain / bulk engine: BMR (Mifflin-St Jeor) -> TDEE -> goal-adjusted
// calorie target, macro split (ISSN ranges), carb cycling across high/low days,
// WHO salt cap, a body-weight trend engine, and a low-energy-availability check.

struct EnergyTargets {
    var bmr: Double
    var tdee: Double
    var target: Double          // daily kcal target
    var protein: Double         // g/day
    var fat: Double             // g/day
    var carbs: Double           // g/day (baseline)
    var carbHigh: Double        // g on training days
    var carbLow: Double         // g on rest days
    var saltMax: Double         // g/day (WHO)
    var rateTarget: Double      // kg/week (signed)
    var mode: GoalMode
}

struct TrendResult {
    var avgWeight: Double?       // smoothed current weight
    var ratePerWeek: Double?     // kg/week from regression
    var spanDays: Int
    var points: Int
    /// "ok" | "fast" | "slow" | "wrong" | "none"
    var status: String
    /// suggested daily kcal adjustment to get back on target
    var kcalAdjust: Int
}

struct LEAResult {
    var ea: Double?              // kcal per kg FFM per day
    /// "ok" | "warn" | "risk" | "none"
    var risk: String
}

extension Store {
    // --- Basal & total energy ------------------------------------------------
    func bmr(weight: Double? = nil) -> Double {
        let w = weight ?? lastWeight
        let cm = prefs.height * 100
        let age = Double(prefs.age ?? 30)
        let base = 10 * w + 6.25 * cm - 5 * age
        return prefs.sex_ == "f" ? base - 161 : base + 5
    }

    func tdee(weight: Double? = nil) -> Double {
        bmr(weight: weight) * prefs.activityLevel.multiplier
    }

    /// Target kg/week (signed). User value wins, else derived from goal mode.
    func targetRate() -> Double {
        if let r = prefs.weeklyRate, abs(r) > 0.001 { return r }
        return prefs.goal.defaultWeeklyPct / 100 * lastWeight
    }

    /// Fat-free mass from current body-fat %, if known.
    func fatFreeMass() -> Double? {
        guard let bf = currentBF, bf > 0, bf < 60 else { return nil }
        return lastWeight * (1 - bf / 100)
    }

    func energyTargets() -> EnergyTargets {
        let w = lastWeight
        let td = tdee(weight: w)
        let rate = targetRate()                         // kg/week
        let dailyDelta = rate * 7700 / 7                // ~7700 kcal per kg
        var target = td + dailyDelta
        target = max(target, bmr(weight: w) * 1.1)      // never below ~BMR
        let mode = prefs.goal

        // Macros: protein scaled by goal (higher in a cut to protect lean mass),
        // fat ~0.8 g/kg floor, carbs fill the remainder.
        let proteinPerKg: Double = mode == .cut ? 2.2 : (mode == .bulk ? 1.8 : 2.0)
        let protein = (proteinPerKg * w).rounded()
        let fat = max(0.6 * w, 0.8 * w).rounded()
        let carbsKcal = max(0, target - protein * 4 - fat * 9)
        let carbs = (carbsKcal / 4).rounded()

        // Carb cycling: shuttle carbs toward training days, keep the weekly mean.
        let carbHigh = (carbs * 1.30).rounded()
        let carbLow  = (carbs * 0.65).rounded()

        return EnergyTargets(
            bmr: bmr(weight: w).rounded(),
            tdee: td.rounded(),
            target: target.rounded(),
            protein: protein, fat: fat, carbs: carbs,
            carbHigh: carbHigh, carbLow: carbLow,
            saltMax: 5,                                 // WHO recommendation
            rateTarget: (rate * 100).rounded() / 100,
            mode: mode
        )
    }

    // --- Body-weight trend engine -------------------------------------------
    /// Linear regression over the last `days` of weigh-ins to estimate the real
    /// rate of change (kg/week), independent of daily noise.
    func weightTrend(days: Int = 21) -> TrendResult {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
        let pts = sortedDaily.compactMap { e -> (Double, Double)? in
            guard let w = e.weight, let d = isoFormatter.date(from: e.date), d >= cutoff else { return nil }
            let x = d.timeIntervalSince(cutoff) / 86400         // day index
            return (x, w)
        }
        guard pts.count >= 4 else {
            return TrendResult(avgWeight: lastWeight, ratePerWeek: nil, spanDays: days, points: pts.count, status: "none", kcalAdjust: 0)
        }
        // least-squares slope (kg/day)
        let n = Double(pts.count)
        let sx = pts.reduce(0) { $0 + $1.0 }
        let sy = pts.reduce(0) { $0 + $1.1 }
        let sxx = pts.reduce(0) { $0 + $1.0 * $1.0 }
        let sxy = pts.reduce(0) { $0 + $1.0 * $1.1 }
        let denom = n * sxx - sx * sx
        guard denom != 0 else {
            return TrendResult(avgWeight: lastWeight, ratePerWeek: nil, spanDays: days, points: pts.count, status: "none", kcalAdjust: 0)
        }
        let slope = (n * sxy - sx * sy) / denom              // kg/day
        let intercept = (sy - slope * sx) / n
        let lastX = pts.map { $0.0 }.max() ?? 0
        let avg = intercept + slope * lastX                  // fitted current weight
        let rate = slope * 7                                 // kg/week

        let target = targetRate()
        let status: String
        var adjust = 0
        let band = max(0.1, abs(target) * 0.4)               // tolerance kg/week
        if target < 0 {                                      // cutting
            if rate > 0.05 { status = "wrong"; adjust = -250 }
            else if rate > target + band { status = "slow"; adjust = -150 }
            else if rate < target - band { status = "fast"; adjust = 150 }
            else { status = "ok" }
        } else if target > 0 {                               // bulking
            if rate < -0.05 { status = "wrong"; adjust = 250 }
            else if rate < target - band { status = "slow"; adjust = 150 }
            else if rate > target + band { status = "fast"; adjust = -150 }
            else { status = "ok" }
        } else {                                             // maintenance
            if abs(rate) > band { status = abs(rate) > 0 ? "fast" : "ok"; adjust = rate > 0 ? -150 : 150 }
            else { status = "ok" }
        }
        return TrendResult(avgWeight: (avg * 10).rounded() / 10,
                           ratePerWeek: (rate * 100).rounded() / 100,
                           spanDays: days, points: pts.count, status: status, kcalAdjust: adjust)
    }

    // --- Low energy availability --------------------------------------------
    /// EA = (intake - exercise energy) / FFM, averaged over the last 7 days.
    /// <30 kcal/kg FFM/day = clinical LEA risk; 30-45 a caution under heavy load.
    func energyAvailability() -> LEAResult {
        guard let ffm = fatFreeMass(), ffm > 0 else { return LEAResult(ea: nil, risk: "none") }
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -7, to: Date())!
        let intakes = daily.compactMap { e -> Int? in
            guard let k = e.kcal, k > 0, let d = isoFormatter.date(from: e.date), d >= cutoff else { return nil }
            return k
        }
        guard !intakes.isEmpty else { return LEAResult(ea: nil, risk: "none") }
        let avgIntake = Double(intakes.reduce(0, +)) / Double(intakes.count)
        let exDays = sessions.filter { (isoFormatter.date(from: $0.date) ?? .distantPast) >= cutoff }
        let exEnergy = exDays.reduce(0.0) { $0 + Double($1.caloriesManual ?? estimateCalories($1)) }
        let ea = (avgIntake - exEnergy / 7) / ffm
        let risk: String
        if ea < 30 { risk = "risk" }
        else if ea < 45 { risk = "warn" }
        else { risk = "ok" }
        return LEAResult(ea: (ea * 10).rounded() / 10, risk: risk)
    }
}
