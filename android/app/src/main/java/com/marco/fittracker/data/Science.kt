package com.marco.fittracker.data

import java.time.LocalDate
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.sqrt

// MARK: - Internal-load & recovery science (ports the iOS Science.swift).
// All metrics come from manually entered data (RPE, duration, avg HR, RMSSD).
// DFA-alpha1 / true beat-to-beat RMSSD need a BLE chest strap and are stubbed.

// MARK: TRIMP (Banister, sex-weighted)
fun Store.trimp(s: WorkoutSession): Double? {
    val dur = s.durationMin ?: return null
    val hr = s.avgHR ?: return null
    if (dur <= 0 || hr <= 0) return null
    val rest = prefs.restHRorDefault.toDouble()
    val mx = (s.maxHRSes ?: prefs.estMaxHR).toDouble()
    if (mx <= rest) return null
    val hrr = ((hr - rest) / (mx - rest)).coerceIn(0.0, 1.0)
    val y = if (prefs.sexCode == "f") 1.67 else 1.92
    return dur * hrr * 0.64 * exp(y * hrr)
}

/** Strictly measured internal load = TRIMP (duration + avg HR). Null when no avg
 *  HR was entered, so ACWR / monotony / strain never fabricate load from set
 *  counts. We intentionally do NOT fall back to the old sRPE (duration × RPE):
 *  the RPE input was removed in v4, so any sRPE today is legacy data that would
 *  inflate load even with no HR — the "load looks extremely high without HR"
 *  surprise. TRIMP is now the single source of internal load. */
fun Store.measuredLoad(s: WorkoutSession): Double? = trimp(s)
fun Store.hasMeasuredLoad(s: WorkoutSession): Boolean = measuredLoad(s) != null

/** Sum of session TRIMP in a Monday-based week (offset 0 = current week). */
fun Store.weeklyTrimp(offset: Int = 0): Double {
    val now = LocalDate.now()
    val mon = now.minusDays((now.dayOfWeek.value - 1).toLong()).minusDays(offset * 7L)
    val sun = mon.plusDays(7)
    var total = 0.0
    for (s in sessions) {
        val v = trimp(s) ?: continue
        val d = runCatching { LocalDate.parse(s.date) }.getOrNull() ?: continue
        if (!d.isBefore(mon) && d.isBefore(sun)) total += v
    }
    return total
}

/** TRIMP of the most recent session that has one (null until HR is logged). */
fun Store.lastSessionTrimp(): Pair<Double, String>? {
    for (s in sessions.sortedByDescending { it.date }) {
        trimp(s)?.let { return it to s.date }
    }
    return null
}

/** True once any session carries the avg HR needed to compute TRIMP. */
fun Store.hasAnyTrimp(): Boolean = sessions.any { trimp(it) != null }

data class LoadPoint(val date: String, val load: Double)
data class ACWRResult(val ratio: Double?, val acute: Double, val chronic: Double, val zone: String)

private fun ewma(values: List<Double>, days: Int): Double {
    if (values.isEmpty()) return 0.0
    val lambda = 2.0 / (days + 1.0)
    var e = values[0]
    for (i in 1 until values.size) e = values[i] * lambda + e * (1 - lambda)
    return e
}

/** Daily summed measured load for the last `days`, oldest -> newest, zero-filled. */
fun Store.dailyLoadSeries(days: Int): List<LoadPoint> {
    val map = HashMap<String, Double>()
    for (s in sessions) measuredLoad(s)?.let { map[s.date] = (map[s.date] ?: 0.0) + it }
    val out = ArrayList<LoadPoint>()
    var d = LocalDate.now()
    repeat(days) {
        val key = d.toString()
        out.add(LoadPoint(key, map[key] ?: 0.0))
        d = d.minusDays(1)
    }
    return out.reversed()
}

fun Store.acwr(): ACWRResult {
    val series = dailyLoadSeries(42).map { it.load }
    if (series.none { it > 0 }) return ACWRResult(null, 0.0, 0.0, "none")
    val acute = ewma(series, 7)
    val chronic = ewma(series, 28)
    if (chronic <= 0) return ACWRResult(null, acute, chronic, "none")
    val r = acute / chronic
    val zone = if (r < 0.8) "low" else if (r < 1.3) "ok" else "high"
    return ACWRResult(Math.round(r * 100.0) / 100.0, acute, chronic, zone)
}

data class WeekLoad(
    val total: Double, val mean: Double, val sd: Double,
    val monotony: Double?, val strain: Double?, val sessions: Int
)

