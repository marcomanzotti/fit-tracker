package com.marco.fittracker.data

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import kotlinx.serialization.json.Json
import java.io.File
import java.time.LocalDate
import kotlin.math.ln
import kotlin.math.roundToInt

private val json = Json {
    encodeDefaults = true
    explicitNulls = false
    ignoreUnknownKeys = true
    prettyPrint = false
}
private val prettyJson = Json {
    encodeDefaults = true
    explicitNulls = false
    ignoreUnknownKeys = true
    prettyPrint = true
}

class Store(app: Application) : AndroidViewModel(app) {

    // Observable state (Compose snapshot state)
    val daily = mutableStateListOf<DailyEntry>()
    val sessions = mutableStateListOf<WorkoutSession>()
    val body = mutableStateListOf<BodyEntry>()
    val plans = mutableStateListOf<WorkoutPlan>()
    var prefs by mutableStateOf(Prefs())

    private val dataFile: File get() = File(getApplication<Application>().filesDir, "fittracker.json")
    private var loaded = false

    init { load() }

    // MARK: Persistence
    private fun load() {
        runCatching {
            if (dataFile.exists()) {
                val a = json.decodeFromString<AppData>(dataFile.readText())
                daily.addAll(a.daily); sessions.addAll(a.sessions)
                body.addAll(a.body); plans.addAll(a.plans); prefs = a.prefs
            }
        }
        if (plans.isEmpty()) plans.addAll(defaultPlans())
        loaded = true
        save()
    }

    private fun snapshot() = AppData(daily.toList(), sessions.toList(), body.toList(), plans.toList(), prefs)

    private fun save() {
        if (!loaded) return
        runCatching {
            val text = json.encodeToString(AppData.serializer(), snapshot())
            dataFile.writeText(text)
            // Rolling dated backup, visible via the system file manager export.
            File(getApplication<Application>().filesDir, "backup-${today()}.json").writeText(text)
        }
    }

    /** Pretty JSON used for share/export. */
    fun exportText(): String = prettyJson.encodeToString(AppData.serializer(), snapshot())
    fun exportFileName(): String = "fittracker-${today()}.json"

    fun importText(text: String): Boolean = runCatching {
        val a = json.decodeFromString<AppData>(text)
        daily.clear(); daily.addAll(a.daily)
        sessions.clear(); sessions.addAll(a.sessions)
        body.clear(); body.addAll(a.body)
        plans.clear(); plans.addAll(if (a.plans.isEmpty()) defaultPlans() else a.plans)
        prefs = a.prefs
        save()
        true
    }.getOrDefault(false)

    // MARK: - Derived data
    val sortedDaily: List<DailyEntry> get() = daily.sortedBy { it.date }

    val lastWeight: Double
        get() = sortedDaily.lastOrNull { it.weight != null }?.weight ?: prefs.startWeight

    fun plan(id: String): WorkoutPlan? = plans.firstOrNull { it.id == id }

    fun bmi(w: Double): Double = Math.round((w / (prefs.height * prefs.height)) * 10.0) / 10.0

    /** US-Navy body-fat estimate from neck & waist (cm). */
    fun bfNavy(waist: Double?, neck: Double?): Double? {
        if (waist == null || neck == null || waist <= neck) return null
        val v = 86.010 * log10(waist - neck) - 70.041 * log10(prefs.height * 100) + 36.76
        return Math.round(v * 10.0) / 10.0
    }

    fun hasCheckedIn(): Boolean = daily.any { it.date == today() && it.weight != null }

    val streak: Int
        get() {
            val dates = HashSet<String>()
            daily.forEach { dates.add(it.date) }
            sessions.forEach { dates.add(it.date) }
            var n = 0
            var d = LocalDate.now()
            repeat(365) {
                val s = d.toString()
                if (dates.contains(s)) { n += 1; d = d.minusDays(1) } else return n
            }
            return n
        }

    /** Next plan to train, cycling through the plan list after the most recent session. */
    fun nextPlan(): WorkoutPlan? {
        if (plans.isEmpty()) return null
        val last = sessions.sortedByDescending { it.date }.firstOrNull() ?: return plans.first()
        val idx = plans.indexOfFirst { it.id == last.planId }
        if (idx < 0) return plans.first()
        return plans[(idx + 1) % plans.size]
    }

