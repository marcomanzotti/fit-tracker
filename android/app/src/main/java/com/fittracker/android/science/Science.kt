package com.fittracker.android.science

import com.fittracker.android.data.Store
import com.fittracker.android.data.WorkoutSession
import com.fittracker.android.data.durationMinutesD
import com.fittracker.android.data.exKind
import com.fittracker.android.data.ExKind
import com.fittracker.android.data.PlanExercise
import com.fittracker.android.data.effortScale
import com.fittracker.android.data.EffortMode
import com.fittracker.android.data.effectiveTargetSec
import com.fittracker.android.data.maxSeconds
import com.fittracker.android.data.restHRorDefault
import com.fittracker.android.data.estMaxHR
import com.fittracker.android.data.sex_
import com.fittracker.android.data.restDaySet
import com.fittracker.android.utils.Helpers.isoFormatter
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.utils.Helpers.today
import java.util.Calendar
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Kotlin port of Science.swift: internal load (TRIMP), ACWR (EWMA method),
 * weekly monotony/strain (Foster), multi-factor readiness, and progressive
 * overload logic. All computed from manually entered data — nothing here
 * depends on HealthKit / a BLE chest strap (those parts of the Swift original
 * are intentionally stubbed there too).
 */

// MARK: TRIMP (Banister, sex-weighted) --------------------------------------

/** Banister TRIMP for a session; needs avg HR + duration. */
fun Store.trimp(s: WorkoutSession): Double? {
    val dur = s.durationMinutesD ?: return null
    val hr = s.avgHR ?: return null
    if (dur <= 0 || hr <= 0) return null
    val p = prefs.value
    val rest = p.restHRorDefault.toDouble()
    val mx = (s.maxHRSes ?: p.estMaxHR).toDouble()
    if (mx <= rest) return null
    val hrr = max(0.0, min(1.0, (hr - rest) / (mx - rest)))
    val y = if (p.sex_ == "f") 1.67 else 1.92
    return dur * hrr * 0.64 * exp(y * hrr)
}

/** Strictly *measured* internal load = TRIMP. */
fun Store.measuredLoad(s: WorkoutSession): Double? = trimp(s)

/** Sum of session TRIMP in a Monday-based week (offset 0 = current week). */
fun Store.weeklyTrimp(offset: Int = 0): Double {
    val cal = Calendar.getInstance()
    val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
    val mon = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -dow - offset * 7)
    }
    val sun = (mon.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 7) }
    var total = 0.0
    for (s in sessions.value) {
        val v = trimp(s) ?: continue
        val d = try { isoFormatter.parse(s.date) } catch (e: Exception) { null } ?: continue
        if (!d.before(mon.time) && d.before(sun.time)) total += v
    }
    return total
}

/** TRIMP of the most recent session that has one (null if no HR logged yet). */
fun Store.lastSessionTrimp(): Pair<Double, String>? {
    for (s in sessions.value.sortedByDescending { it.date }) {
        val v = trimp(s)
        if (v != null) return v to s.date
    }
    return null
}

val Store.hasAnyTrimp: Boolean get() = sessions.value.any { trimp(it) != null }

// MARK: - Daily load series + ACWR (EWMA method) -----------------------------

data class LoadPoint(val date: String, val load: Double)

data class ACWRResult(val ratio: Double?, val acute: Double, val chronic: Double, val zone: String)

/** Daily summed load for the last `days` days, oldest -> newest, zero-filled. */
fun Store.dailyLoadSeries(days: Int): List<LoadPoint> {
    val map = HashMap<String, Double>()
    for (s in sessions.value) { measuredLoad(s)?.let { map[s.date] = (map[s.date] ?: 0.0) + it } }
    val cal = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    val stack = ArrayList<LoadPoint>()
    repeat(days) {
        val key = isoFormatter.format(cal.time)
        stack.add(LoadPoint(key, map[key] ?: 0.0))
        cal.add(Calendar.DAY_OF_YEAR, -1)
    }
    return stack.reversed()
}

