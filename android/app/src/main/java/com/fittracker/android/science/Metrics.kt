package com.fittracker.android.science

import com.fittracker.android.data.MuscleGroup
import com.fittracker.android.data.Sport
import com.fittracker.android.data.Store
import com.fittracker.android.data.bar
import com.fittracker.android.data.durationMinutesD
import com.fittracker.android.data.estMaxHR
import com.fittracker.android.data.exKind
import com.fittracker.android.data.filled
import com.fittracker.android.data.maxSeconds
import com.fittracker.android.data.maxWeight
import com.fittracker.android.data.plateSet
import com.fittracker.android.data.restHRorDefault
import com.fittracker.android.data.sportType
import com.fittracker.android.utils.Helpers.isoFormatter
import com.fittracker.android.utils.Helpers.pf
import java.util.Calendar
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Kotlin port of Metrics.swift: e1RM, FFMI, barbell plate math, weekly
 * muscle-group volume, PR timeline, a VO2max estimate derived from logged
 * runs (the HealthKit-measured branch is dropped — out of scope for this
 * port), HR zones (Karvonen) and resting-HR/HRV linear trend.
 */

// MARK: e1RM (Epley) ---------------------------------------------------------

object Metrics {
    /** Estimated 1RM for a single set via Epley: w · (1 + reps/30), reps capped at 12. */
    fun e1RM(weight: Double, reps: Double): Double? {
        if (weight <= 0 || reps <= 0) return null
        val r = min(reps, 12.0)
        return weight * (1 + r / 30.0)
    }

    data class FFMIResult(val raw: Double, val normalized: Double, val lean: Double)

    fun ffmi(weight: Double, bodyFat: Double, heightM: Double): FFMIResult? {
        if (weight <= 0 || bodyFat <= 0 || bodyFat >= 60) return null
        val lean = weight * (1 - bodyFat / 100.0)
        if (heightM <= 1.0 || heightM >= 2.5 || lean <= 0) return null
        val raw = lean / (heightM * heightM)
        val norm = raw + 6.1 * (1.80 - heightM)
        return FFMIResult((raw * 10).roundToInt() / 10.0, (norm * 10).roundToInt() / 10.0, (lean * 10).roundToInt() / 10.0)
    }
}

/** Best estimated 1RM ever logged for an exercise (bodyweight exercises return null). */
fun Store.bestE1RM(name: String): Double? {
    if (isBodyweightExercise(name)) return null
    var best: Double? = null
    for (s in sessions.value) for (e in s.exercises) if (e.name == name) for (set in e.sets) {
        val v = Metrics.e1RM(pf(set.weight), pf(set.reps))
        if (v != null) best = max(best ?: 0.0, v)
    }
    return best?.let { (it * 10).roundToInt() / 10.0 }
}

data class E1RMPoint(val date: String, val value: Double)

fun Store.e1RMSeries(name: String): List<E1RMPoint> {
    val pts = ArrayList<E1RMPoint>()
    for (s in sessions.value.sortedBy { it.date }) {
        var best = 0.0
        for (e in s.exercises) if (e.name == name) for (set in e.sets) {
            Metrics.e1RM(pf(set.weight), pf(set.reps))?.let { best = max(best, it) }
        }
        if (best > 0) pts.add(E1RMPoint(s.date, (best * 10).roundToInt() / 10.0))
    }
    return pts
}

// MARK: FFMI ------------------------------------------------------------------

fun Store.ffmi(weight: Double? = null, bodyFat: Double? = null): Metrics.FFMIResult? {
    val h = prefs.value.height
    val lean: Double? = if (weight != null && bodyFat != null && weight > 0 && bodyFat > 0 && bodyFat < 60) {
        weight * (1 - bodyFat / 100)
    } else {
        fatFreeMass()
    }
    if (h <= 1.0 || h >= 2.5 || lean == null || lean <= 0) return null
    val raw = lean / (h * h)
    val norm = raw + 6.1 * (1.80 - h)
    return Metrics.FFMIResult((raw * 10).roundToInt() / 10.0, (norm * 10).roundToInt() / 10.0, (lean * 10).roundToInt() / 10.0)
}

