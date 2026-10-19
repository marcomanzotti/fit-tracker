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
    var mode: GoalMode
    var adaptive: Bool          // true when TDEE was learned from logged data
}

struct TrendResult {
    var ratePerWeek: Double?     // kg/week from regression
    var points: Int
    /// "ok" | "fast" | "slow" | "wrong" | "drift" (maintenance) | "none"
    var status: String
    /// suggested daily kcal adjustment to get back on target
    var kcalAdjust: Int
}

struct LEAResult {
    var ea: Double?              // kcal per kg FFM per day
    /// "ok" | "warn" | "risk" | "none"
    var risk: String
}

/// Adherence signals over the last ~2-3 weeks that drive a smarter calorie
/// adjustment than weight alone: how consistently nutrition is logged, average
/// steps, and training volume.
struct AdherenceResult {
    var loggingPct: Double       // 0...1 share of days with kcal logged
    var avgSteps: Int?           // average daily steps (if any logged)
    var sessions: Int            // workouts in the window
    var avgIntake: Int?          // average logged kcal
    var days: Int                // window length
    /// "ok" | "low_logging" | "none"
    var status: String
}

extension Store {
    /// Fibre advice: 14 g for every 1000 kcal eaten (US Dietary Guidelines).
    static let fiberPer1000kcal = 14.0

    // --- Basal & total energy ------------------------------------------------
    /// Katch-McArdle (370 + 21.6 × lean mass) once body fat is known, which is
    /// more precise than Mifflin-St Jeor for muscular and for lean builds; Mifflin
    /// otherwise.
    func bmr(weight: Double? = nil) -> Double {
        let w = weight ?? lastWeight
        if let bf = currentBF, bf > 0, bf < 60, w > 0 { return 370 + 21.6 * w * (1 - bf / 100) }
        let cm = prefs.height * 100
        let age = Double(prefs.age ?? 30)
        let base = 10 * w + 6.25 * cm - 5 * age
        return prefs.sex_ == "f" ? base - 161 : base + 5
    }

    func tdee(weight: Double? = nil) -> Double {
        bmr(weight: weight) * prefs.activityLevel.multiplier
    }

    /// Data-driven ("adaptive") maintenance estimate: when there are enough days
    /// of logged intake AND a reliable weight trend, real maintenance ≈ average
    /// intake − the energy implied by the measured rate of weight change. This is
    /// the gold-standard adjustment: it learns your true expenditure from your
    /// own data instead of trusting the activity multiplier. Returns nil until
    /// there's enough adherence to be trustworthy.
    func adaptiveTDEE(days: Int = 21) -> Double? { memo("adaptiveTDEE|\(days)") { computeAdaptiveTDEE(days: days) } }

    private func computeAdaptiveTDEE(days: Int) -> Double? {
        let tr = weightTrend(days: days)
        guard let rate = tr.ratePerWeek, tr.points >= 8 else { return nil }
        let intakes = recentIntakes(days: days)
        guard intakes.count >= 8 else { return nil }
        let avgIntake = Double(intakes.reduce(0, +)) / Double(intakes.count)
        let dailyChangeKcal = rate * 7700 / 7          // energy implied by the trend
        // Under-logged days or three weeks of scale noise can push the raw number
        // below BMR or far above any plausible expenditure; keep it physiological.
        let estimate = avgIntake - dailyChangeKcal
        return min(max(estimate, bmr()), tdee() * 1.5).rounded()
    }

