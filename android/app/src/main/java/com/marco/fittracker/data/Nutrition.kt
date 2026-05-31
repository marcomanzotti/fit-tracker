package com.marco.fittracker.data

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.abs

// MARK: - Energy periodization & nutrition targets (ports iOS Nutrition.swift).
// Cut/maintain/bulk: BMR (Mifflin-St Jeor) -> TDEE -> goal-adjusted target, macro
// split (ISSN), carb cycling, WHO salt cap, weight-trend regression, LEA check.

data class EnergyTargets(
    val bmr: Double, val tdee: Double, val target: Double,
    val protein: Double, val fat: Double, val carbs: Double,
    val carbHigh: Double, val carbLow: Double, val saltMax: Double,
    val rateTarget: Double, val mode: GoalMode
)

data class TrendResult(
    val avgWeight: Double?, val ratePerWeek: Double?, val spanDays: Int,
    val points: Int, val status: String, val kcalAdjust: Int
)

data class LEAResult(val ea: Double?, val risk: String)

fun Store.bmr(weight: Double? = null): Double {
    val w = weight ?: lastWeight
    val cm = prefs.height * 100
    val age = (prefs.age ?: 30).toDouble()
    val base = 10 * w + 6.25 * cm - 5 * age
    return if (prefs.sexCode == "f") base - 161 else base + 5
}

fun Store.tdee(weight: Double? = null): Double = bmr(weight) * prefs.activityLevel.multiplier

fun Store.targetRate(): Double {
    prefs.weeklyRate?.let { if (abs(it) > 0.001) return it }
    return prefs.goal.defaultWeeklyPct / 100 * lastWeight
}

fun Store.fatFreeMass(): Double? {
    val bf = currentBF ?: return null
    if (bf <= 0 || bf >= 60) return null
    return lastWeight * (1 - bf / 100)
}

fun Store.energyTargets(): EnergyTargets {
    val w = lastWeight
    val td = tdee(w)
    val rate = targetRate()
    val dailyDelta = rate * 7700 / 7
    var target = td + dailyDelta
    target = maxOf(target, bmr(w) * 1.1)
    val mode = prefs.goal
    val proteinPerKg = if (mode == GoalMode.CUT) 2.2 else if (mode == GoalMode.BULK) 1.8 else 2.0
    val protein = Math.round(proteinPerKg * w).toDouble()
    val fat = Math.round(0.8 * w).toDouble()
    val carbsKcal = maxOf(0.0, target - protein * 4 - fat * 9)
    val carbs = Math.round(carbsKcal / 4).toDouble()
    return EnergyTargets(
        bmr = Math.round(bmr(w)).toDouble(),
        tdee = Math.round(td).toDouble(),
        target = Math.round(target).toDouble(),
        protein = protein, fat = fat, carbs = carbs,
        carbHigh = Math.round(carbs * 1.30).toDouble(),
        carbLow = Math.round(carbs * 0.65).toDouble(),
        saltMax = 5.0,
        rateTarget = Math.round(rate * 100.0) / 100.0,
        mode = mode
    )
}

fun Store.weightTrend(days: Int = 21): TrendResult {
    val cutoff = LocalDate.now().minusDays(days.toLong())
    val pts = sortedDaily.mapNotNull { e ->
        val w = e.weight ?: return@mapNotNull null
        val d = runCatching { LocalDate.parse(e.date) }.getOrNull() ?: return@mapNotNull null
        if (d.isBefore(cutoff)) null else ChronoUnit.DAYS.between(cutoff, d).toDouble() to w
    }
    if (pts.size < 4)
        return TrendResult(lastWeight, null, days, pts.size, "none", 0)
    val n = pts.size.toDouble()
    val sx = pts.sumOf { it.first }
    val sy = pts.sumOf { it.second }
    val sxx = pts.sumOf { it.first * it.first }
    val sxy = pts.sumOf { it.first * it.second }
    val denom = n * sxx - sx * sx
    if (denom == 0.0) return TrendResult(lastWeight, null, days, pts.size, "none", 0)
    val slope = (n * sxy - sx * sy) / denom
    val intercept = (sy - slope * sx) / n
    val lastX = pts.maxOf { it.first }
    val avg = intercept + slope * lastX
    val rate = slope * 7
    val target = targetRate()
    var status = "ok"
    var adjust = 0
    val band = maxOf(0.1, abs(target) * 0.4)
    if (target < 0) {
        if (rate > 0.05) { status = "wrong"; adjust = -250 }
        else if (rate > target + band) { status = "slow"; adjust = -150 }
        else if (rate < target - band) { status = "fast"; adjust = 150 }
        else status = "ok"
    } else if (target > 0) {
        if (rate < -0.05) { status = "wrong"; adjust = 250 }
        else if (rate < target - band) { status = "slow"; adjust = 150 }
        else if (rate > target + band) { status = "fast"; adjust = -150 }
        else status = "ok"
    } else {
        if (abs(rate) > band) { status = "fast"; adjust = if (rate > 0) -150 else 150 }
        else status = "ok"
    }
    return TrendResult(
        Math.round(avg * 10.0) / 10.0,
        Math.round(rate * 100.0) / 100.0,
        days, pts.size, status, adjust
    )
}

fun Store.energyAvailability(): LEAResult {
    val ffm = fatFreeMass() ?: return LEAResult(null, "none")
    if (ffm <= 0) return LEAResult(null, "none")
    val cutoff = LocalDate.now().minusDays(7)
    val intakes = daily.mapNotNull { e ->
        val k = e.kcal ?: return@mapNotNull null
        val d = runCatching { LocalDate.parse(e.date) }.getOrNull() ?: return@mapNotNull null
        if (k > 0 && !d.isBefore(cutoff)) k else null
    }
    if (intakes.isEmpty()) return LEAResult(null, "none")
    val avgIntake = intakes.sum().toDouble() / intakes.size
    val exDays = sessions.filter {
        val d = runCatching { LocalDate.parse(it.date) }.getOrNull()
        d != null && !d.isBefore(cutoff)
    }
    val exEnergy = exDays.sumOf { (it.caloriesManual ?: estimateCalories(it)).toDouble() }
    val ea = (avgIntake - exEnergy / 7) / ffm
    val risk = if (ea < 30) "risk" else if (ea < 45) "warn" else "ok"
    return LEAResult(Math.round(ea * 10.0) / 10.0, risk)
}