private fun Store.fatFreeMass(): Double? {
    val bf = currentBF ?: return null
    if (bf <= 0 || bf >= 60) return null
    val w = lastWeight
    return w * (1 - bf / 100)
}

/** (labelKey, colorTag) for a normalized FFMI, sex-adjusted. */
fun ffmiCategory(v: Double, sex: String): Pair<String, String> {
    val shift = if (sex == "f") -3.0 else 0.0
    return when {
        v < 18 + shift -> "ffmi.below" to "sub"
        v < 20 + shift -> "ffmi.average" to "blue"
        v < 22 + shift -> "ffmi.good" to "good"
        v < 23 + shift -> "ffmi.great" to "acc2"
        v < 26 + shift -> "ffmi.excellent" to "acc"
        else -> "ffmi.elite" to "fat"
    }
}

fun Store.ffmiFor(weight: Double): Double? {
    val h = prefs.value.height
    val bf = currentBF
    if (h <= 1.0 || h >= 2.5 || bf == null || bf <= 0 || bf >= 60 || weight <= 0) return null
    val lean = weight * (1 - bf / 100)
    return ((lean / (h * h)) * 10).roundToInt() / 10.0
}

// MARK: Barbell plate maths + warm-up ramp ------------------------------------

data class PlateLoad(val plates: List<Double>, val achieved: Double, val exact: Boolean)

fun Store.plateBreakdown(target: Double, bar: Double? = null, available: List<Double>? = null): PlateLoad? {
    val barKg = bar ?: prefs.value.bar
    val denoms = (available ?: prefs.value.plateSet).sortedDescending()
    if (target <= 0 || denoms.isEmpty()) return null
    if (target < barKg) {
        return PlateLoad(emptyList(), barKg, kotlin.math.abs(target - barKg) < 0.01)
    }
    var perSide = (target - barKg) / 2
    val out = ArrayList<Double>()
    for (d in denoms) {
        while (perSide >= d - 0.001) { out.add(d); perSide -= d }
    }
    val achieved = barKg + out.sum() * 2
    return PlateLoad(out, (achieved * 100).roundToInt() / 100.0, kotlin.math.abs(achieved - target) < 0.01)
}

data class WarmupStep(val pct: Double, val reps: Int, val weight: Double)

fun Store.warmupRamp(working: Double): List<WarmupStep> {
    if (working <= prefs.value.bar) return emptyList()
    val plan = listOf(0.4 to 5, 0.6 to 3, 0.8 to 1)
    return plan.mapNotNull { (pct, reps) ->
        val raw = working * pct
        if (raw <= prefs.value.bar) return@mapNotNull null
        val w = plateBreakdown(raw)?.achieved ?: raw
        if (w <= prefs.value.bar) return@mapNotNull null
        WarmupStep(pct, reps, w)
    }
}

// MARK: - Weekly volume per muscle group (sets/week) --------------------------

data class MuscleVolume(val group: MuscleGroup, val sets: Int, val target: Int) {
    val status: String get() {
        val lower = (target * 0.67).roundToInt()
        val upper = (target * 1.33).roundToInt()
        return if (sets < lower) "low" else if (sets > upper) "high" else "ok"
    }
}

fun Store.volumeTarget(g: MuscleGroup): Int {
    val v = prefs.value.volumeTargets?.get(g.raw)
    if (v != null && v > 0) return v
    return when (g) {
        MuscleGroup.CHEST, MuscleGroup.BACK, MuscleGroup.LEGS, MuscleGroup.SHOULDERS -> 15
        MuscleGroup.ARMS, MuscleGroup.CORE -> 10
        MuscleGroup.FULLBODY -> 12
        MuscleGroup.CARDIO, MuscleGroup.OTHER -> 0
    }
}