    /// Energy eaten (kcal) on each of the last `days` days that has nutrition logged
    /// in any form: quick total, per meal or per food. Today is left out: a
    /// breakfast logged at 9 am is not what the day will add up to.
    private func recentIntakes(days: Int) -> [Int] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let from = isoFormatter.string(from: cutoff), todayKey = today()
        return daily.compactMap { e in
            guard e.date >= from, e.date != todayKey, e.totalKcal > 0 else { return nil }
            return e.totalKcal
        }
    }

    /// Adherence over a 2-3 week window: logging consistency, steps, volume.
    func adherence(days: Int = 14) -> AdherenceResult { memo("adherence|\(days)") { computeAdherence(days: days) } }

    private func computeAdherence(days: Int) -> AdherenceResult {
        let cal = Calendar.current
        let cutoff = isoFormatter.string(from: cal.date(byAdding: .day, value: -days, to: Date())!)
        func recent(_ ds: String) -> Bool { ds >= cutoff }
        let logged = recentIntakes(days: days)
        let stepVals = daily.compactMap { e -> Int? in recent(e.date) ? (e.steps.flatMap { $0 > 0 ? $0 : nil }) : nil }
        let sess = sessions.filter { recent($0.date) }.count
        let loggingPct = Double(logged.count) / Double(days)
        let avgSteps = stepVals.isEmpty ? nil : stepVals.reduce(0, +) / stepVals.count
        let avgIntake = logged.isEmpty ? nil : logged.reduce(0, +) / logged.count
        let status: String
        if logged.isEmpty { status = "none" }
        else if loggingPct < 0.5 { status = "low_logging" }
        else { status = "ok" }
        return AdherenceResult(loggingPct: loggingPct, avgSteps: avgSteps, sessions: sess,
                               avgIntake: avgIntake, days: days, status: status)
    }

    /// Target kg/week, signed by the goal: a cut always loses, a bulk always gains,
    /// maintenance holds. The pace typed by the user wins over the goal's default.
    func targetRate() -> Double {
        let goal = prefs.goal
        guard goal != .maintain else { return 0 }
        if let r = prefs.weeklyRate, abs(r) > 0.001 { return goal == .cut ? -abs(r) : abs(r) }
        return goal.defaultWeeklyPct / 100 * lastWeight
    }

    /// Fat-free mass from current body-fat %, if known.
    func fatFreeMass() -> Double? {
        guard let bf = currentBF, bf > 0, bf < 60 else { return nil }
        return lastWeight * (1 - bf / 100)
    }

    func energyTargets() -> EnergyTargets { memo("energyTargets") { computeEnergyTargets() } }

    private func computeEnergyTargets() -> EnergyTargets {
        let w = lastWeight
        // Prefer the data-driven maintenance once enough has been logged; this is
        // the adherence-driven part: the target follows your real expenditure.
        let adaptive = adaptiveTDEE()
        let td = adaptive ?? tdee(weight: w)
        let rate = targetRate()                         // kg/week
        let dailyDelta = rate * 7700 / 7                // ~7700 kcal per kg
        var target = td + dailyDelta
        target = max(target, bmr(weight: w) * 1.1)      // never below ~BMR
        let mode = prefs.goal

        // Macros: protein scaled by goal (higher in a cut to protect lean mass),
        // fat ~0.8 g/kg floor, carbs fill the remainder.
        let proteinPerKg: Double = mode == .cut ? 2.2 : (mode == .bulk ? 1.8 : 2.0)
        // 2.2 g per kg of a 110 kg person with 35 % body fat is 242 g, far above
        // what the lean tissue can use: when fat is high, the target follows lean
        // mass (scaled so that it matches body weight at about 15 % fat).
        let highFat = (currentBF ?? 0) > (prefs.sex_ == "f" ? 32 : 25)
        let proteinBase = highFat ? (fatFreeMass() ?? w) / 0.85 : w
        let protein = (proteinPerKg * proteinBase).rounded()
        let fat = (0.8 * w).rounded()              // ~0.8 g/kg essential-fat floor
        let carbsKcal = max(0, target - protein * 4 - fat * 9)
        let carbs = (carbsKcal / 4).rounded()

        // Carb cycling: training days get twice the carbs of the others, and the
        // two values are set so that the week's average is the target, whatever
        // the number of training days (a fixed ×1.30 / ×0.65 only did at 3.8).
        let trainingDays = prefs.hasSchedule
            ? Double(prefs.weekSchedule.filter { !$0.isEmpty && $0 != "rest" }.count)
            : Double(prefs.trainingDays ?? 4)
        let low = trainingDays > 0 && trainingDays < 7 ? 7 * carbs / (trainingDays + 7) : carbs
        let carbHigh = (trainingDays > 0 && trainingDays < 7 ? 2 * low : carbs).rounded()
        let carbLow  = low.rounded()

        return EnergyTargets(
            bmr: bmr(weight: w).rounded(),
            tdee: td.rounded(),
            target: target.rounded(),
            protein: protein, fat: fat, carbs: carbs,
            carbHigh: carbHigh, carbLow: carbLow,
            saltMax: 5,                                 // WHO recommendation
            mode: mode,
            adaptive: adaptive != nil
        )
    }

    // --- Body-weight trend engine -------------------------------------------
    /// Linear regression over the last `days` of weigh-ins to estimate the real
    /// rate of change (kg/week), independent of daily noise.
    func weightTrend(days: Int = 21) -> TrendResult { memo("weightTrend|\(days)") { computeWeightTrend(days: days) } }

    private func computeWeightTrend(days: Int) -> TrendResult {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
        let pts = sortedDaily.compactMap { e -> (Double, Double)? in
            guard let w = e.weight, let d = isoFormatter.date(from: e.date), d >= cutoff else { return nil }
            let x = d.timeIntervalSince(cutoff) / 86400         // day index
            return (x, w)
        }
        guard pts.count >= 4 else {
            return TrendResult(ratePerWeek: nil, points: pts.count, status: "none", kcalAdjust: 0)
        }
        // least-squares slope (kg/day)
        guard let fit = linearFit(pts) else {
            return TrendResult(ratePerWeek: nil, points: pts.count, status: "none", kcalAdjust: 0)
        }
        let rate = fit.slope * 7                             // kg/week

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
            if abs(rate) > band { status = "drift"; adjust = rate > 0 ? -150 : 150 }
            else { status = "ok" }
        }
        return TrendResult(ratePerWeek: (rate * 100).rounded() / 100,
                           points: pts.count, status: status, kcalAdjust: adjust)
    }

    // --- Low energy availability --------------------------------------------
    /// EA = (intake - exercise energy) / FFM, averaged over the last 7 days.
    /// <30 kcal/kg FFM/day = clinical LEA risk; 30-45 a caution under heavy load.
    func energyAvailability() -> LEAResult { memo("lea") { computeEnergyAvailability() } }

    private func computeEnergyAvailability() -> LEAResult {
        guard let ffm = fatFreeMass(), ffm > 0 else { return LEAResult(ea: nil, risk: "none") }
        let window = 7
        let intakes = recentIntakes(days: window)
        guard !intakes.isEmpty,
              let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: Date())
        else { return LEAResult(ea: nil, risk: "none") }
        let avgIntake = Double(intakes.reduce(0, +)) / Double(intakes.count)
        let from = isoFormatter.string(from: cutoff)
        let exDays = sessions.filter { $0.date >= from && $0.date != today() }
        let exEnergy = exDays.reduce(0.0) { $0 + Double($1.caloriesManual ?? estimateCalories($1)) }
        let ea = (avgIntake - exEnergy / 7) / ffm
        let risk: String
        if ea < 30 { risk = "risk" }
        else if ea < 45 { risk = "warn" }
        else { risk = "ok" }
        return LEAResult(ea: (ea * 10).rounded() / 10, risk: risk)
    }
}