private fun ewma(values: List<Double>, days: Int): Double {
    if (values.isEmpty()) return 0.0
    val lambda = 2.0 / (days + 1.0)
    var e = values[0]
    for (v in values.drop(1)) e = v * lambda + e * (1 - lambda)
    return e
}

data class LoadDataStatus(val reliable: Boolean, val sessions: Int, val spanDays: Int, val needSessions: Int, val needDays: Int)

fun Store.loadDataStatus(): LoadDataStatus {
    val needSessions = 6; val needDays = 21
    val loaded = sessions.value.filter { measuredLoad(it) != null }
    val cal = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    val today = cal.timeInMillis
    val dates = loaded.mapNotNull { s -> try { isoFormatter.parse(s.date) } catch (e: Exception) { null } }
    val span = dates.minByOrNull { it.time }?.let { min ->
        val minCal = Calendar.getInstance().apply {
            time = min; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val diffDays = ((today - minCal.timeInMillis) / 86400000L).toInt()
        diffDays + 1
    } ?: 0
    val reliable = loaded.size >= needSessions && span >= needDays
    return LoadDataStatus(reliable, loaded.size, span, needSessions, needDays)
}

/** ACWR with the EWMA method (acute = 7d, chronic = 28d). */
fun Store.acwr(): ACWRResult {
    val series = dailyLoadSeries(42).map { it.load }
    if (series.none { it > 0 }) return ACWRResult(null, 0.0, 0.0, "none")
    val acute = ewma(series, 7)
    val chronic = ewma(series, 28)
    if (chronic <= 0) return ACWRResult(null, acute, chronic, "none")
    val r = acute / chronic
    val zone = when {
        r < 0.8 -> "low"
        r < 1.3 -> "ok"
        else -> "high"
    }
    return ACWRResult((r * 100).roundToInt() / 100.0, acute, chronic, zone)
}

// MARK: - Weekly monotony & strain (Foster) ---------------------------------

data class WeekLoad(val total: Double, val mean: Double, val sd: Double, val monotony: Double?, val strain: Double?, val sessions: Int)

fun Store.weekLoad(offset: Int): WeekLoad {
    val cal = Calendar.getInstance()
    val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
    val mon = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -dow - offset * 7)
    }
    val todayCal = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    val daily = DoubleArray(7)
    var count = 0
    val trainingDays = HashSet<Int>()
    val knownDays = HashSet<Int>()
    for (s in sessions.value) {
        val l = measuredLoad(s) ?: continue
        val d = try { isoFormatter.parse(s.date) } catch (e: Exception) { null } ?: continue
        val dayCal = Calendar.getInstance().apply {
            time = d; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val diff = ((dayCal.timeInMillis - mon.timeInMillis) / 86400000L).toInt()
        if (diff in 0..6) { daily[diff] += l; count += 1; trainingDays.add(diff); knownDays.add(diff) }
    }
    val restSet = prefs.value.restDaySet
    for (diff in 0..6) {
        val day = (mon.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, diff) }
        if (restSet.contains(isoFormatter.format(day.time))) knownDays.add(diff)
    }
    val denom = if (offset == 0) max(1, knownDays.size).toDouble() else 7.0
    val total = daily.sum()
    val mean = total / denom
    val days = if (offset == 0) knownDays.sorted() else (0..6).toList()
    val variance = days.sumOf { (daily[it] - mean) * (daily[it] - mean) } / denom
    val sd = sqrt(variance)
    val monotony = if (sd > 0 && trainingDays.size >= 2) mean / sd else null
    val strain = monotony?.let { total * it }
    return WeekLoad(total, mean, sd, monotony, strain, count)
}

// MARK: - Readiness (multi-factor: HRV + resting HR + sleep) ----------------

data class ReadinessResult(
    val score: Int?, val lnToday: Double?, val baseline: Double?, val sd: Double?,
    val samples: Int, val advice: String, val usedSignals: List<String> = emptyList()
)

private data class ZFactor(val z: Double, val today: Double, val mean: Double, val sd: Double, val baseCount: Int)