fun Store.weeklyMuscleVolume(offset: Int = 0): List<MuscleVolume> {
    val cal = Calendar.getInstance()
    val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
    val mon = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -dow - offset * 7)
    }
    val sun = (mon.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 7) }
    val counts = HashMap<String, Int>()
    for (s in sessions.value) {
        val d = try { isoFormatter.parse(s.date) } catch (e: Exception) { null } ?: continue
        if (d.before(mon.time) || !d.before(sun.time)) continue
        for (e in s.exercises) {
            val working = e.sets.count { it.filled }
            if (working <= 0) continue
            val g = exerciseCategory(e.name)
            counts[g] = (counts[g] ?: 0) + working
        }
    }
    return MuscleGroup.allCases.mapNotNull { g ->
        val n = counts[g.raw] ?: 0
        if (n > 0) MuscleVolume(g, n, volumeTarget(g)) else null
    }
}

/** Whether the week's numbers say to back off (ACWR high + monotonous). */
fun Store.deloadAdvice(): Boolean {
    if (!loadDataStatus().reliable) return false
    val a = acwr()
    val ratio = a.ratio ?: return false
    val w = weekLoad(0)
    val mono = w.monotony ?: return false
    return ratio > 1.5 && mono > 2.0
}

// MARK: - Personal-record timeline --------------------------------------------

data class PREvent(val date: String, val exercise: String, val kind: String, val value: Double, val delta: Double?) {
    val unit: String get() = if (kind == "hold") "s" else "kg"
    val labelKey: String get() = when (kind) {
        "e1rm" -> "st.pr_e1rm"
        "hold" -> "st.pr_hold"
        else -> "st.pr_weight"
    }
}

fun Store.prTimeline(limit: Int = 60): List<PREvent> {
    val bestWeight = HashMap<String, Double>()
    val bestE1RM = HashMap<String, Double>()
    val bestHold = HashMap<String, Double>()
    val out = ArrayList<PREvent>()

    for (s in sessions.value.sortedBy { it.date }) {
        for (e in s.exercises) {
            val name = e.name
            when (e.exKind) {
                com.fittracker.android.data.ExKind.TIMED -> {
                    val hold = e.maxSeconds
                    if (hold > 0 && hold > (bestHold[name] ?: 0.0)) {
                        val prev = bestHold[name]
                        out.add(PREvent(s.date, name, "hold", hold, prev?.let { hold - it }))
                        bestHold[name] = hold
                    }
                }
                com.fittracker.android.data.ExKind.REPS -> {
                    val w = e.maxWeight
                    if (w > 0 && w > (bestWeight[name] ?: 0.0)) {
                        val prev = bestWeight[name]
                        out.add(PREvent(s.date, name, "weight", w, prev?.let { w - it }))
                        bestWeight[name] = w
                    }
                    val e1 = e.sets.mapNotNull { Metrics.e1RM(pf(it.weight), pf(it.reps)) }.maxOrNull() ?: 0.0
                    if (e1 > 0 && e1 > (bestE1RM[name] ?: 0.0) + 0.05) {
                        val prev = bestE1RM[name]
                        val rounded = (e1 * 10).roundToInt() / 10.0
                        out.add(PREvent(s.date, name, "e1rm", rounded, prev?.let { ((e1 - it) * 10).roundToInt() / 10.0 }))
                        bestE1RM[name] = e1
                    }
                }
                com.fittracker.android.data.ExKind.INTERVAL -> {}
            }
        }
    }
    return out.reversed().take(limit)
}

// MARK: - VO2max estimate from running + HR zones -----------------------------