// MARK: - Logging food (moved from Store.swift)
extension Store {
    // MARK: Nutrition (quick total OR per-meal, for any date)
    /// Look up a day's entry (nil if never logged). A calendar asks for thirty of
    /// them per render: one lookup table per change instead of a scan each.
    func dailyEntry(_ date: String) -> DailyEntry? {
        memo("dailyByDate") { Dictionary(daily.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first }) }[date]
    }

    /// Upsert a day's entry by mutation, for an arbitrary (past) date: one change,
    /// and a new day lands in date order.
    func upsertDaily(_ date: String, _ mutate: (inout DailyEntry) -> Void) {
        var list = daily
        if let i = list.firstIndex(where: { $0.date == date }) {
            mutate(&list[i])
        } else {
            var e = DailyEntry(date: date)
            mutate(&e)
            list.insert(e, at: list.firstIndex { $0.date > date } ?? list.count)
        }
        daily = list
    }

    /// Quick one-tap mode: a single daily total (clears any per-meal breakdown so
    /// the total is unambiguous).
    func saveNutritionTotal(date: String, kcal: Int?, protein: Double?, carbs: Double?, fat: Double?) {
        upsertDaily(date) { e in
            e.kcal = kcal; e.protein = protein; e.carbs = carbs; e.fat = fat
            e.meals = nil
        }
    }

    /// Empties what was eaten on a day and returns the day as it was, for Undo.
    func clearNutrition(date: String) -> DailyEntry? {
        let before = dailyEntry(date)
        upsertDaily(date) { e in
            e.kcal = nil; e.protein = nil; e.carbs = nil; e.fat = nil; e.salt = nil
            e.meals = nil; e.foods = nil
        }
        return before
    }
    /// Undo of `clearNutrition`: only the food comes back, the rest of the day stays as it is now.
    func restoreNutrition(_ before: DailyEntry) {
        upsertDaily(before.date) { e in
            e.kcal = before.kcal; e.protein = before.protein; e.carbs = before.carbs; e.fat = before.fat
            e.salt = before.salt; e.meals = before.meals; e.foods = before.foods
        }
    }

    /// Per-meal mode: individual meals that auto-sum to the day total. Empty meals
    /// are dropped; the quick-total fields are cleared so `totalKcal` uses the sum.
    func saveNutritionMeals(date: String, meals: [String: MealEntry]) {
        let clean = meals.filter { !$0.value.isEmpty }
        upsertDaily(date) { e in
            e.meals = clean.isEmpty ? nil : clean
            e.kcal = nil; e.protein = nil; e.carbs = nil; e.fat = nil
        }
        // Float any foods used in a meal to the top of the picker.
        for m in clean.values { for l in (m.foods ?? []) { if let fid = l.foodId { touchFood(fid) } } }
    }

    // MARK: Saved food list (local, per-100 macros)
    /// Saved foods, most-recently-used first (then alphabetical) for the picker.
    func recentFoods() -> [FoodItem] {
        foods.sorted {
            ($0.lastUsed ?? "") != ($1.lastUsed ?? "")
                ? ($0.lastUsed ?? "") > ($1.lastUsed ?? "")
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    func food(barcode: String) -> FoodItem? { foods.first { $0.barcode == barcode } }

    /// Insert or update a saved food (matched by id).
    @discardableResult
    func saveFood(_ f: FoodItem) -> FoodItem {
        if let i = foods.firstIndex(where: { $0.id == f.id }) { foods[i] = f }
        else { foods.append(f) }
        return f
    }
    func deleteFood(_ id: String) { foods.removeAll { $0.id == id } }
    /// Undo of a delete: back at its old position (or the end, if the list shrank).
    func restoreFood(_ food: FoodItem, at index: Int) {
        guard !foods.contains(where: { $0.id == food.id }) else { return }
        foods.insert(food, at: min(max(0, index), foods.count))
    }
    /// Mark a food as used today so it floats to the top of the picker.
    func touchFood(_ id: String) {
        guard let i = foods.firstIndex(where: { $0.id == id }) else { return }
        foods[i].lastUsed = today()
    }

    /// Replace the day-level individual foods for a date (food-by-food logging
    /// without a meal). Empty list clears them.
    func saveDayFoods(date: String, foods logs: [FoodLog]) {
        upsertDaily(date) { e in
            e.foods = logs.isEmpty ? nil : logs
            // Day-level food logging is its own mode: clear the quick total and
            // the per-meal breakdown so the day total is unambiguous.
            if !logs.isEmpty {
                e.kcal = nil; e.protein = nil; e.carbs = nil; e.fat = nil
                e.meals = nil
            }
        }
        for l in logs { if let fid = l.foodId { touchFood(fid) } }
    }

    /// Series of logged-intake days for the nutrition charts (most recent `days`).
    struct NutPoint: Identifiable {
        var day: Date; var kcal: Int
        var protein: Double; var carbs: Double; var fat: Double
        var id: Date { day }
    }

    /// Weekly-averaged nutrition series for the charts. Mirrors `metricSeries`:
    /// groups logged days into ISO-week buckets and averages each macro, so the
    /// nutrition charts show weekly means — consistent with every other overview
    /// chart (sleep, steps, weight…) instead of noisy day-by-day values.
    func nutritionWeeklySeries(months: Int = ChartGranularity.week.months) -> [NutPoint] {
        func weekly(_ value: @escaping (DailyEntry) -> Double) -> [Date: Double] {
            let points = metricSeries({ $0.hasNutrition ? value($0) : nil }, granularity: .week, months: months)
            return Dictionary(uniqueKeysWithValues: points.map { ($0.day, $0.value) })
        }
        let kcal = weekly { Double($0.totalKcal) }
        let protein = weekly(\.totalProtein), carbs = weekly(\.totalCarbs), fat = weekly(\.totalFat)
        return kcal.keys.sorted().map { day in
            NutPoint(day: day, kcal: Int((kcal[day] ?? 0).rounded()),
                     protein: protein[day] ?? 0, carbs: carbs[day] ?? 0, fat: fat[day] ?? 0)
        }
    }


    // MARK: Saved recipes
    /// All recipes sorted most-recently-used first, then alphabetically.
    func recentRecipes() -> [Recipe] {
        recipes.sorted {
            ($0.lastUsed ?? "") != ($1.lastUsed ?? "")
                ? ($0.lastUsed ?? "") > ($1.lastUsed ?? "")
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    @discardableResult
    func saveRecipe(_ r: Recipe) -> Recipe {
        if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r }
        else { recipes.append(r) }
        return r
    }

    func deleteRecipe(_ id: String) { recipes.removeAll { $0.id == id } }
    func restoreRecipe(_ recipe: Recipe, at index: Int) {
        guard !recipes.contains(where: { $0.id == recipe.id }) else { return }
        recipes.insert(recipe, at: min(max(0, index), recipes.count))
    }
}