private fun zFactor(map: Map<String, Double>, transform: (Double) -> Double, higherIsBetter: Boolean, minN: Int): ZFactor? {
    val pairs = map.filterValues { it > 0 }.toList().sortedBy { it.first }
    if (pairs.isEmpty()) return null
    val vals = pairs.map { transform(it.second) }
    val today = vals.last()
    val history = if (vals.size > 1) vals.dropLast(1) else vals
    val base = history.takeLast(60)
    if (base.size < minN) return null
    val mean = base.sum() / base.size
    val variance = base.sumOf { (it - mean) * (it - mean) } / base.size
    val sd = sqrt(variance)
    if (sd <= 0) return null
    var z = (today - mean) / sd
    if (!higherIsBetter) z = -z
    return ZFactor(max(-3.0, min(3.0, z)), today, mean, sd, base.size)
}

fun Store.readiness(): ReadinessResult {
    val rmssdMap = HashMap<String, Double>()
    for (s in sessions.value) { val r = s.rmssd; if (r != null && r > 0) rmssdMap[s.date] = r }
    for (d in daily.value) { val r = d.rmssd; if (r != null && r > 0) rmssdMap[d.date] = r }
    val sdnnMap = HashMap<String, Double>()
    for (d in daily.value) { val h = d.hrvSDNN; if (h != null && h > 0) sdnnMap[d.date] = h }
    val hrvMap = if (rmssdMap.size >= sdnnMap.size) rmssdMap else sdnnMap

    data class Factor(val name: String, val z: Double, val w: Double)
    val factors = ArrayList<Factor>()
    var hrvSamples = 0
    var lnToday: Double? = null; var hrvBase: Double? = null; var hrvSD: Double? = null

    zFactor(hrvMap, { ln(it) }, true, 5)?.let { f ->
        factors.add(Factor("hrv", f.z, 0.50))
        hrvSamples = f.baseCount; lnToday = f.today; hrvBase = f.mean; hrvSD = f.sd
    }

    val hrMap = HashMap<String, Double>()
    for (d in daily.value) {
        val v = d.restHR
        if (v != null && v > 0) hrMap[d.date] = v.toDouble()
        else { val sv = d.sleepHR; if (sv != null && sv > 0) hrMap[d.date] = sv.toDouble() }
    }
    zFactor(hrMap, { it }, false, 5)?.let { f -> factors.add(Factor("hr", f.z, 0.30)) }

    val sleepMap = HashMap<String, Double>()
    for (d in daily.value) { val v = d.sleep; if (v != null && v > 0) sleepMap[d.date] = v.toDouble() }
    val sf = zFactor(sleepMap, { it }, true, 5)
    if (sf != null) {
        factors.add(Factor("sleep", sf.z, 0.20))
    } else {
        val latestKey = sleepMap.keys.maxOrNull()
        if (latestKey != null) {
            val todayScore = sleepMap[latestKey]!!
            factors.add(Factor("sleep", max(-3.0, min(3.0, (todayScore - 72) / 12)), 0.20))
        }
    }

    if (factors.isEmpty()) {
        return ReadinessResult(null, lnToday, hrvBase, hrvSD, hrvSamples, "none", emptyList())
    }
    val wSum = factors.sumOf { it.w }
    val z = factors.sumOf { it.z * it.w } / wSum
    val score = max(0, min(100, (50 + 20 * z).roundToInt()))
    val advice = when {
        z < -1.0 -> "rest"
        z < -0.3 -> "easy"
        else -> "ready"
    }
    return ReadinessResult(score, lnToday, hrvBase, hrvSD, hrvSamples, advice, factors.map { it.name })
}

// MARK: - Progressive overload (double progression) --------------------------

enum class ProgKind(val key: String) {
    ADD_LOAD("wk.add_load"), ADD_REPS("wk.add_reps"), HOLD("wk.hold"), DELOAD("wk.deload_ex")
}