fun Store.weekLoad(offset: Int): WeekLoad {
    val now = LocalDate.now()
    val mon = now.minusDays((now.dayOfWeek.value - 1).toLong()).minusDays(offset * 7L)
    val daily = DoubleArray(7)
    var count = 0
    val trainingDays = HashSet<Int>()
    for (s in sessions) {
        val l = measuredLoad(s) ?: continue
        val d = runCatching { LocalDate.parse(s.date) }.getOrNull() ?: continue
        val diff = java.time.temporal.ChronoUnit.DAYS.between(mon, d).toInt()
        if (diff in 0..6) { daily[diff] += l; count++; trainingDays.add(diff) }
    }
    val total = daily.sum()
    val mean = total / 7
    val variance = daily.sumOf { (it - mean) * (it - mean) } / 7
    val sd = sqrt(variance)
    // Monotony/strain need >= 2 training days to be meaningful.
    val monotony = if (sd > 0 && trainingDays.size >= 2) mean / sd else null
    val strain = monotony?.let { total * it }
    return WeekLoad(total, mean, sd, monotony, strain, count)
}

data class ReadinessResult(
    val score: Int?, val lnToday: Double?, val baseline: Double?,
    val sd: Double?, val samples: Int, val advice: String
)

fun Store.readiness(): ReadinessResult {
    // Prefer manual RMSSD; fall back to imported SDNN when RMSSD is sparse. The
    // readiness math is a personal-baseline z-score of ln(HRV), so either metric
    // works as long as one source is used consistently.
    val rmssdMap = HashMap<String, Double>()
    for (s in sessions) s.rmssd?.let { if (it > 0) rmssdMap[s.date] = it }
    for (d in daily) d.rmssd?.let { if (it > 0) rmssdMap[d.date] = it }
    val sdnnMap = HashMap<String, Double>()
    for (d in daily) d.hrvSDNN?.let { if (it > 0) sdnnMap[d.date] = it }
    val map = if (rmssdMap.size >= sdnnMap.size) rmssdMap else sdnnMap
    val pairs = map.filter { it.value > 0 }.toSortedMap()
    if (pairs.isEmpty()) return ReadinessResult(null, null, null, null, 0, "none")
    val lns = pairs.values.map { ln(it) }
    val lnToday = lns.last()
    val history = if (lns.size > 1) lns.dropLast(1) else lns
    val base = history.takeLast(60)
    val mean = base.sum() / base.size
    val variance = base.sumOf { (it - mean) * (it - mean) } / base.size
    val sd = sqrt(variance)
    if (base.size < 5 || sd <= 0) return ReadinessResult(null, lnToday, mean, sd, base.size, "none")
    val z = (lnToday - mean) / sd
    val score = (50 + 20 * z).coerceIn(0.0, 100.0).let { Math.round(it).toInt() }
    val advice = if (z < -1.0) "rest" else if (z < -0.3) "easy" else "ready"
    return ReadinessResult(score, lnToday, mean, sd, base.size, advice)
}

fun Store.dfaAlpha1Available(): Boolean = false

// MARK: - Progressive overload (double progression)
enum class ProgKind(val key: String) {
    ADD_LOAD("wk.add_load"), ADD_REPS("wk.add_reps"), HOLD("wk.hold"), DELOAD("wk.deload_ex")
}

fun Store.repRange(s: String): Pair<Int, Int>? {
    if (s.lowercase().contains("s")) return null
    val nums = Regex("\\d+").findAll(s).map { it.value.toInt() }.toList()
    val lo = nums.firstOrNull() ?: return null
    val hi = if (nums.size > 1) nums[1] else lo
    return lo to maxOf(lo, hi)
}

fun Store.progression(planId: String, exercise: String): ProgKind? {
    val plan = plan(planId) ?: return null
    val pe = plan.exercises.firstOrNull { it.name == exercise } ?: return null
    val range = repRange(pe.reps) ?: return null
    val last = lastSession(planId) ?: return null
    val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
    val working = ex.sets.filter { pf(it.weight) > 0 }
    if (working.isEmpty()) return null
    val minReps = working.mapNotNull { pf(it.reps).toInt().takeIf { r -> r > 0 } }.minOrNull() ?: return null
    return when {
        minReps >= range.second -> ProgKind.ADD_LOAD
        minReps >= range.first -> ProgKind.ADD_REPS
        else -> ProgKind.HOLD
    }
}
