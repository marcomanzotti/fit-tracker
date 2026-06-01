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
    val cardioTypes = mutableStateListOf<CardioType>()
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
                cardioTypes.addAll(a.cardioTypes)
            }
        }
        if (plans.isEmpty()) plans.addAll(defaultPlans())
        if (cardioTypes.isEmpty()) cardioTypes.addAll(defaultCardioTypes())
        L.lang = prefs.langCode
        loaded = true
        save()
    }

    fun syncLang() { L.lang = prefs.langCode }

    private fun snapshot() = AppData(daily.toList(), sessions.toList(), body.toList(), plans.toList(), prefs, cardioTypes.toList())

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
        cardioTypes.clear(); cardioTypes.addAll(if (a.cardioTypes.isEmpty()) defaultCardioTypes() else a.cardioTypes)
        prefs = a.prefs
        L.lang = prefs.langCode
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

    /** Consecutive days with a check-in or workout. Today is a grace period: the
     *  streak stays alive all day even before today's check-in, and only breaks
     *  after a full day has passed with nothing logged. */
    val streak: Int
        get() {
            val dates = HashSet<String>()
            daily.forEach { dates.add(it.date) }
            sessions.forEach { dates.add(it.date) }
            var d = LocalDate.now()
            if (!dates.contains(d.toString())) d = d.minusDays(1)   // today still open
            var n = 0
            repeat(400) {
                val s = d.toString()
                if (dates.contains(s)) { n += 1; d = d.minusDays(1) } else return n
            }
            return n
        }

    // MARK: - Next workout (schedule-aware)
    /** What to train next: a strength plan or a cardio activity. */
    sealed class NextItem {
        data class Plan(val plan: WorkoutPlan) : NextItem()
        data class Cardio(val cardio: CardioType) : NextItem()
        val name: String get() = when (this) { is Plan -> plan.name; is Cardio -> cardio.name }
        val color: String get() = when (this) { is Plan -> plan.color; is Cardio -> cardio.color }
        val sub: String get() = when (this) { is Plan -> plan.sub; is Cardio -> cardio.sportType.label() }
        val isCardio: Boolean get() = this is Cardio
    }

    private fun scheduleItem(id: String): NextItem? {
        if (id.isEmpty() || id == "rest") return null
        plans.firstOrNull { it.id == id }?.let { return NextItem.Plan(it) }
        cardioTypes.firstOrNull { it.id == id }?.let { return NextItem.Cardio(it) }
        return null
    }

    /** The next thing to train (schedule first, else rotation). */
    fun nextUp(): NextItem? {
        if (prefs.hasSchedule) {
            val sched = prefs.weekSchedule
            val now = LocalDate.now()
            val todayMon = (now.dayOfWeek.value - 1).coerceIn(0, 6)   // Monday = 0
            val trainedToday = sessions.any { it.date == today() }
            for (off in 0 until 8) {
                if (off == 0 && trainedToday) continue
                scheduleItem(sched[(todayMon + off) % 7])?.let { return it }
            }
            return null
        }
        return nextPlanRotation()?.let { NextItem.Plan(it) }
    }

    /** Next strength plan only (used by progressive-overload suggestions). */
    fun nextStrengthPlan(): WorkoutPlan? {
        if (prefs.hasSchedule) (nextUp() as? NextItem.Plan)?.let { return it.plan }
        return nextPlanRotation()
    }

    /** Rotation: the plan after the most recent session's plan, looping. */
    fun nextPlanRotation(): WorkoutPlan? {
        if (plans.isEmpty()) return null
        val last = sessions.sortedByDescending { it.date }.firstOrNull() ?: return plans.first()
        val idx = plans.indexOfFirst { it.id == last.planId }
        if (idx < 0) return plans.first()
        return plans[(idx + 1) % plans.size]
    }

    fun setSchedule(weekday: Int, id: String) {
        if (weekday !in 0..6) return
        val s = prefs.weekSchedule.toMutableList()
        s[weekday] = id
        val keep = s.any { it.isNotEmpty() && it != "rest" }
        updatePrefs(prefs.copy(schedule = if (keep) s else null))
    }
    fun clearSchedule() { updatePrefs(prefs.copy(schedule = null)) }

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

    /** Calories from the user's global data: Keytel (HR-based) when avg HR is
     *  available, MET-based for cardio, else the original strength heuristic. */
    fun estimateCalories(s: WorkoutSession): Int {
        s.caloriesManual?.let { if (it > 0) return it }
        val w = lastWeight
        val hr = s.avgHR; val dur = s.durationMin
        if (hr != null && hr > 0 && dur != null && dur > 0) {
            val age = (prefs.age ?: 30).toDouble()
            val perMin = if (prefs.sexCode == "f")
                (-20.4022 + 0.4472 * hr - 0.1263 * w + 0.074 * age) / 4.184
            else
                (-55.0969 + 0.6309 * hr + 0.1988 * w + 0.2017 * age) / 4.184
            return maxOf(0, (perMin * dur).roundToInt())
        }
        if (s.sportType.isCardio && dur != null && dur > 0) {
            val met = when (s.sportType) {
                Sport.RUNNING -> 9.8; Sport.SWIMMING -> 8.0; Sport.CYCLING -> 7.5
                Sport.WALKING -> 3.5; else -> 6.0
            }
            return (met * w * dur / 60).roundToInt()
        }
        return (s.volume * 0.022 + s.totalSets * 3 + 60).roundToInt()
    }

    // MARK: Cardio types
    fun commitCardioType(ct: CardioType) {
        val i = cardioTypes.indexOfFirst { it.id == ct.id }
        if (i >= 0) cardioTypes[i] = ct else cardioTypes.add(ct)
        save()
    }
    fun deleteCardioType(id: String) { cardioTypes.removeAll { it.id == id }; save() }

    // MARK: Session editing
    fun deleteSession(id: String) { sessions.removeAll { it.id == id }; save() }
    fun updateSession(s: WorkoutSession) {
        val i = sessions.indexOfFirst { it.id == s.id }
        if (i >= 0) { sessions[i] = s; save() }
    }

    // MARK: Rest days (markers, not sessions)
    fun isRestDay(date: String): Boolean = prefs.restDaySet.contains(date)
    fun setRestDay(date: String, on: Boolean) {
        val set = prefs.restDaySet.toMutableSet()
        if (on) set.add(date) else set.remove(date)
        updatePrefs(prefs.copy(restDays = if (set.isEmpty()) null else set.sorted()))
    }
    fun toggleRestDay(date: String) = setRestDay(date, !isRestDay(date))

    // MARK: Quick insert (log a workout for another day from Home or Calendar)
    /** Create a strength session for [date], prefilled from the last session of
     *  that plan (sets/reps/weights/load), or the plan template when no history. */
    fun quickInsertSession(plan: WorkoutPlan, date: String): WorkoutSession {
        val last = sessions.filter { it.planId == plan.id }.sortedByDescending { it.date }.firstOrNull()
        val exercises = if (last != null) {
            last.exercises.map { e ->
                LoggedExercise(name = e.name,
                    sets = e.sets.map { SetEntry(reps = it.reps, weight = it.weight) },
                    notes = "", target = e.target,
                    supersetGroup = e.supersetGroup, method = e.method)
            }
        } else {
            plan.exercises.map { pe ->
                LoggedExercise(name = pe.name,
                    sets = List(maxOf(1, pe.sets)) { SetEntry() },
                    target = "${pe.sets}×${pe.reps}",
                    supersetGroup = pe.supersetGroup, method = pe.method)
            }
        }
        val s = WorkoutSession(date = date, planId = plan.id, planName = plan.name,
            planColor = plan.color, exercises = exercises,
            durationMin = last?.durationMin, avgHR = last?.avgHR, maxHRSes = last?.maxHRSes)
        setRestDay(date, false)
        sessions.add(s)
        save()
        return s
    }

    /** Create a cardio session for [date], prefilled from the last log. */
    fun quickInsertCardio(type: CardioType, date: String): WorkoutSession {
        val pid = "cardio-${type.id}"
        val last = sessions.filter { it.planId == pid }.sortedByDescending { it.date }.firstOrNull()
        val s = WorkoutSession(date = date, planId = pid, planName = type.name,
            planColor = type.color, exercises = emptyList(), sport = type.sport,
            durationMin = last?.durationMin, avgHR = last?.avgHR, distanceKm = last?.distanceKm)
        setRestDay(date, false)
        sessions.add(s)
        save()
        return s
    }

    // MARK: Daily nutrition & recovery
    fun saveDailyExtras(
        kcal: Int? = null, protein: Double? = null, carbs: Double? = null,
        fat: Double? = null, salt: Double? = null, steps: Int? = null,
        rmssd: Double? = null, restHR: Int? = null, hrvSDNN: Double? = null
    ) {
        val t = today()
        val e = daily.firstOrNull { it.date == t } ?: DailyEntry(date = t)
        val ne = e.copy(
            kcal = kcal ?: e.kcal, protein = protein ?: e.protein, carbs = carbs ?: e.carbs,
            fat = fat ?: e.fat, salt = salt ?: e.salt, steps = steps ?: e.steps,
            rmssd = rmssd ?: e.rmssd, restHR = restHR ?: e.restHR, hrvSDNN = hrvSDNN ?: e.hrvSDNN
        )
        daily.removeAll { it.date == t }
        daily.add(ne)
        save()
    }

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
            WorkoutPlan(id = "p1", name = "Push", sub = "Chest + Shoulders + Triceps", color = "ff5a52", exercises = listOf(
                PlanExercise(name = "Barbell bench press", sets = 4, reps = "6-8"),
                PlanExercise(name = "Incline dumbbell press", sets = 3, reps = "8-10"),
                PlanExercise(name = "Seated dumbbell shoulder press", sets = 3, reps = "10"),
                PlanExercise(name = "Cable lateral raise", sets = 3, reps = "12-15"),
                PlanExercise(name = "Cable chest fly", sets = 3, reps = "12"),
                PlanExercise(name = "Triceps rope pushdown", sets = 3, reps = "12")
            )),
            WorkoutPlan(id = "p2", name = "Pull", sub = "Back + Biceps + Rear Delts", color = "4fb8c4", exercises = listOf(
                PlanExercise(name = "Pull-up", sets = 4, reps = "6-10"),
                PlanExercise(name = "Barbell row", sets = 3, reps = "8-10"),
                PlanExercise(name = "Lat pulldown", sets = 3, reps = "10-12"),
                PlanExercise(name = "Seated cable row", sets = 3, reps = "12"),
                PlanExercise(name = "Face pull", sets = 3, reps = "15"),
                PlanExercise(name = "EZ-bar biceps curl", sets = 3, reps = "10-12")
            )),
            WorkoutPlan(id = "p3", name = "Legs", sub = "Quads + Hamstrings + Calves", color = "ffb000", exercises = listOf(
                PlanExercise(name = "Barbell back squat", sets = 4, reps = "6-8"),
                PlanExercise(name = "Romanian deadlift", sets = 3, reps = "8-10"),
                PlanExercise(name = "Leg press", sets = 3, reps = "12"),
                PlanExercise(name = "Seated leg curl", sets = 3, reps = "12"),
                PlanExercise(name = "Leg extension", sets = 3, reps = "15"),
                PlanExercise(name = "Standing calf raise", sets = 4, reps = "15")
            ))
        )

        fun defaultCardioTypes(): List<CardioType> = listOf(
            CardioType(id = "c-run", name = "Running", sport = "running", color = "ff5a52"),
            CardioType(id = "c-swim", name = "Swimming", sport = "swimming", color = "4fb8c4"),
            CardioType(id = "c-bike", name = "Cycling", sport = "cycling", color = "7fc950"),
            CardioType(id = "c-walk", name = "Walking", sport = "walking", color = "b08fff")
        )
    }
}

private fun log10(x: Double): Double = ln(x) / ln(10.0)