/** Parse a target like "8-10" or "10" into a rep range. Null for time/asymmetric targets. */
fun Store.repRange(s: String): Pair<Int, Int>? {
    if (s.lowercase().contains("s")) return null
    val nums = Regex("[0-9]+").findAll(s).map { it.value.toIntOrNull() }.filterNotNull().toList()
    val lo = nums.firstOrNull() ?: return null
    val hi = if (nums.size > 1) nums[1] else lo
    return lo to max(lo, hi)
}

fun Store.progression(planId: String, exercise: String): ProgKind? {
    val plan = plan(planId) ?: return null
    val pe = plan.exercises.firstOrNull { it.name == exercise } ?: return null

    val r = readiness()
    if ((r.score ?: 100) < 30) return ProgKind.DELOAD
    val aw = acwr()
    if ((aw.ratio ?: 0.0) > 1.3) return ProgKind.HOLD

    when (pe.exKind) {
        ExKind.TIMED -> return timedProgression(planId, exercise)
        ExKind.INTERVAL -> return intervalProgression(pe)
        ExKind.REPS -> {}
    }

    val (lo, hi) = repRange(pe.reps) ?: return null

    val planSessions = sessions.value.filter { it.planId == planId && it.date != today() }.sortedByDescending { it.date }
    val last = planSessions.firstOrNull() ?: return null
    val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null

    val working = ex.sets.filter { pf(it.weight) > 0 }
    if (working.isEmpty()) return null
    val reps = working.map { pf(it.reps).toInt() }
    val minReps = reps.minOrNull() ?: return null
    if (minReps <= 0) return null

    ex.effortScale?.let { scale ->
        val effortVals = ex.sets.mapNotNull { it.effortVal }
        if (effortVals.isNotEmpty()) {
            val avgEffort = effortVals.sum().toDouble() / effortVals.size
            when {
                scale == EffortMode.RIR && avgEffort >= 3 -> return ProgKind.ADD_REPS
                scale == EffortMode.RPE && avgEffort <= 6 -> return ProgKind.ADD_REPS
                else -> {}
            }
        }
    }

    if (minReps < hi) {
        return if (minReps >= lo) ProgKind.ADD_REPS else ProgKind.HOLD
    }

    if (planSessions.size >= 2) {
        val prev = planSessions[1]
        val prevEx = prev.exercises.firstOrNull { it.name == exercise }
        if (prevEx != null) {
            val prevWorking = prevEx.sets.filter { pf(it.weight) > 0 }
            val prevReps = prevWorking.mapNotNull { pf(it.reps).toInt() }
            val prevMin = prevReps.minOrNull()
            if (prevMin != null && prevMin >= hi) return ProgKind.ADD_LOAD
        }
    }
    return ProgKind.ADD_LOAD
}

private fun Store.timedProgression(planId: String, exercise: String): ProgKind? {
    val plan = plan(planId) ?: return null
    val pe = plan.exercises.firstOrNull { it.name == exercise } ?: return null
    val target: Double? = if (pe.effectiveTargetSec > 0) pe.effectiveTargetSec.toDouble() else null
    val planSessions = sessions.value.filter { it.planId == planId && it.date != today() }.sortedByDescending { it.date }
    val last = planSessions.firstOrNull() ?: return null
    val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
    val held = ex.maxSeconds
    if (held <= 0) return null
    if (target == null || held < target) return ProgKind.ADD_REPS
    if (planSessions.size >= 2) {
        val prevEx = planSessions[1].exercises.firstOrNull { it.name == exercise }
        if (prevEx != null && prevEx.maxSeconds >= target) return ProgKind.ADD_LOAD
    }
    return ProgKind.ADD_LOAD
}

private fun Store.intervalProgression(pe: PlanExercise): ProgKind? {
    val target = pe.rounds?.takeIf { it > 0 } ?: return null
    val recent = sessions.value
        .filter { it.date != today() }
        .sortedByDescending { it.date }
        .mapNotNull { s -> s.exercises.firstOrNull { it.name == pe.name }?.rounds }
    val lastRounds = recent.firstOrNull() ?: return null
    return if (lastRounds >= target) ProgKind.ADD_LOAD else ProgKind.ADD_REPS
}