fun Store.vo2maxEstimate(): Pair<Double, Boolean>? {
    val v = latestVO2
    if (v != null && v > 0) return v to false
    val runs = sessions.value.filter { it.sportType == Sport.RUNNING }.sortedByDescending { it.date }.take(20)
    var best: Double? = null
    for (r in runs) {
        val mins = r.durationMinutesD ?: continue
        val km = r.distanceKm ?: continue
        val hr = r.avgHR ?: continue
        if (mins <= 0 || km <= 0 || hr <= 0) continue
        val vel = km * 1000 / mins
        val vo2AtPace = 0.2 * vel + 3.5
        val rest = prefs.value.restHRorDefault.toDouble()
        val mx = prefs.value.estMaxHR.toDouble()
        if (mx <= rest) continue
        val hrr = max(0.5, min(1.0, (hr - rest) / (mx - rest)))
        val est = vo2AtPace / hrr
        best = max(best ?: 0.0, est)
    }
    return best?.let { (it * 10).roundToInt() / 10.0 to true }
}

data class HRZone(val index: Int, val lower: Int, val upper: Int)

fun Store.hrZones(): List<HRZone> {
    val rest = prefs.value.restHRorDefault.toDouble()
    val mx = prefs.value.estMaxHR.toDouble()
    if (mx <= rest) return emptyList()
    val bounds = listOf(0.50, 0.60, 0.70, 0.80, 0.90, 1.00)
    fun bpm(frac: Double) = (rest + frac * (mx - rest)).roundToInt()
    return (0 until 5).map { i -> HRZone(i + 1, bpm(bounds[i]), bpm(bounds[i + 1])) }
}

fun Store.hrZone(bpm: Int): Int? {
    val zones = hrZones()
    if (zones.isEmpty() || bpm <= 0) return null
    if (bpm < zones[0].lower) return 1
    for (z in zones) if (bpm in z.lower..z.upper) return z.index
    return 5
}

// MARK: - Resting HR / HRV trend (recovery & fitness direction) --------------

data class VitalTrend(val current: Double?, val deltaPerWeek: Double?, val points: Int, val status: String)

private fun Store.vitalTrend(value: (com.fittracker.android.data.DailyEntry) -> Double?, days: Int, higherIsBetter: Boolean): VitalTrend {
    val cutoff = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -days) }
    val pts = ArrayList<Pair<Double, Double>>()
    for (e in sortedDaily) {
        val v = value(e) ?: continue
        if (v <= 0) continue
        val d = try { isoFormatter.parse(e.date) } catch (ex: Exception) { null } ?: continue
        if (d.before(cutoff.time)) continue
        val x = (d.time - cutoff.timeInMillis) / 86400000.0
        pts.add(x to v)
    }
    if (pts.size < 4) return VitalTrend(pts.lastOrNull()?.second, null, pts.size, "none")
    val n = pts.size.toDouble()
    val sx = pts.sumOf { it.first }; val sy = pts.sumOf { it.second }
    val sxx = pts.sumOf { it.first * it.first }; val sxy = pts.sumOf { it.first * it.second }
    val denom = n * sxx - sx * sx
    if (denom == 0.0) return VitalTrend(sy / n, null, pts.size, "none")
    val slope = (n * sxy - sx * sy) / denom
    val intercept = (sy - slope * sx) / n
    val lastX = pts.maxOfOrNull { it.first } ?: 0.0
    val current = intercept + slope * lastX
    val perWeek = slope * 7
    val threshold = 0.02 * max(1.0, current)
    val status = when {
        kotlin.math.abs(perWeek) < threshold -> "stable"
        (perWeek > 0) == higherIsBetter -> "improving"
        else -> "declining"
    }
    return VitalTrend((current * 10).roundToInt() / 10.0, (perWeek * 100).roundToInt() / 100.0, pts.size, status)
}

fun Store.restingHRTrend(days: Int = 30): VitalTrend =
    vitalTrend({ it.restHR?.toDouble() }, days, false)

fun Store.hrvTrend(days: Int = 30): VitalTrend =
    vitalTrend({ (it.hrvSDNN ?: it.rmssd)?.takeIf { v -> v > 0 } }, days, true)
