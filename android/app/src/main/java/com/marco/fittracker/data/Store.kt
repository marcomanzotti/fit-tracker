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

    val daily = mutableStateListOf<DailyEntry>()
    val sessions = mutableStateListOf<WorkoutSession>()
    val body = mutableStateListOf<BodyEntry>()
    val plans = mutableStateListOf<WorkoutPlan>()
    val cardioTypes = mutableStateListOf<CardioType>()
    val foods = mutableStateListOf<FoodItem>()
    val exerciseItems = mutableStateListOf<ExerciseItem>()
    val recipes = mutableStateListOf<Recipe>()
    var prefs by mutableStateOf(Prefs())

    private val dataFile: File get() = File(getApplication<Application>().filesDir, "fittracker.json")
    private var loaded = false

    init { load() }

    // MARK: - Persistence
    private fun load() {
        runCatching {
            if (dataFile.exists()) {
                val a = json.decodeFromString<AppData>(dataFile.readText())
                daily.addAll(a.daily); sessions.addAll(a.sessions)
                body.addAll(a.body); plans.addAll(a.plans); prefs = a.prefs
                cardioTypes.addAll(a.cardioTypes)
                foods.addAll(a.foods)
                exerciseItems.addAll(a.exerciseItems)
                recipes.addAll(a.recipes)
            }
        }
        if (plans.isEmpty()) plans.addAll(defaultPlans())
        if (cardioTypes.isEmpty()) cardioTypes.addAll(defaultCardioTypes())
        L.lang = prefs.langCode
        Units.imperial = prefs.imperial
        loaded = true
        save()
    }

    fun syncLang() { L.lang = prefs.langCode; Units.imperial = prefs.imperial }

    private fun snapshot() = AppData(
        daily.toList(), sessions.toList(), body.toList(), plans.toList(), prefs,
        cardioTypes.toList(), foods.toList(), exerciseItems.toList(), recipes.toList()
    )

    fun save() {
        if (!loaded) return
        runCatching {
            val text = json.encodeToString(AppData.serializer(), snapshot())
            dataFile.writeText(text)
            File(getApplication<Application>().filesDir, "backup-${today()}.json").writeText(text)
        }
    }

    fun exportText(): String = prettyJson.encodeToString(AppData.serializer(), snapshot())
    fun exportFileName(): String = "fittracker-${today()}.json"

    fun importText(text: String): Boolean = runCatching {
        val a = json.decodeFromString<AppData>(text)
        daily.clear(); daily.addAll(a.daily)
        sessions.clear(); sessions.addAll(a.sessions)
        body.clear(); body.addAll(a.body)
        plans.clear(); plans.addAll(if (a.plans.isEmpty()) defaultPlans() else a.plans)
        cardioTypes.clear(); cardioTypes.addAll(if (a.cardioTypes.isEmpty()) defaultCardioTypes() else a.cardioTypes)
        foods.clear(); foods.addAll(a.foods)
        exerciseItems.clear(); exerciseItems.addAll(a.exerciseItems)
        recipes.clear(); recipes.addAll(a.recipes)
        prefs = a.prefs
        L.lang = prefs.langCode
        Units.imperial = prefs.imperial
        save(); true
    }.getOrDefault(false)

    // MARK: - Derived data
    val sortedDaily: List<DailyEntry> get() = daily.sortedBy { it.date }

    fun metricSeries(value: (DailyEntry) -> Double?, months: Int = 2): List<Pair<String, Double>> {
        val cutoff = LocalDate.now().minusMonths(months.toLong()).toString()
        val entries = sortedDaily.filter { it.date >= cutoff && value(it) != null }
        if (entries.size < 2) return emptyList()
        val grouped = LinkedHashMap<String, MutableList<Double>>()
        for (e in entries) {
            val d = LocalDate.parse(e.date)
            val monday = d.minusDays((d.dayOfWeek.value - 1).toLong())
            val label = monday.format(java.time.format.DateTimeFormatter.ofPattern("d MMM"))
            grouped.getOrPut(label) { mutableListOf() }.add(value(e)!!)
        }
        return grouped.map { (label, vals) -> label to (vals.sum() / vals.size) }
    }

    val lastWeight: Double
        get() = sortedDaily.lastOrNull { it.weight != null }?.weight ?: prefs.startWeight

    fun plan(id: String): WorkoutPlan? = plans.firstOrNull { it.id == id }
    fun cardioType(id: String): CardioType? = cardioTypes.firstOrNull { it.id == id }

    fun bmi(w: Double): Double = Math.round((w / (prefs.height * prefs.height)) * 10.0) / 10.0

    /** US-Navy body-fat estimate (cm). Sex-specific: women use waist+hip−neck. */
    fun bfNavy(waist: Double?, neck: Double?, hip: Double? = null): Double? {
        val h = prefs.height * 100
        if (waist == null || neck == null || h <= 0) return null
        val v: Double = if (prefs.sexCode == "f") {
            if (hip == null || (waist + hip) <= neck) return null
            163.205 * log10(waist + hip - neck) - 97.684 * log10(h) - 78.387
        } else {
            if (waist <= neck) return null
            86.010 * log10(waist - neck) - 70.041 * log10(h) + 36.76
        }
        return Math.round(v * 10.0) / 10.0
    }

    fun hasCheckedIn(): Boolean = daily.any { it.date == today() && it.weight != null }

    val streak: Int
        get() {
            val dates = HashSet<String>()
            daily.forEach { dates.add(it.date) }
            sessions.forEach { dates.add(it.date) }
            var d = LocalDate.now()
            if (!dates.contains(d.toString())) d = d.minusDays(1)
            var n = 0
            repeat(400) {
                val s = d.toString()
                if (dates.contains(s)) { n += 1; d = d.minusDays(1) } else return n
            }
            return n
        }

    val latestVO2: Double?
        get() = sortedDaily.lastOrNull { (it.vo2max ?: 0.0) > 0 }?.vo2max

    // MARK: - Next workout (schedule-aware)
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

    fun nextUp(): NextItem? {
        if (prefs.hasSchedule) {
            val sched = prefs.weekSchedule
            val now = LocalDate.now()
            val todayMon = (now.dayOfWeek.value - 1).coerceIn(0, 6)
            val trainedToday = sessions.any { it.date == today() }
            for (off in 0 until 8) {
                if (off == 0 && trainedToday) continue
                scheduleItem(sched[(todayMon + off) % 7])?.let { return it }
            }
            return null
        }
        return nextPlanRotation()?.let { NextItem.Plan(it) }
    }

    fun nextStrengthPlan(): WorkoutPlan? {
        if (prefs.hasSchedule) (nextUp() as? NextItem.Plan)?.let { return it.plan }
        return nextPlanRotation()
    }

    fun nextPlanRotation(): WorkoutPlan? {
        if (plans.isEmpty()) return null
        val last = sessions.sortedByDescending { it.date }.firstOrNull() ?: return plans.first()
        val idx = plans.indexOfFirst { it.id == last.planId }
        if (idx < 0) return plans.first()
        return plans[(idx + 1) % plans.size]
    }

    fun setSchedule(weekday: Int, id: String) {
        if (weekday !in 0..6) return
        val s = prefs.weekSchedule.toMutableList(); s[weekday] = id
        val keep = s.any { it.isNotEmpty() && it != "rest" }
        updatePrefs(prefs.copy(schedule = if (keep) s else null))
    }
    fun clearSchedule() { updatePrefs(prefs.copy(schedule = null)) }

    fun exercisePR(name: String): Double {
        var mx = 0.0
        for (s in sessions) for (e in s.exercises) if (e.name == name) mx = maxOf(mx, e.maxWeight)
        return mx
    }

    fun isBodyweightExercise(name: String): Boolean {
        exerciseItems.firstOrNull { it.name == name }?.let { return it.isBodyweight }
        for (p in plans) { p.exercises.firstOrNull { it.name == name }?.let { return it.bodyweight } }
        return false
    }

    fun lastSession(planId: String): WorkoutSession? =
        sessions.filter { it.planId == planId && it.date != today() }
            .sortedByDescending { it.date }.firstOrNull()

    fun suggested(planId: String, exercise: String): Double? {
        val prog = progression(planId, exercise)
        if (prog != ProgressionHint.ADD_LOAD) return null
        val last = lastSession(planId) ?: return null
        val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
        if (ex.sets.isEmpty()) return null
        val allDone = ex.sets.all { pf(it.reps) > 0 && pf(it.weight) > 0 }
        if (!allDone) return null
        return ex.maxWeight + 2.5
    }

    fun estimateCalories(s: WorkoutSession): Int {
        s.caloriesManual?.let { if (it > 0) return it }
        val w = lastWeight
        val dur = s.durationMinutesD
        if (dur == null || dur <= 0)
            return (s.volume * 0.022 + s.totalSets * 3 + 60).roundToInt()
        val hours = dur / 60.0
        val speed = s.distanceKm?.let { if (it > 0) it / hours else null }
        val hrr = hrReserve(s.avgHR, s)
        val met = sportMET(s.sportType, speed, hrr)
        var kcal = maxOf(1.0, met - 1.0) * w * hours
        if (s.sportType == Sport.STRENGTH) kcal += minOf(90.0, s.volume * 0.008)
        return maxOf(1, kcal.roundToInt())
    }

    private fun hrReserve(hr: Int?, s: WorkoutSession): Double? {
        if (hr == null || hr <= 0) return null
        val rest = prefs.restHRorDefault.toDouble()
        val mx = (s.maxHRSes ?: prefs.estMaxHR).toDouble()
        if (mx <= rest) return null
        return ((hr - rest) / (mx - rest)).coerceIn(0.0, 1.0)
    }

    private fun sportMET(sport: Sport, speedKmh: Double?, hrr: Double?): Double = when (sport) {
        Sport.RUNNING -> when {
            speedKmh != null && speedKmh > 0 -> maxOf(6.0, 0.95 * speedKmh + 0.5)
            hrr != null -> 3.0 + 9.0 * hrr; else -> 9.5
        }
        Sport.CYCLING -> when {
            speedKmh != null && speedKmh > 0 -> when {
                speedKmh < 16 -> 3.8; speedKmh < 20 -> 5.0; speedKmh < 24 -> 6.8
                speedKmh < 28 -> 8.5; speedKmh < 33 -> 10.5; else -> 12.5
            }
            hrr != null -> 2.5 + 7.0 * hrr; else -> 6.0
        }
        Sport.WALKING -> when {
            speedKmh != null && speedKmh > 0 -> when {
                speedKmh < 3.2 -> 2.5; speedKmh < 4.8 -> 3.3; speedKmh < 6.4 -> 4.5
                speedKmh < 8.0 -> 6.0; else -> 7.5
            }
            hrr != null -> 2.0 + 4.0 * hrr; else -> 3.5
        }
        Sport.SWIMMING -> when {
            speedKmh != null && speedKmh > 0 -> if (speedKmh > 4) 10.0 else if (speedKmh < 2.5) 6.0 else 8.3
            hrr != null -> 4.0 + 7.0 * hrr; else -> 8.0
        }
        Sport.STRENGTH -> if (hrr != null) 2.8 + 5.5 * hrr else 4.5
        else -> if (hrr != null) 2.0 + 7.0 * hrr else 6.0
    }

    // Banister TRIMP: duration * HRR * exp(b * HRR) where b=1.92 (men)
    fun trimp(s: WorkoutSession): Double? {
        val dur = s.durationMinutesD ?: return null
        if (dur <= 0) return null
        val hrr = hrReserve(s.avgHR, s) ?: return null
        val b = if (prefs.sexCode == "f") 1.67 else 1.92
        return dur * hrr * kotlin.math.exp(b * hrr)
    }

    // MARK: - Nutrition targets
    data class EnergyTargets(
        val bmr: Double, val tdee: Double, val target: Double, val mode: GoalMode,
        val protein: Double, val carbs: Double, val fat: Double
    )

    fun energyTargets(): EnergyTargets {
        val w = lastWeight; val h = prefs.height * 100   // cm
        val age = prefs.age?.toDouble() ?: 30.0
        val bmr = if (prefs.sexCode == "m")
            10 * w + 6.25 * h - 5 * age + 5
        else
            10 * w + 6.25 * h - 5 * age - 161
        val tdee = bmr * prefs.activityLevel.multiplier
        val mode = prefs.goal
        val target = (tdee * (1 + mode.calorieAdjust)).coerceAtLeast(1200.0)
        // Protein: 2.0 g/kg; Fat: 0.9 g/kg; Carbs: remainder
        val protein = (w * 2.0).roundToInt().toDouble()
        val fat = (w * 0.9).roundToInt().toDouble()
        val carbs = ((target - protein * 4 - fat * 9) / 4).coerceAtLeast(0.0).roundToInt().toDouble()
        return EnergyTargets(bmr.roundToInt().toDouble(), tdee.roundToInt().toDouble(),
            target.roundToInt().toDouble(), mode, protein, carbs, fat)
    }

    // MARK: - Nutrition storage
    fun dailyEntry(date: String): DailyEntry? = daily.firstOrNull { it.date == date }

    fun upsertDaily(date: String, mutate: (DailyEntry) -> DailyEntry) {
        val existing = daily.firstOrNull { it.date == date } ?: DailyEntry(date = date)
        val updated = mutate(existing)
        daily.removeAll { it.date == date }
        daily.add(updated)
        save()
    }

    fun saveNutritionTotal(date: String, kcal: Int?, protein: Double?, carbs: Double?, fat: Double?) {
        upsertDaily(date) { e -> e.copy(kcal = kcal, protein = protein, carbs = carbs, fat = fat, meals = null) }
    }

    fun saveNutritionMeals(date: String, meals: Map<String, MealEntry>) {
        val clean = meals.filter { !it.value.isEmpty }
        upsertDaily(date) { e ->
            e.copy(meals = if (clean.isEmpty()) null else clean, kcal = null, protein = null, carbs = null, fat = null)
        }
        for (m in clean.values) { for (l in (m.foods ?: emptyList())) { l.foodId?.let { touchFood(it) } } }
    }

    fun saveDayFoods(date: String, foods: List<FoodLog>) {
        upsertDaily(date) { e ->
            if (foods.isEmpty()) e.copy(foods = null)
            else e.copy(foods = foods, kcal = null, protein = null, carbs = null, fat = null, meals = null)
        }
        for (l in foods) { l.foodId?.let { touchFood(it) } }
    }

    fun saveManualSleep(hours: Double?, score: Int?, hrv: Double?, sleepHR: Int?) {
        val t = today()
        upsertDaily(t) { e ->
            e.copy(
                sleepHours = if (hours != null && hours > 0) hours else e.sleepHours,
                sleep = if (score != null) score.coerceIn(0, 100) else e.sleep,
                hrvSDNN = if (hrv != null && hrv > 0) hrv else e.hrvSDNN,
                sleepHR = if (sleepHR != null && sleepHR > 0) sleepHR else e.sleepHR
            )
        }
    }

    data class NutPoint(val date: String, val kcal: Int, val protein: Double, val carbs: Double, val fat: Double)
    fun nutritionSeries(days: Int = 90): List<NutPoint> =
        sortedDaily.filter { it.hasNutrition }.takeLast(days).map {
            NutPoint(it.date, it.totalKcal, it.totalProtein, it.totalCarbs, it.totalFat)
        }

    // MARK: - Health Connect sample import (gap-fill only, manual values win)
    fun applyHealthSamples(samples: List<HealthDaySample>) {
        for (s in samples) {
            val existing = daily.firstOrNull { it.date == s.date } ?: DailyEntry(date = s.date)
            var e = existing
            if (e.stepsManual != true && s.steps != null && s.steps > 0) e = e.copy(steps = s.steps)
            if (e.restHR == null && s.restHR != null && s.restHR > 0) e = e.copy(restHR = s.restHR)
            if (e.hrvSDNN == null && s.rmssd != null && s.rmssd > 0) e = e.copy(hrvSDNN = s.rmssd)
            if (e.activeKcal == null && s.activeKcal != null && s.activeKcal > 0) e = e.copy(activeKcal = s.activeKcal)
            if (e.exerciseMin == null && s.exerciseMin != null && s.exerciseMin > 0) e = e.copy(exerciseMin = s.exerciseMin)
            if (e.sleepHours == null && s.sleepHours != null && s.sleepHours > 0) e = e.copy(sleepHours = s.sleepHours)
            if (e.sleepHR == null && s.sleepHR != null && s.sleepHR > 0) e = e.copy(sleepHR = s.sleepHR)
            if (e.vo2max == null && s.vo2max != null && s.vo2max > 0) e = e.copy(vo2max = s.vo2max)
            if (e.sleep == null) {
                val h = e.sleepHours ?: s.sleepHours
                if (h != null && h > 0) e = e.copy(sleep = sleepScore(h))
            }
            daily.removeAll { it.date == s.date }
            daily.add(e)
        }
        save()
    }

    // MARK: - Health Connect workout import
    // Mirrors iOS applyHealthWorkouts: dedup by UUID, skip same-day/sport/duration overlaps.
    fun applyHealthWorkouts(workouts: List<HealthWorkout>): Pair<Int, List<String>> {
        var imported = 0
        val srcs = mutableSetOf<String>()
        for (w in workouts) {
            if (sessions.any { it.healthUUID == w.uuid }) continue
            val isStrength = w.sport == "strength"
            val overlaps = sessions.any { s ->
                if (s.date != w.date) return@any false
                val sameSport = if (isStrength) (s.sport == null) else (s.sport == w.sport)
                if (!sameSport) return@any false
                val dur = s.durationSeconds ?: 0
                Math.abs(dur - w.durationSec) <= 120
            }
            if (overlaps) continue
            sessions.add(sessionFromHealth(w))
            imported++
            if (w.sourceName.isNotEmpty()) srcs.add(w.sourceName)
        }
        if (imported > 0) save()
        return imported to srcs.sorted()
    }

    private fun sessionFromHealth(w: HealthWorkout): WorkoutSession {
        val isStrength = w.sport == "strength"
        val sportType = Sport.from(w.sport)
        val sessionName = w.displayName.ifEmpty { sportType.label() }
        return WorkoutSession(
            date = w.date, planId = "health-${w.sport}", planName = sessionName,
            planColor = "34c759",   // Apple Health green
            sport = if (isStrength) null else w.sport,
            durationSec = if (w.durationSec > 0) w.durationSec else null,
            avgHR = w.avgHR?.takeIf { it > 0 },
            maxHRSes = w.maxHR?.takeIf { it > 0 },
            distanceKm = w.distance?.takeIf { it > 0 },
            caloriesManual = w.calories?.takeIf { it > 0 },
            healthUUID = w.uuid,
            source = w.sourceName.ifEmpty { null }
        )
    }

    fun importHealthWorkout(w: HealthWorkout): WorkoutSession {
        sessions.firstOrNull { it.healthUUID == w.uuid }?.let { return it }
        val s = sessionFromHealth(w); sessions.add(s); save(); return s
    }

    // MARK: - Saved food list
    fun recentFoods(): List<FoodItem> = foods.sortedWith(
        compareByDescending<FoodItem> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )
    fun food(barcode: String): FoodItem? = foods.firstOrNull { it.barcode == barcode }

    fun saveFood(f: FoodItem): FoodItem {
        val i = foods.indexOfFirst { it.id == f.id }
        if (i >= 0) foods[i] = f else foods.add(f)
        save(); return f
    }
    fun deleteFood(id: String) { foods.removeAll { it.id == id }; save() }
    fun touchFood(id: String) {
        val i = foods.indexOfFirst { it.id == id }
        if (i >= 0) { foods[i] = foods[i].copy(lastUsed = today()); save() }
    }

    // MARK: - Saved recipes
    fun recentRecipes(): List<Recipe> = recipes.sortedWith(
        compareByDescending<Recipe> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )

    fun saveRecipe(r: Recipe): Recipe {
        val i = recipes.indexOfFirst { it.id == r.id }
        if (i >= 0) recipes[i] = r else recipes.add(r)
        save(); return r
    }
    fun deleteRecipe(id: String) { recipes.removeAll { it.id == id }; save() }
    fun touchRecipe(id: String) {
        val i = recipes.indexOfFirst { it.id == id }
        if (i >= 0) { recipes[i] = recipes[i].copy(lastUsed = today()); save() }
    }

    // MARK: - Exercise library
    fun recentExercises(): List<ExerciseItem> = exerciseItems.sortedWith(
        compareByDescending<ExerciseItem> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )

    fun touchExerciseInLibrary(name: String, isBodyweight: Boolean = false): ExerciseItem {
        val i = exerciseItems.indexOfFirst { it.name == name }
        if (i >= 0) {
            val e = exerciseItems[i].let { ex ->
                ex.copy(
                    lastUsed = today(),
                    isBodyweight = if (isBodyweight) true else ex.isBodyweight,
                    base = ex.base ?: normalizedBase(name),
                    category = ex.category ?: guessCategory(name).raw
                )
            }
            exerciseItems[i] = e; save(); return e
        }
        val item = ExerciseItem(name = name, isBodyweight = isBodyweight, lastUsed = today(),
            base = normalizedBase(name), category = guessCategory(name).raw)
        exerciseItems.add(item); save(); return item
    }

    fun registerPlanExercises(plan: WorkoutPlan) {
        for (ex in plan.exercises) {
            val name = ex.name.trim(); if (name.isEmpty()) continue
            touchExerciseInLibrary(name, ex.bodyweight)
            if (ex.muscle != null && ex.muscle.isNotEmpty()) {
                val i = exerciseItems.indexOfFirst { it.name == name }
                if (i >= 0) exerciseItems[i] = exerciseItems[i].copy(category = ex.muscle)
            }
        }
        save()
    }

    fun exerciseBase(name: String): String {
        val item = exerciseItems.firstOrNull { it.name == name }
        return item?.base?.takeIf { it.isNotEmpty() } ?: normalizedBase(name)
    }

    fun exerciseCategory(name: String): String {
        val item = exerciseItems.firstOrNull { it.name == name }
        return item?.category?.takeIf { it.isNotEmpty() } ?: guessCategory(name).raw
    }

    data class ExFamily(val base: String, val category: String, val names: List<String>)

    fun exerciseFamilies(): List<ExFamily> {
        val byBase = LinkedHashMap<String, Pair<String, MutableList<String>>>()
        for ((_, name) in allExerciseNames()) {
            if (name.isEmpty()) continue
            val base = exerciseBase(name)
            val entry = byBase.getOrPut(base) { exerciseCategory(name) to mutableListOf() }
            if (!entry.second.contains(name)) entry.second.add(name)
        }
        return byBase.map { ExFamily(it.key, it.value.first, it.value.second) }
            .sortedBy { it.base.lowercase() }
    }

    data class ExPoint(val date: String, val maxW: Double, val vol: Double)
    fun exerciseHistory(name: String): List<ExPoint> =
        sessions.filter { s -> s.exercises.any { it.name == name } }
            .sortedBy { it.date }
            .map { s ->
                val ex = s.exercises.first { it.name == name }
                ExPoint(fmtShort(s.date), ex.maxWeight, Math.round(ex.volume).toDouble())
            }

    fun exerciseHistory(familyBase: String): List<ExPoint> {
        val names = exerciseItems.filter { exerciseBase(it.name) == familyBase }.map { it.name }.toHashSet()
        plans.forEach { p -> p.exercises.forEach { if (exerciseBase(it.name) == familyBase) names.add(it.name) } }
        return sessions.filter { s -> s.exercises.any { it.name in names } }
            .sortedBy { it.date }
            .map { s ->
                val exs = s.exercises.filter { it.name in names }
                ExPoint(fmtShort(s.date), exs.maxOfOrNull { it.maxWeight } ?: 0.0,
                    Math.round(exs.sumOf { it.volume }).toDouble())
            }
    }

    // MARK: - Body data
    val bodyLatest: BodyEntry? get() = body.sortedByDescending { it.date }.firstOrNull()
    val bodyPrev: BodyEntry?
        get() { val s = body.sortedByDescending { it.date }; return if (s.size > 1) s[1] else null }

    val currentBF: Double?
        get() {
            val bl = bodyLatest ?: return null
            return bl.bfManual ?: bfNavy(bl.waist, bl.neck, bl.hips)
        }

    // MARK: - Mutations
    fun saveCheckIn(weight: Double?, sleep: Int?, restHR: Int? = null, sleepHR: Int? = null) {
        val t = today()
        val existing = daily.firstOrNull { it.date == t } ?: DailyEntry(date = t)
        val entry = existing.copy(
            weight = weight ?: existing.weight,
            sleep = sleep ?: existing.sleep,
            restHR = restHR ?: existing.restHR,
            sleepHR = sleepHR ?: existing.sleepHR
        )
        daily.removeAll { it.date == t }; daily.add(entry); save()
    }

    fun saveBodyFat(v: Double) {
        val t = today()
        val rec = (if (bodyLatest?.date == t) bodyLatest!! else BodyEntry(date = t)).copy(bfManual = v)
        body.removeAll { it.date == t }; body.add(rec); save()
    }

    fun saveMeasurements(values: Map<String, Double>) {
        val t = today()
        var rec = if (bodyLatest?.date == t) bodyLatest!! else BodyEntry(date = t)
        for ((k, v) in values) if (v > 0) rec = rec.withValue(k, v)
        body.removeAll { it.date == t }; body.add(rec); save()
    }

    fun addSession(s: WorkoutSession) { sessions.add(s); save() }
    fun deleteSession(id: String) { sessions.removeAll { it.id == id }; save() }
    fun updateSession(s: WorkoutSession) {
        val i = sessions.indexOfFirst { it.id == s.id }
        if (i >= 0) { sessions[i] = s; save() }
    }

    fun upsertPlan(p: WorkoutPlan) {
        val idx = plans.indexOfFirst { it.id == p.id }
        if (idx >= 0) plans[idx] = p else plans.add(p); save()
    }
    fun deletePlan(id: String) { plans.removeAll { it.id == id }; save() }

    fun addExerciseToPlan(planId: String, name: String) {
        val idx = plans.indexOfFirst { it.id == planId }
        if (idx < 0) return
        val p = plans[idx]
        if (p.exercises.any { it.name.equals(name, ignoreCase = true) }) return
        plans[idx] = p.copy(exercises = p.exercises + PlanExercise(name = name, sets = 3, reps = "10"))
        save()
    }

    fun commitCardioType(ct: CardioType) {
        val i = cardioTypes.indexOfFirst { it.id == ct.id }
        if (i >= 0) cardioTypes[i] = ct else cardioTypes.add(ct); save()
    }
    fun deleteCardioType(id: String) { cardioTypes.removeAll { it.id == id }; save() }

    fun isRestDay(date: String): Boolean = prefs.restDaySet.contains(date)
    fun setRestDay(date: String, on: Boolean) {
        val set = prefs.restDaySet.toMutableSet()
        if (on) set.add(date) else set.remove(date)
        updatePrefs(prefs.copy(restDays = if (set.isEmpty()) null else set.sorted()))
    }
    fun toggleRestDay(date: String) = setRestDay(date, !isRestDay(date))

    fun quickInsertSession(plan: WorkoutPlan, date: String): WorkoutSession {
        val last = sessions.filter { it.planId == plan.id }.sortedByDescending { it.date }.firstOrNull()
        val exercises = if (last != null) {
            last.exercises.map { e ->
                LoggedExercise(name = e.name,
                    sets = e.sets.map { SetEntry(reps = it.reps, weight = it.weight) },
                    notes = "", target = e.target, supersetGroup = e.supersetGroup, method = e.method)
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
            durationSec = last?.durationSeconds, avgHR = last?.avgHR, maxHRSes = last?.maxHRSes)
        setRestDay(date, false); sessions.add(s); save(); return s
    }

    fun quickInsertCardio(type: CardioType, date: String): WorkoutSession {
        val pid = "cardio-${type.id}"
        val last = sessions.filter { it.planId == pid }.sortedByDescending { it.date }.firstOrNull()
        val s = WorkoutSession(date = date, planId = pid, planName = type.name,
            planColor = type.color, exercises = emptyList(), sport = type.sport,
            durationSec = last?.durationSeconds, avgHR = last?.avgHR,
            distanceKm = last?.distanceKm, paceManual = last?.paceManual)
        setRestDay(date, false); sessions.add(s); save(); return s
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
    fun allPRs(): Map<String, PRInfo> {
        val prs = LinkedHashMap<String, PRInfo>()
        for (p in plans) for (e in p.exercises) if (!prs.containsKey(e.name)) prs[e.name] = PRInfo(0.0, null)
        for (s in sessions.sortedBy { it.date }) for (e in s.exercises) {
            val w = e.maxWeight
            if (w >= (prs[e.name]?.weight ?: 0.0)) prs[e.name] = PRInfo(w, s.date)
        }
        return prs
    }

    fun allExerciseNames(): List<Pair<String, String>> {
        val seen = HashSet<String>(); val out = ArrayList<Pair<String, String>>()
        for (p in plans) for (e in p.exercises) if (e.name.isNotEmpty() && seen.add(e.name)) out.add(p.name to e.name)
        for (item in exerciseItems.sortedByDescending { it.lastUsed ?: "" })
            if (item.name.isNotEmpty() && seen.add(item.name)) out.add(L.t("ex.library") to item.name)
        return out
    }

    fun updatePrefs(p: Prefs) { prefs = p; save() }

    // MARK: - Progressive overload hints (mirrors iOS progression())
    enum class ProgressionHint { ADD_LOAD, ADD_REPS, HOLD, DELOAD }

    fun progression(planId: String, exercise: String): ProgressionHint? {
        val last = lastSession(planId) ?: return null
        val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
        if (ex.sets.isEmpty()) return null
        val allDone = ex.sets.all { pf(it.reps) > 0 }
        val someEmpty = ex.sets.any { !it.filled }
        return when {
            someEmpty -> ProgressionHint.HOLD
            allDone -> ProgressionHint.ADD_LOAD
            else -> ProgressionHint.ADD_REPS
        }
    }

    // MARK: - Static helpers
    companion object {
        fun sleepScore(fromHours: Double): Int {
            val penalty = Math.abs(fromHours - 8.0) * 12.0
            return maxOf(0, minOf(100, (100 - penalty).roundToInt()))
        }

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

        fun normalizedBase(name: String): String {
            var s = " ${name.lowercase()} "
            val qualifiers = listOf("wide-grip", "wide grip", "close-grip", "close grip",
                "narrow-grip", "narrow grip", "neutral-grip", "neutral grip",
                "reverse-grip", "reverse grip", "rear-delt", "rear delt",
                "single-arm", "single arm", "one-arm", "one arm", "wide", "close", "narrow")
            for (q in qualifiers) s = s.replace(" $q ", " ")
            val cleaned = s.replace("  ", " ").trim()
            if (cleaned.isEmpty()) return name
            return cleaned[0].uppercaseChar() + cleaned.drop(1)
        }

        fun guessCategory(name: String): MuscleGroup {
            val n = name.lowercase()
            fun has(ks: List<String>) = ks.any { n.contains(it) }
            if (has(listOf("squat", "leg press", "leg curl", "leg extension", "lunge", "calf",
                    "hamstring", "quad", "glute", "rdl", "romanian", "hip thrust"))) return MuscleGroup.LEGS
            if (has(listOf("bench", "chest", "fly", "pec", "push-up", "push up", "dip"))) return MuscleGroup.CHEST
            if (has(listOf("row", "pulldown", "pull-up", "pull up", "chin-up", "lat ", "deadlift",
                    "pull-over", "back extension"))) return MuscleGroup.BACK
            if (has(listOf("shoulder", "lateral raise", "delt", "overhead press", "ohp",
                    "upright row", "face pull", "shrug"))) return MuscleGroup.SHOULDERS
            if (has(listOf("curl", "triceps", "biceps", "pushdown", "skull", "preacher",
                    "hammer", "forearm"))) return MuscleGroup.ARMS
            if (has(listOf("plank", "crunch", "ab ", "abs", "core", "sit-up", "sit up",
                    "leg raise", "russian twist"))) return MuscleGroup.CORE
            if (has(listOf("run", "cycl", "bike", "swim", "walk", "rowing", "elliptical",
                    "jump rope"))) return MuscleGroup.CARDIO
            return MuscleGroup.OTHER
        }
    }
}

// MARK: - Units helper (mirrors iOS Units)
object Units {
    var imperial: Boolean = false
    val wLabel: String get() = if (imperial) "lb" else "kg"
    val heightLabel: String get() = if (imperial) "in" else "cm"
    fun wIn(v: Double): Double = if (imperial) v / 2.20462 else v
    fun wOut(v: Double): Double = if (imperial) v * 2.20462 else v
    fun heightIn(v: Double): Double = if (imperial) v * 2.54 / 100 else v / 100
    fun heightOut(hm: Double): Double = if (imperial) hm * 100 / 2.54 else hm * 100
    fun dispW(v: Double): String = trimNum(if (imperial) Math.round(wOut(v) * 10.0) / 10.0 else Math.round(v * 10.0) / 10.0)
}

private fun log10(x: Double): Double = ln(x) / ln(10.0)