    fun exercisePR(name: String): Double {
        var mx = 0.0
        for (s in sessions) for (e in s.exercises) if (e.name == name) mx = maxOf(mx, e.maxWeight)
        return mx
    }

    fun lastSession(planId: String): WorkoutSession? =
        sessions.filter { it.planId == planId && it.date != today() }
            .sortedByDescending { it.date }.firstOrNull()

    /** Suggested next weight: previous session's max + 2.5kg if every set was completed. */
    fun suggested(planId: String, exercise: String): Double? {
        val last = lastSession(planId) ?: return null
        val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
        if (ex.sets.isEmpty()) return null
        val allDone = ex.sets.all { pf(it.reps) > 0 && pf(it.weight) > 0 }
        return if (allDone) ex.maxWeight + 2.5 else null
    }

    fun estimateCalories(s: WorkoutSession): Int =
        (s.volume * 0.022 + s.totalSets * 3 + 60).roundToInt()

    data class WeekStat(val avgWeight: Double?, val sessions: Int)
    fun weekStats(offset: Int): WeekStat {
        val now = LocalDate.now()
        val monday = now.minusDays((now.dayOfWeek.value - 1).toLong()).minusDays(offset * 7L)
        val sunday = monday.plusDays(7)
        fun inRange(ds: String): Boolean {
            val d = runCatching { LocalDate.parse(ds) }.getOrNull() ?: return false
            return !d.isBefore(monday) && d.isBefore(sunday)
        }
        val dw = daily.filter { inRange(it.date) && it.weight != null }.mapNotNull { it.weight }
        val avg = if (dw.isEmpty()) null else Math.round((dw.sum() / dw.size) * 10.0) / 10.0
        return WeekStat(avg, sessions.count { inRange(it.date) })
    }

    data class PRInfo(val weight: Double, val date: String?)
    /** PR per exercise name across all plans + sessions. */
    fun allPRs(): Map<String, PRInfo> {
        val prs = LinkedHashMap<String, PRInfo>()
        for (p in plans) for (e in p.exercises) if (!prs.containsKey(e.name)) prs[e.name] = PRInfo(0.0, null)
        for (s in sessions.sortedBy { it.date }) for (e in s.exercises) {
            val w = e.maxWeight
            if (w >= (prs[e.name]?.weight ?: 0.0)) prs[e.name] = PRInfo(w, s.date)
        }
        return prs
    }

    /** Distinct exercise names from every plan, in plan order. */
    fun allExerciseNames(): List<Pair<String, String>> {
        val out = ArrayList<Pair<String, String>>()
        for (p in plans) for (e in p.exercises) out.add(p.name to e.name)
        return out
    }

    data class ExPoint(val date: String, val maxW: Double, val vol: Double)
    fun exerciseHistory(name: String): List<ExPoint> =
        sessions.filter { s -> s.exercises.any { it.name == name } }
            .sortedBy { it.date }
            .map { s ->
                val ex = s.exercises.first { it.name == name }
                ExPoint(fmtShort(s.date), ex.maxWeight, Math.round(ex.volume).toDouble())
            }

    val bodyLatest: BodyEntry? get() = body.sortedByDescending { it.date }.firstOrNull()
    val bodyPrev: BodyEntry?
        get() {
            val s = body.sortedByDescending { it.date }
            return if (s.size > 1) s[1] else null
        }

    /** Effective body-fat %: manual override wins, otherwise Navy estimate. */
    val currentBF: Double?
        get() {
            val bl = bodyLatest ?: return null
            return bl.bfManual ?: bfNavy(bl.waist, bl.neck)
        }

    // MARK: - Mutations
    fun saveCheckIn(weight: Double?, sleep: Int?) {
        val t = today()
        val existing = daily.firstOrNull { it.date == t } ?: DailyEntry(date = t)
        val entry = existing.copy(
            weight = weight ?: existing.weight,
            sleep = sleep ?: existing.sleep
        )
        daily.removeAll { it.date == t }
        daily.add(entry)
        save()
    }

    fun saveBodyFat(v: Double) {
        val t = today()
        val rec = (if (bodyLatest?.date == t) bodyLatest!! else BodyEntry(date = t)).copy(bfManual = v)
        body.removeAll { it.date == t }
        body.add(rec)
        save()
    }

    fun saveMeasurements(values: Map<String, Double>) {
        val t = today()
        var rec = if (bodyLatest?.date == t) bodyLatest!! else BodyEntry(date = t)
        for ((k, v) in values) if (v > 0) rec = rec.withValue(k, v)
        body.removeAll { it.date == t }
        body.add(rec)
        save()
    }

    fun addSession(s: WorkoutSession) { sessions.add(s); save() }

    fun upsertPlan(p: WorkoutPlan) {
        val idx = plans.indexOfFirst { it.id == p.id }
        if (idx >= 0) plans[idx] = p else plans.add(p)
        save()
    }

    fun deletePlan(id: String) { plans.removeAll { it.id == id }; save() }

    fun addExerciseToPlan(planId: String, name: String) {
        val idx = plans.indexOfFirst { it.id == planId }
        if (idx >= 0) {
            val p = plans[idx]
            plans[idx] = p.copy(exercises = p.exercises + PlanExercise(name = name, sets = 3, reps = "10"))
            save()
        }
    }

    fun updatePrefs(p: Prefs) { prefs = p; save() }

    companion object {
        fun defaultPlans(): List<WorkoutPlan> = listOf(
            WorkoutPlan(id = "p1", name = "Push", sub = "Spalle + Petto", color = "ff5a52", exercises = listOf(
                PlanExercise(name = "Military press bilanciere", sets = 4, reps = "8-10"),
                PlanExercise(name = "Shoulder press manubri seduto", sets = 3, reps = "10"),
                PlanExercise(name = "Lateral raise al cavo", sets = 3, reps = "12"),
                PlanExercise(name = "Panca inclinata manubri", sets = 3, reps = "10"),
                PlanExercise(name = "Cavi incrociati bassi", sets = 3, reps = "12"),
                PlanExercise(name = "Triceps pushdown al cavo", sets = 3, reps = "12")
            )),
            WorkoutPlan(id = "p2", name = "Pull", sub = "Schiena + Bicipiti", color = "4fb8c4", exercises = listOf(
                PlanExercise(name = "Lat machine presa larga", sets = 4, reps = "10-12"),
                PlanExercise(name = "Pulley presa stretta", sets = 3, reps = "12"),
                PlanExercise(name = "Rematore manubrio 1 braccio", sets = 3, reps = "10"),
                PlanExercise(name = "Face pull al cavo", sets = 3, reps = "15"),
                PlanExercise(name = "Curl bilanciere EZ", sets = 3, reps = "10"),
                PlanExercise(name = "Curl a martello manubri", sets = 3, reps = "12")
            )),
            WorkoutPlan(id = "p3", name = "Gambe", sub = "Quad + Posteriori", color = "ffb000", exercises = listOf(
                PlanExercise(name = "Leg press", sets = 4, reps = "12"),
                PlanExercise(name = "RDL singola gamba", sets = 3, reps = "10/lato"),
                PlanExercise(name = "Leg curl seduto", sets = 3, reps = "12"),
                PlanExercise(name = "Adductor machine", sets = 3, reps = "15"),
                PlanExercise(name = "Abductor machine", sets = 3, reps = "15"),
                PlanExercise(name = "Calf raise in piedi", sets = 3, reps = "15")
            )),
            WorkoutPlan(id = "p4", name = "Spalle & Core", sub = "Postura + V-Shape", color = "ff6a00", exercises = listOf(
                PlanExercise(name = "Arnold press manubri", sets = 4, reps = "10"),
                PlanExercise(name = "Lateral raise cavo", sets = 3, reps = "12"),
                PlanExercise(name = "Rear delt fly manubri", sets = 3, reps = "12"),
                PlanExercise(name = "Shrug manubri", sets = 3, reps = "15"),
                PlanExercise(name = "Plank laterale", sets = 3, reps = "30s/lato"),
                PlanExercise(name = "Crunch al cavo", sets = 3, reps = "15")
            ))
        )
    }
}

private fun log10(x: Double): Double = ln(x) / ln(10.0)
