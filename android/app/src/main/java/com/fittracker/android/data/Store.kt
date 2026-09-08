package com.fittracker.android.data

import android.content.Context
import com.fittracker.android.science.ProgKind
import com.fittracker.android.science.acwr
import com.fittracker.android.science.progression
import com.fittracker.android.science.readiness
import com.fittracker.android.localization.L
import com.fittracker.android.utils.Helpers.isoFormatter
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.utils.Helpers.today
import com.fittracker.android.utils.Helpers.fmtShort
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import java.io.File
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Kotlin port of Store.swift. Mirrors its method names/semantics closely.
 * Persistence is a single JSON document (fittracker.json in app-private
 * storage) with rolling dated backups, exactly like the iOS version — minus
 * everything that depends on HealthKit, Watch sync, Live Activities or file
 * (GPX/TCX) import, which are explicitly out of scope for this Android port.
 *
 * Every mutating method updates the relevant StateFlow and then calls save().
 * The iOS version debounces autosave via Combine; here we simply save
 * synchronously after each mutation (writes are small JSON documents, so this
 * is cheap enough and much simpler to reason about correctness-wise).
 */
class Store(private val context: Context) {
    private val _daily = MutableStateFlow<List<DailyEntry>>(emptyList())
    val daily: StateFlow<List<DailyEntry>> = _daily.asStateFlow()

    private val _sessions = MutableStateFlow<List<WorkoutSession>>(emptyList())
    val sessions: StateFlow<List<WorkoutSession>> = _sessions.asStateFlow()

    private val _body = MutableStateFlow<List<BodyEntry>>(emptyList())
    val body: StateFlow<List<BodyEntry>> = _body.asStateFlow()

    private val _plans = MutableStateFlow<List<WorkoutPlan>>(emptyList())
    val plans: StateFlow<List<WorkoutPlan>> = _plans.asStateFlow()

    private val _cardioTypes = MutableStateFlow<List<CardioType>>(emptyList())
    val cardioTypes: StateFlow<List<CardioType>> = _cardioTypes.asStateFlow()

    private val _foods = MutableStateFlow<List<FoodItem>>(emptyList())
    val foods: StateFlow<List<FoodItem>> = _foods.asStateFlow()

    private val _exerciseItems = MutableStateFlow<List<ExerciseItem>>(emptyList())
    val exerciseItems: StateFlow<List<ExerciseItem>> = _exerciseItems.asStateFlow()

    private val _recipes = MutableStateFlow<List<Recipe>>(emptyList())
    val recipes: StateFlow<List<Recipe>> = _recipes.asStateFlow()

    private val _prefs = MutableStateFlow(Prefs())
    val prefs: StateFlow<Prefs> = _prefs.asStateFlow()

    private var loaded = false
    private val json = Json { ignoreUnknownKeys = true }

    init {
        load()
    }

    // MARK: Persistence -----------------------------------------------------

    private val docsDir: File get() = context.filesDir
    private fun dataFile(): File = File(docsDir, "fittracker.json")

    private fun load() {
        val file = dataFile()
        if (file.exists()) {
            try {
                val raw = file.readText()
                val decoded = json.decodeFromString<AppData>(raw)
                val a = migrate(decoded)
                _daily.value = a.daily
                _sessions.value = a.sessions
                _body.value = a.body
                _plans.value = a.plans
                _prefs.value = a.prefs
                _cardioTypes.value = a.cardioTypes ?: emptyList()
                _foods.value = a.foods ?: emptyList()
                _exerciseItems.value = a.exerciseItems ?: emptyList()
                _recipes.value = a.recipes ?: emptyList()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        if (_plans.value.isEmpty()) _plans.value = Defaults.defaultPlans()
        if (_cardioTypes.value.isEmpty()) _cardioTypes.value = Defaults.defaultCardioTypes()
        // Register the default plans' exercises so a fresh install's library isn't
        // empty.
        for (p in _plans.value) registerPlanExercises(p)
        L.lang = _prefs.value.langCode
        loaded = true
    }

    /** Upgrade a decoded document to the current schema (additive-optional-field rule). */
    private fun migrate(decoded: AppData): AppData {
        // No migrations needed yet beyond normalizing the version number — every
        // field added so far is optional, so old backups decode untouched.
        return decoded.copy(schemaVersion = AppData.currentSchemaVersion)
    }

    /** Keep the global localization language in sync with prefs. */
    fun syncLang() { L.lang = _prefs.value.langCode }

    /** Generic prefs mutator (mirrors the many small `store.prefs.x = y` writes in
     * the Swift source, which work directly since Prefs there is a class property). */
    fun updatePrefs(mutate: (Prefs) -> Prefs) {
        _prefs.value = mutate(_prefs.value)
        save()
    }

    fun save() {
        if (!loaded) return
        val a = AppData(
            schemaVersion = AppData.currentSchemaVersion,
            daily = _daily.value,
            sessions = _sessions.value,
            body = _body.value,
            plans = _plans.value,
            prefs = _prefs.value,
            cardioTypes = _cardioTypes.value,
            foods = _foods.value,
            exerciseItems = _exerciseItems.value,
            recipes = _recipes.value
        )
        try {
            val text = json.encodeToString(a)
            dataFile().writeText(text)
            val bk = File(docsDir, "backup-${today()}.json")
            bk.writeText(text)
            pruneBackups(keep = 30)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /** Delete the oldest dated backups, keeping the `keep` most recent. */
    private fun pruneBackups(keep: Int) {
        val files = docsDir.listFiles() ?: return
        val backups = files
            .filter { it.name.startsWith("backup-") && it.extension == "json" }
            .sortedByDescending { it.name }
        if (backups.size <= keep) return
        for (f in backups.drop(keep)) f.delete()
    }

    /** Produce a JSON file for sharing/export. */
    fun exportFile(): File? {
        val a = AppData(
            schemaVersion = AppData.currentSchemaVersion,
            daily = _daily.value, sessions = _sessions.value, body = _body.value, plans = _plans.value,
            prefs = _prefs.value, cardioTypes = _cardioTypes.value, foods = _foods.value,
            exerciseItems = _exerciseItems.value, recipes = _recipes.value
        )
        return try {
            val pretty = Json { prettyPrint = true; ignoreUnknownKeys = true }
            val text = pretty.encodeToString(a)
            val f = File(context.cacheDir, "fittracker-${today()}.json")
            f.writeText(text)
            f
        } catch (e: Exception) {
            e.printStackTrace(); null
        }
    }

    fun importFile(file: File): Boolean {
        return try {
            val a = json.decodeFromString<AppData>(file.readText())
            _daily.value = a.daily
            _sessions.value = a.sessions
            _body.value = a.body
            _plans.value = a.plans.ifEmpty { Defaults.defaultPlans() }
            _cardioTypes.value = if (!a.cardioTypes.isNullOrEmpty()) a.cardioTypes!! else Defaults.defaultCardioTypes()
            _foods.value = a.foods ?: emptyList()
            _exerciseItems.value = a.exerciseItems ?: emptyList()
            _recipes.value = a.recipes ?: emptyList()
            _prefs.value = a.prefs
            save()
            true
        } catch (e: Exception) {
            e.printStackTrace(); false
        }
    }

    // MARK: Cardio type mutations --------------------------------------------
    fun commitCardioType(ct: CardioType) {
        val list = _cardioTypes.value.toMutableList()
        val i = list.indexOfFirst { it.id == ct.id }
        if (i >= 0) list[i] = ct else list.add(ct)
        _cardioTypes.value = list
        save()
    }
    fun deleteCardioType(id: String) {
        _cardioTypes.value = _cardioTypes.value.filterNot { it.id == id }
        save()
    }

    // MARK: Plan mutations ----------------------------------------------------
    fun commitPlan(plan: WorkoutPlan, isNew: Boolean) {
        val list = _plans.value.toMutableList()
        val i = list.indexOfFirst { it.id == plan.id }
        if (i >= 0) list[i] = plan else list.add(plan)
        _plans.value = list
        registerPlanExercises(plan)
        save()
    }
    fun deletePlan(plan: WorkoutPlan) {
        _plans.value = _plans.value.filterNot { it.id == plan.id }
        save()
    }

    // MARK: - Derived data / domain logic ------------------------------------

    val sortedDaily: List<DailyEntry> get() = _daily.value.sortedBy { it.date }

    data class WeekPoint(val date: String, val value: Double)

    enum class ChartGranularity { DAY, WEEK, MONTH, YEAR;
        val months: Int get() = when (this) {
            DAY -> 3; WEEK -> 6; MONTH -> 24; YEAR -> 120
        }
    }

    private fun bucketKey(cal: Calendar, g: ChartGranularity): String = when (g) {
        ChartGranularity.DAY -> "%04d-%02d-%02d".format(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
        ChartGranularity.WEEK -> "%04d-%02d".format(cal.get(Calendar.YEAR), cal.get(Calendar.WEEK_OF_YEAR))
        ChartGranularity.MONTH -> "%04d-%02d".format(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH))
        ChartGranularity.YEAR -> "%04d".format(cal.get(Calendar.YEAR))
    }
    private fun bucketLabel(cal: Calendar, g: ChartGranularity): String {
        val f = java.text.SimpleDateFormat(
            when (g) { ChartGranularity.DAY, ChartGranularity.WEEK -> "MM-dd"; ChartGranularity.MONTH -> "yyyy-MM"; ChartGranularity.YEAR -> "yyyy" },
            Locale.US
        )
        return f.format(cal.time)
    }

    /** Generic time-bucketed average of a daily metric. */
    fun metricSeries(value: (DailyEntry) -> Double?, granularity: ChartGranularity, months: Int? = null): List<WeekPoint> {
        val back = months ?: granularity.months
        val cutoff = Calendar.getInstance().apply { add(Calendar.MONTH, -back) }
        data class Acc(var sum: Double = 0.0, var n: Int = 0)
        val byBucket = LinkedHashMap<String, Acc>()
        val bucketCal = LinkedHashMap<String, Calendar>()
        for (e in _daily.value) {
            val v = value(e) ?: continue
            if (!v.isFinite()) continue
            val d = try { isoFormatter.parse(e.date) } catch (ex: Exception) { null } ?: continue
            if (d.before(cutoff.time)) continue
            val cal = Calendar.getInstance().apply { time = d }
            val key = bucketKey(cal, granularity)
            val acc = byBucket.getOrPut(key) { Acc() }
            acc.sum += v; acc.n += 1
            bucketCal.putIfAbsent(key, cal)
        }
        return byBucket.keys.sorted().map { k ->
            val acc = byBucket[k]!!
            WeekPoint(bucketLabel(bucketCal[k]!!, granularity), ((acc.sum / acc.n) * 10).roundToInt() / 10.0)
        }
    }

    fun familyLastUsed(f: ExFamily): String =
        f.names.mapNotNull { n -> _exerciseItems.value.firstOrNull { it.name == n }?.lastUsed }.maxOrNull() ?: ""

    fun familySessionCount(f: ExFamily): Int {
        val names = f.names.toSet()
        return _sessions.value.count { s -> s.exercises.any { names.contains(it.name) } }
    }

    fun sessionCount(name: String): Int = _sessions.value.count { s -> s.exercises.any { it.name == name } }

    val latestVO2: Double? get() = sortedDaily.lastOrNull { (it.vo2max ?: 0.0) > 0 }?.vo2max

    val lastWeight: Double get() = sortedDaily.lastOrNull { it.weight != null }?.weight ?: _prefs.value.startWeight

    fun plan(id: String): WorkoutPlan? = _plans.value.firstOrNull { it.id == id }
    fun cardioType(id: String): CardioType? = _cardioTypes.value.firstOrNull { it.id == id }

    fun bmi(w: Double): Double {
        val h = _prefs.value.height
        return ((w / (h * h)) * 10).roundToInt() / 10.0
    }

    /** (labelKey, colorTag) — the UI maps colorTag to a Theme color. */
    fun bmiCategory(b: Double): Pair<String, String> = when {
        b < 18.5 -> "bmi.under" to "blue"
        b < 25 -> "bmi.normal" to "good"
        b < 30 -> "bmi.over" to "acc2"
        else -> "bmi.obese" to "red"
    }

    enum class BFCategory(val raw: String) {
        ESSENTIAL("essential"), ATHLETE("athlete"), FITNESS("fitness"), AVERAGE("average"), OVERWEIGHT("overweight"), OBESE("obese");
        val key: String get() = "bf.$raw"
        val colorTag: String get() = when (this) {
            ESSENTIAL -> "blue"; ATHLETE, FITNESS -> "good"; AVERAGE, OVERWEIGHT -> "acc2"; OBESE -> "red"
        }
    }

    fun bfCategory(bf: Double, sex: String): BFCategory {
        return if (sex == "f") {
            when {
                bf < 14 -> BFCategory.ESSENTIAL
                bf < 21 -> BFCategory.ATHLETE
                bf < 25 -> BFCategory.FITNESS
                bf < 32 -> BFCategory.AVERAGE
                bf < 37 -> BFCategory.OVERWEIGHT
                else -> BFCategory.OBESE
            }
        } else {
            when {
                bf < 6 -> BFCategory.ESSENTIAL
                bf < 14 -> BFCategory.ATHLETE
                bf < 18 -> BFCategory.FITNESS
                bf < 25 -> BFCategory.AVERAGE
                bf < 30 -> BFCategory.OVERWEIGHT
                else -> BFCategory.OBESE
            }
        }
    }

    private fun notOverweightByFat(bf: Double): Boolean = if (_prefs.value.sex_ == "f") bf < 25 else bf < 18

    /** (text, colorTag) shown under the weight box. */
    fun bmiComment(weight: Double): Pair<String, String> {
        val b = bmi(weight)
        val bf = currentBF
        if (bf != null) {
            val cat = bfCategory(bf, _prefs.value.sex_)
            if (b >= 25 && notOverweightByFat(bf)) {
                return "BMI ${trimNumLocal(b)} · ${L.t("bf.muscular")}" to "good"
            }
            return "BMI ${trimNumLocal(b)} · ${L.t(cat.key)}" to cat.colorTag
        }
        val std = bmiCategory(b)
        return "BMI ${trimNumLocal(b)} · ${L.t(std.first)}" to std.second
    }

    private fun trimNumLocal(v: Double): String =
        if (v == v.roundToInt().toDouble()) v.roundToInt().toString() else v.toString()

    /** US-Navy body-fat estimate (cm). */
    fun bfNavy(waist: Double?, neck: Double?, hip: Double? = null): Double? {
        val h = _prefs.value.height * 100
        if (waist == null || neck == null || waist <= neck || h <= 0) return null
        val v: Double
        if (_prefs.value.sex_ == "f") {
            if (hip == null || (waist + hip) <= neck) return null
            v = 163.205 * log10(waist + hip - neck) - 97.684 * log10(h) - 78.387
        } else {
            v = 86.010 * log10(waist - neck) - 70.041 * log10(h) + 36.76
        }
        return (v * 10).roundToInt() / 10.0
    }

    fun hasCheckedIn(): Boolean = _daily.value.any { it.date == today() && it.weight != null }

    val streak: Int
        get() {
            val dates = HashSet<String>()
            _daily.value.forEach { dates.add(it.date) }
            _sessions.value.forEach { dates.add(it.date) }
            return computeStreak(dates)
        }

    private fun computeStreak(dates: Set<String>): Int {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        if (!dates.contains(isoFormatter.format(cal.time))) cal.add(Calendar.DAY_OF_YEAR, -1)
        var n = 0
        for (i in 0 until 400) {
            val s = isoFormatter.format(cal.time)
            if (dates.contains(s)) { n += 1; cal.add(Calendar.DAY_OF_YEAR, -1) } else break
        }
        return n
    }

    // MARK: Next workout ------------------------------------------------------
    sealed class NextItem {
        data class Plan(val plan: WorkoutPlan) : NextItem()
        data class Cardio(val cardio: CardioType) : NextItem()
        val name: String get() = when (this) { is Plan -> plan.name; is Cardio -> cardio.name }
        val color: String get() = when (this) { is Plan -> plan.color; is Cardio -> cardio.color }
    }

    private fun scheduleItem(id: String): NextItem? {
        if (id.isEmpty() || id == "rest") return null
        _plans.value.firstOrNull { it.id == id }?.let { return NextItem.Plan(it) }
        _cardioTypes.value.firstOrNull { it.id == id }?.let { return NextItem.Cardio(it) }
        return null
    }

    fun nextUp(): NextItem? {
        val p = _prefs.value
        if (p.hasSchedule) {
            val sched = p.weekSchedule
            val cal = Calendar.getInstance()
            val todayMon = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
            val trainedToday = _sessions.value.any { it.date == today() }
            for (off in 0 until 8) {
                if (off == 0 && trainedToday) continue
                val item = scheduleItem(sched[(todayMon + off) % 7])
                if (item != null) return item
            }
            return null
        }
        return nextPlanRotation()?.let { NextItem.Plan(it) }
    }

    fun nextPlanRotation(): WorkoutPlan? {
        val plans = _plans.value
        if (plans.isEmpty()) return null
        val last = _sessions.value.sortedByDescending { it.date }.firstOrNull() ?: return plans.first()
        val idx = plans.indexOfFirst { it.id == last.planId }
        if (idx < 0) return plans.first()
        return plans[(idx + 1) % plans.size]
    }

    fun setSchedule(weekday: Int, id: String) {
        if (weekday !in 0..6) return
        val s = _prefs.value.weekSchedule.toMutableList()
        s[weekday] = id
        val newSchedule = if (s.any { it.isNotEmpty() && it != "rest" }) s else null
        _prefs.value = _prefs.value.copy(schedule = newSchedule)
        save()
    }
    fun clearSchedule() { _prefs.value = _prefs.value.copy(schedule = null); save() }

    fun exercisePR(name: String): Double {
        var mx = 0.0
        for (s in _sessions.value) for (e in s.exercises) if (e.name == name) mx = max(mx, e.maxWeight)
        return mx
    }
    fun exerciseMaxSeconds(name: String): Double {
        var mx = 0.0
        for (s in _sessions.value) for (e in s.exercises) if (e.name == name) mx = max(mx, e.maxSeconds)
        return mx
    }
    fun isBodyweightExercise(name: String): Boolean {
        _exerciseItems.value.firstOrNull { it.name == name }?.let { return it.isBodyweight }
        for (p in _plans.value) p.exercises.firstOrNull { it.name == name }?.let { return it.bodyweight }
        return false
    }

    fun lastSession(forPlan: String): WorkoutSession? =
        _sessions.value.filter { it.planId == forPlan && it.date != today() }.maxByOrNull { it.date }

    /** Suggested next weight: previous session's max + 2.5 kg when ready to progress. */
    fun suggested(planId: String, exercise: String): Double? {
        val prog = progression(planId, exercise) ?: return null
        if (prog != ProgKind.ADD_LOAD) return null
        val last = lastSession(planId) ?: return null
        val ex = last.exercises.firstOrNull { it.name == exercise } ?: return null
        if (ex.sets.isEmpty()) return null
        val r = readiness()
        if ((r.score ?: 100) < 30) return null
        val aw = acwr()
        if ((aw.ratio ?: 0.0) > 1.3) return null
        val allDone = ex.sets.all { pf(it.reps) > 0 && pf(it.weight) > 0 }
        if (!allDone) return null
        return ex.maxWeight + 2.5
    }

    /** Active-energy estimate for a session, in kcal. */
    fun estimateCalories(s: WorkoutSession): Int {
        val manual = s.caloriesManual
        if (manual != null && manual > 0) return manual
        val w = lastWeight
        val dur = s.durationMinutesD
        if (dur == null || dur <= 0) {
            return (s.volume * 0.022 + s.totalSets * 3 + 60).roundToInt()
        }
        val hours = dur / 60
        val speed: Double? = s.distanceKm?.takeIf { it > 0 }?.let { it / hours }
        val hrr = hrReserve(s.avgHR, s)
        val met = sportMET(s.sportType, speed, hrr)
        var kcal = max(1.0, met - 1.0) * w * hours
        if (s.sportType == Sport.STRENGTH) kcal += min(90.0, s.volume * 0.008)
        return max(1, kcal.roundToInt())
    }

    private fun hrReserve(hr: Int?, s: WorkoutSession): Double? {
        if (hr == null || hr <= 0) return null
        val rest = _prefs.value.restHRorDefault.toDouble()
        val mx = (s.maxHRSes ?: _prefs.value.estMaxHR).toDouble()
        if (mx <= rest) return null
        return max(0.0, min(1.0, (hr - rest) / (mx - rest)))
    }

    private fun sportMET(sport: Sport, speedKmh: Double?, hrr: Double?): Double = when (sport) {
        Sport.RUNNING -> when {
            speedKmh != null && speedKmh > 0 -> max(6.0, 0.95 * speedKmh + 0.5)
            hrr != null -> 3.0 + 9.0 * hrr
            else -> 9.5
        }
        Sport.CYCLING -> when {
            speedKmh != null && speedKmh > 0 -> when {
                speedKmh < 16 -> 3.8
                speedKmh < 20 -> 5.0
                speedKmh < 24 -> 6.8
                speedKmh < 28 -> 8.5
                speedKmh < 33 -> 10.5
                else -> 12.5
            }
            hrr != null -> 2.5 + 7.0 * hrr
            else -> 6.0
        }
        Sport.WALKING -> when {
            speedKmh != null && speedKmh > 0 -> when {
                speedKmh < 3.2 -> 2.5
                speedKmh < 4.8 -> 3.3
                speedKmh < 6.4 -> 4.5
                speedKmh < 8.0 -> 6.0
                else -> 7.5
            }
            hrr != null -> 2.0 + 4.0 * hrr
            else -> 3.5
        }
        Sport.SWIMMING -> when {
            speedKmh != null && speedKmh > 0 -> if (speedKmh > 4) 10.0 else if (speedKmh < 2.5) 6.0 else 8.3
            hrr != null -> 4.0 + 7.0 * hrr
            else -> 8.0
        }
        Sport.STRENGTH -> if (hrr != null) 2.8 + 5.5 * hrr else 4.5
        Sport.OTHER -> if (hrr != null) 2.0 + 7.0 * hrr else 6.0
    }

    // MARK: Daily nutrition & recovery ---------------------------------------
    fun saveDailyExtras(
        date: String = today(), kcal: Int? = null, protein: Double? = null, carbs: Double? = null,
        fat: Double? = null, salt: Double? = null, steps: Int? = null,
        rmssd: Double? = null, restHR: Int? = null, sleepHR: Int? = null
    ) {
        upsertDaily(date) { e ->
            var r = e
            if (kcal != null) r = r.copy(kcal = kcal)
            if (protein != null) r = r.copy(protein = protein)
            if (carbs != null) r = r.copy(carbs = carbs)
            if (fat != null) r = r.copy(fat = fat)
            if (salt != null) r = r.copy(salt = salt)
            if (steps != null) r = r.copy(steps = steps, stepsManual = true)
            if (rmssd != null) r = r.copy(rmssd = rmssd)
            if (restHR != null) r = r.copy(restHR = restHR)
            if (sleepHR != null) r = r.copy(sleepHR = sleepHR)
            r
        }
    }

    fun dailyEntry(date: String): DailyEntry? = _daily.value.firstOrNull { it.date == date }

    fun upsertDaily(date: String, mutate: (DailyEntry) -> DailyEntry) {
        val existing = _daily.value.firstOrNull { it.date == date } ?: DailyEntry(date = date)
        val updated = mutate(existing)
        _daily.value = _daily.value.filterNot { it.date == date } + updated
        save()
    }

    fun saveNutritionTotal(date: String, kcal: Int?, protein: Double?, carbs: Double?, fat: Double?) {
        upsertDaily(date) { e -> e.copy(kcal = kcal, protein = protein, carbs = carbs, fat = fat, meals = null) }
    }

    fun saveNutritionMeals(date: String, meals: Map<String, MealEntry>) {
        val clean = meals.filterValues { !it.isEmpty() }
        upsertDaily(date) { e -> e.copy(meals = clean.ifEmpty { null }, kcal = null, protein = null, carbs = null, fat = null) }
        for (m in clean.values) for (l in (m.foods ?: emptyList())) l.foodId?.let { touchFood(it) }
    }

    // MARK: Saved foods -------------------------------------------------------
    fun recentFoods(): List<FoodItem> = _foods.value.sortedWith(
        compareByDescending<FoodItem> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )
    fun food(barcode: String): FoodItem? = _foods.value.firstOrNull { it.barcode == barcode }

    fun saveFood(f: FoodItem): FoodItem {
        val list = _foods.value.toMutableList()
        val i = list.indexOfFirst { it.id == f.id }
        if (i >= 0) list[i] = f else list.add(f)
        _foods.value = list
        save()
        return f
    }
    fun deleteFood(id: String) { _foods.value = _foods.value.filterNot { it.id == id }; save() }
    fun touchFood(id: String) {
        _foods.value = _foods.value.map { if (it.id == id) it.copy(lastUsed = today()) else it }
        save()
    }

    fun saveDayFoods(date: String, logs: List<FoodLog>) {
        upsertDaily(date) { e ->
            var r = e.copy(foods = logs.ifEmpty { null })
            if (logs.isNotEmpty()) r = r.copy(kcal = null, protein = null, carbs = null, fat = null, meals = null)
            r
        }
        for (l in logs) l.foodId?.let { touchFood(it) }
    }

    data class NutPoint(val date: String, val kcal: Int, val protein: Double, val carbs: Double, val fat: Double)

    fun nutritionSeries(days: Int = 90): List<NutPoint> =
        sortedDaily.filter { it.hasNutrition }.takeLast(days).map {
            NutPoint(it.date, it.totalKcal, it.totalProtein, it.totalCarbs, it.totalFat)
        }

    fun nutritionWeeklySeries(months: Int = ChartGranularity.WEEK.months): List<NutPoint> {
        val cutoff = Calendar.getInstance().apply { add(Calendar.MONTH, -months) }
        data class Acc(var kcal: Double = 0.0, var p: Double = 0.0, var c: Double = 0.0, var f: Double = 0.0, var n: Int = 0)
        val byBucket = LinkedHashMap<String, Acc>()
        val bucketCal = LinkedHashMap<String, Calendar>()
        for (e in _daily.value) {
            if (!e.hasNutrition) continue
            val d = try { isoFormatter.parse(e.date) } catch (ex: Exception) { null } ?: continue
            if (d.before(cutoff.time)) continue
            val cal = Calendar.getInstance().apply { time = d }
            val key = bucketKey(cal, ChartGranularity.WEEK)
            val acc = byBucket.getOrPut(key) { Acc() }
            acc.kcal += e.totalKcal; acc.p += e.totalProtein; acc.c += e.totalCarbs; acc.f += e.totalFat; acc.n += 1
            bucketCal.putIfAbsent(key, cal)
        }
        return byBucket.keys.sorted().map { k ->
            val a = byBucket[k]!!; val n = max(1, a.n).toDouble()
            NutPoint(
                bucketLabel(bucketCal[k]!!, ChartGranularity.WEEK),
                (a.kcal / n).roundToInt(),
                (a.p / n * 10).roundToInt() / 10.0,
                (a.c / n * 10).roundToInt() / 10.0,
                (a.f / n * 10).roundToInt() / 10.0
            )
        }
    }

    // MARK: Rest days -----------------------------------------------------------
    fun isRestDay(date: String): Boolean = _prefs.value.restDaySet.contains(date)
    fun setRestDay(date: String, on: Boolean) {
        val set = _prefs.value.restDaySet.toMutableSet()
        if (on) set.add(date) else set.remove(date)
        _prefs.value = _prefs.value.copy(restDays = set.ifEmpty { null }?.sorted())
        save()
    }
    fun toggleRestDay(date: String) = setRestDay(date, !isRestDay(date))

    // MARK: Quick insert ----------------------------------------------------
    fun quickInsertSession(plan: WorkoutPlan, date: String): WorkoutSession {
        val last = _sessions.value.filter { it.planId == plan.id }.maxByOrNull { it.date }
        val exercises: List<LoggedExercise> = if (last != null) {
            last.exercises.map { e ->
                LoggedExercise(
                    name = e.name,
                    sets = e.sets.map { SetEntry(reps = it.reps, weight = it.weight) },
                    notes = "", target = e.target,
                    supersetGroup = e.supersetGroup, method = e.method
                )
            }
        } else {
            plan.exercises.map { pe ->
                LoggedExercise(
                    name = pe.name,
                    sets = (0 until max(1, pe.sets)).map { SetEntry() },
                    target = "${pe.sets}×${pe.reps}",
                    supersetGroup = pe.supersetGroup, method = pe.method
                )
            }
        }
        val s = WorkoutSession(
            date = date, planId = plan.id, planName = plan.name, planColor = plan.color, exercises = exercises,
            durationSec = last?.durationSeconds, avgHR = last?.avgHR, maxHRSes = last?.maxHRSes
        )
        setRestDay(date, false)
        _sessions.value = _sessions.value + s
        save()
        return s
    }

    /** Persist a freshly-finished live strength workout (LiveWorkout screen) as a
     * new WorkoutSession — analogous to quickInsertSession but built from the
     * user's actually-logged exercises/sets rather than a template. */
    fun logSession(
        plan: WorkoutPlan,
        exercises: List<LoggedExercise>,
        date: String = today(),
        durationSec: Int? = null,
        avgHR: Int? = null,
        caloriesManual: Int? = null
    ): WorkoutSession {
        val s = WorkoutSession(
            date = date, planId = plan.id, planName = plan.name, planColor = plan.color,
            exercises = exercises, durationSec = durationSec, avgHR = avgHR, caloriesManual = caloriesManual
        )
        setRestDay(date, false)
        _sessions.value = _sessions.value + s
        for (e in exercises) if (e.name.isNotBlank()) touchExerciseInLibrary(e.name, e.isBodyweight ?: false)
        save()
        return s
    }

    fun quickInsertCardio(type: CardioType, date: String): WorkoutSession {
        val pid = "cardio-${type.id}"
        val last = _sessions.value.filter { it.planId == pid }.maxByOrNull { it.date }
        val s = WorkoutSession(
            date = date, planId = pid, planName = type.name, planColor = type.color, exercises = emptyList(),
            sport = type.sport, durationSec = last?.durationSeconds, avgHR = last?.avgHR,
            distanceKm = last?.distanceKm, paceManual = last?.paceManual
        )
        setRestDay(date, false)
        _sessions.value = _sessions.value + s
        save()
        return s
    }

    data class WeekStat(val avgWeight: Double?, val sessions: Int)
    fun weekStats(offset: Int): WeekStat {
        val cal = Calendar.getInstance()
        val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
        val mon = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -dow - offset * 7)
        }
        val sun = (mon.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 7) }
        fun inRange(ds: String): Boolean {
            val d = try { isoFormatter.parse(ds) } catch (e: Exception) { null } ?: return false
            return !d.before(mon.time) && d.before(sun.time)
        }
        val dw = _daily.value.filter { inRange(it.date) && it.weight != null }.mapNotNull { it.weight }
        val avg = if (dw.isEmpty()) null else ((dw.sum() / dw.size) * 10).roundToInt() / 10.0
        return WeekStat(avg, _sessions.value.count { inRange(it.date) })
    }

    data class PRInfo(val weight: Double, val date: String?)
    fun allPRs(): Map<String, PRInfo> {
        val prs = HashMap<String, PRInfo>()
        for (p in _plans.value) for (e in p.exercises) if (!prs.containsKey(e.name)) prs[e.name] = PRInfo(0.0, null)
        for (s in _sessions.value.sortedBy { it.date }) {
            for (e in s.exercises) {
                val w = e.maxWeight
                if (w >= (prs[e.name]?.weight ?: 0.0)) prs[e.name] = PRInfo(w, s.date)
            }
        }
        return prs
    }

    fun allExerciseNames(): List<Pair<String, String>> {
        val seen = HashSet<String>()
        val out = ArrayList<Pair<String, String>>()
        for (p in _plans.value) for (e in p.exercises) if (e.name.isNotEmpty() && seen.add(e.name)) out.add(p.name to e.name)
        for (item in _exerciseItems.value.sortedByDescending { it.lastUsed ?: "" }) {
            if (item.name.isNotEmpty() && seen.add(item.name)) out.add(L.t("ex.library") to item.name)
        }
        return out
    }

    // MARK: Exercise library ---------------------------------------------------
    fun recentExercises(): List<ExerciseItem> = _exerciseItems.value.sortedWith(
        compareByDescending<ExerciseItem> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )

    fun touchExerciseInLibrary(name: String, isBodyweight: Boolean = false): ExerciseItem {
        val list = _exerciseItems.value.toMutableList()
        val i = list.indexOfFirst { it.name == name }
        val result: ExerciseItem
        if (i >= 0) {
            var item = list[i]
            item = item.copy(lastUsed = today())
            if (isBodyweight) item = item.copy(isBodyweight = true)
            if (item.base == null) item = item.copy(base = normalizedBase(name))
            if (item.category == null) item = item.copy(category = guessCategory(name).raw)
            list[i] = item
            result = item
        } else {
            val item = ExerciseItem(
                name = name, isBodyweight = isBodyweight, lastUsed = today(),
                base = normalizedBase(name), category = guessCategory(name).raw
            )
            list.add(item)
            result = item
        }
        _exerciseItems.value = list
        save()
        return result
    }

    fun recreatePlan(session: WorkoutSession): WorkoutPlan {
        val exs: List<PlanExercise> = session.exercises.map { le ->
            val reps = le.sets.mapNotNull { pf(it.reps).toInt().takeIf { r -> r > 0 } }
            val repTarget = if (reps.isEmpty()) "10" else mode(reps).toString()
            PlanExercise(
                name = le.name, sets = max(1, le.sets.size), reps = repTarget,
                supersetGroup = le.supersetGroup, method = le.method,
                effortMode = le.effortMode, isBodyweight = le.isBodyweight,
                muscle = exerciseCategory(le.name)
            )
        }
        val plan = WorkoutPlan(name = session.planName, color = session.planColor, exercises = exs)
        _plans.value = _plans.value + plan
        registerPlanExercises(plan)
        save()
        return plan
    }

    private fun mode(xs: List<Int>): Int {
        val counts = HashMap<Int, Int>()
        for (x in xs) counts[x] = (counts[x] ?: 0) + 1
        return counts.maxByOrNull { it.value }?.key ?: (xs.firstOrNull() ?: 10)
    }

    fun registerPlanExercises(plan: WorkoutPlan) {
        for (ex in plan.exercises) {
            val name = ex.name.trim()
            if (name.isEmpty()) continue
            touchExerciseInLibrary(name, ex.bodyweight)
            if (!ex.muscle.isNullOrEmpty()) {
                val i = _exerciseItems.value.indexOfFirst { it.name == name }
                if (i >= 0) {
                    val list = _exerciseItems.value.toMutableList()
                    list[i] = list[i].copy(category = ex.muscle)
                    _exerciseItems.value = list
                }
            }
        }
    }

    fun setExerciseBodyweight(name: String, flag: Boolean) {
        val i = _exerciseItems.value.indexOfFirst { it.name == name }
        if (i >= 0) {
            val list = _exerciseItems.value.toMutableList()
            list[i] = list[i].copy(isBodyweight = flag)
            _exerciseItems.value = list
        } else {
            _exerciseItems.value = _exerciseItems.value + ExerciseItem(name = name, isBodyweight = flag, lastUsed = today())
        }
        save()
    }

    fun setExerciseFamily(name: String, base: String?, category: String?) {
        val cleanBase = base?.trim()
        val i = _exerciseItems.value.indexOfFirst { it.name == name }
        if (i >= 0) {
            val list = _exerciseItems.value.toMutableList()
            var item = list[i]
            item = item.copy(base = if (cleanBase.isNullOrEmpty()) normalizedBase(name) else cleanBase)
            if (category != null) item = item.copy(category = category)
            list[i] = item
            _exerciseItems.value = list
        } else {
            _exerciseItems.value = _exerciseItems.value + ExerciseItem(
                name = name, lastUsed = today(),
                base = if (cleanBase.isNullOrEmpty()) normalizedBase(name) else cleanBase,
                category = category ?: guessCategory(name).raw
            )
        }
        save()
    }

    // MARK: Exercise rename / merge / delete ---------------------------------
    fun renameExercise(oldName: String, newRaw: String): Boolean {
        val newName = newRaw.trim()
        if (newName.isEmpty() || newName == oldName) return false
        val isMerge = _exerciseItems.value.any { it.name == newName } ||
            _plans.value.any { p -> p.exercises.any { it.name == newName } } ||
            _sessions.value.any { s -> s.exercises.any { it.name == newName } }

        _sessions.value = _sessions.value.map { s ->
            s.copy(exercises = s.exercises.map { if (it.name == oldName) it.copy(name = newName) else it })
        }
        _plans.value = _plans.value.map { p ->
            p.copy(exercises = p.exercises.map { if (it.name == oldName) it.copy(name = newName) else it })
        }
        val oi = _exerciseItems.value.indexOfFirst { it.name == oldName }
        if (oi >= 0) {
            if (isMerge) {
                val di = _exerciseItems.value.indexOfFirst { it.name == newName }
                val list = _exerciseItems.value.toMutableList()
                if (di >= 0) {
                    val merged = maxOf(list[di].lastUsed ?: "", list[oi].lastUsed ?: "")
                    if (merged.isNotEmpty()) list[di] = list[di].copy(lastUsed = merged)
                }
                list.removeAt(oi)
                _exerciseItems.value = list
            } else {
                val list = _exerciseItems.value.toMutableList()
                list[oi] = list[oi].copy(name = newName)
                _exerciseItems.value = list
            }
        } else if (!isMerge) {
            touchExerciseInLibrary(newName)
        }
        save()
        return true
    }

    fun deleteExercise(name: String) {
        _sessions.value = _sessions.value.map { s -> s.copy(exercises = s.exercises.filterNot { it.name == name }) }
            .filterNot { it.sportType == Sport.STRENGTH && it.exercises.isEmpty() }
        _plans.value = _plans.value.map { p -> p.copy(exercises = p.exercises.filterNot { it.name == name }) }
        _exerciseItems.value = _exerciseItems.value.filterNot { it.name == name }
        save()
    }

    fun similarExerciseGroups(): List<List<String>> {
        fun key(s: String): String {
            val folded = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
                .replace(Regex("\\p{M}"), "")
                .lowercase()
                .replace("-", " ")
            return folded.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        }
        val names = allExerciseNames().map { it.second }.toSet()
        val byKey = HashMap<String, MutableList<String>>()
        for (n in names) byKey.getOrPut(key(n)) { mutableListOf() }.add(n)
        return byKey.values.filter { it.size > 1 }
            .map { it.sortedByDescending { n -> recencyOf(n) } }
            .sortedByDescending { it.firstOrNull()?.let { n -> recencyOf(n) } ?: "" }
    }

    private fun recencyOf(name: String): String {
        val lib = _exerciseItems.value.firstOrNull { it.name == name }?.lastUsed ?: ""
        val logged = _sessions.value.filter { s -> s.exercises.any { it.name == name } }.maxOfOrNull { it.date } ?: ""
        return maxOf(lib, logged)
    }

    fun exerciseBase(name: String): String {
        val item = _exerciseItems.value.firstOrNull { it.name == name }
        if (item?.base != null && item.base!!.isNotEmpty()) return item.base!!
        return normalizedBase(name)
    }

    fun exerciseCategory(name: String): String {
        val item = _exerciseItems.value.firstOrNull { it.name == name }
        if (item?.category != null && item.category!!.isNotEmpty()) return item.category!!
        return guessCategory(name).raw
    }

    fun normalizedBase(name: String): String {
        var s = " " + name.lowercase() + " "
        val qualifiers = listOf(
            "wide-grip", "wide grip", "close-grip", "close grip", "narrow-grip",
            "narrow grip", "neutral-grip", "neutral grip", "reverse-grip", "reverse grip",
            "rear-delt", "rear delt", "single-arm", "single arm", "one-arm", "one arm",
            "wide", "close", "narrow"
        )
        for (q in qualifiers) s = s.replace(" $q ", " ")
        val cleaned = s.replace("  ", " ").trim()
        if (cleaned.isEmpty()) return name
        return cleaned.substring(0, 1).uppercase() + cleaned.substring(1)
    }

    fun guessCategory(name: String): MuscleGroup {
        val n = name.lowercase()
        fun has(ks: List<String>) = ks.any { n.contains(it) }
        return when {
            has(listOf("squat", "leg press", "leg curl", "leg extension", "lunge", "calf", "hamstring", "quad", "glute", "rdl", "romanian", "hip thrust")) -> MuscleGroup.LEGS
            has(listOf("bench", "chest", "fly", "pec", "push-up", "push up", "dip")) -> MuscleGroup.CHEST
            has(listOf("row", "pulldown", "pull-up", "pull up", "chin-up", "lat ", "deadlift", "pull-over", "back extension")) -> MuscleGroup.BACK
            has(listOf("shoulder", "lateral raise", "delt", "overhead press", "ohp", "upright row", "face pull", "shrug")) -> MuscleGroup.SHOULDERS
            has(listOf("curl", "triceps", "biceps", "pushdown", "skull", "preacher", "hammer", "forearm")) -> MuscleGroup.ARMS
            has(listOf("plank", "crunch", "ab ", "abs", "core", "sit-up", "sit up", "leg raise", "russian twist")) -> MuscleGroup.CORE
            has(listOf("run", "cycl", "bike", "swim", "walk", "row erg", "rowing", "elliptical", "jump rope")) -> MuscleGroup.CARDIO
            else -> MuscleGroup.OTHER
        }
    }

    data class ExFamily(val base: String, val category: String, val names: List<String>)

    fun exerciseFamilies(): List<ExFamily> {
        data class Entry(var cat: String, val names: MutableList<String>)
        val byBase = LinkedHashMap<String, Entry>()
        for ((_, name) in allExerciseNames()) {
            if (name.isEmpty()) continue
            val base = exerciseBase(name)
            val entry = byBase.getOrPut(base) { Entry(exerciseCategory(name), mutableListOf()) }
            if (!entry.names.contains(name)) entry.names.add(name)
        }
        return byBase.map { (base, e) -> ExFamily(base, e.cat, e.names) }
            .sortedBy { it.base.lowercase() }
    }

    data class ExPoint(val date: String, val maxW: Double, val vol: Double)

    fun exerciseHistory(name: String): List<ExPoint> =
        _sessions.value.filter { s -> s.exercises.any { it.name == name } }
            .sortedBy { it.date }
            .map { s ->
                val ex = s.exercises.first { it.name == name }
                ExPoint(fmtShort(s.date), ex.maxWeight, ex.volume.let { (it).roundToInt().toDouble() })
            }

    fun exerciseHistoryFamily(base: String): List<ExPoint> {
        val names = (_exerciseItems.value.filter { exerciseBase(it.name) == base }.map { it.name } +
            _plans.value.flatMap { it.exercises.map { pe -> pe.name } }.filter { exerciseBase(it) == base }).toSet()
        return _sessions.value.filter { s -> s.exercises.any { names.contains(it.name) } }
            .sortedBy { it.date }
            .map { s ->
                val exs = s.exercises.filter { names.contains(it.name) }
                val maxW = exs.maxOfOrNull { it.maxWeight } ?: 0.0
                val vol = exs.sumOf { it.volume }
                ExPoint(fmtShort(s.date), maxW, vol.roundToInt().toDouble())
            }
    }

    val bodyLatest: BodyEntry? get() = _body.value.sortedByDescending { it.date }.firstOrNull()
    val bodyPrev: BodyEntry?
        get() {
            val s = _body.value.sortedByDescending { it.date }
            return if (s.size > 1) s[1] else null
        }

    val currentBF: Double?
        get() {
            val bl = bodyLatest ?: return null
            return bl.bfManual ?: bfNavy(bl.waist, bl.neck, bl.hips)
        }

    // MARK: Mutations -----------------------------------------------------------
    fun saveCheckIn(weight: Double?, sleep: Int?, restHR: Int? = null, sleepHR: Int? = null, date: String = today()) {
        upsertDaily(date) { e ->
            var r = e
            if (weight != null) r = r.copy(weight = weight)
            if (sleep != null) r = r.copy(sleep = sleep)
            if (restHR != null) r = r.copy(restHR = restHR)
            if (sleepHR != null) r = r.copy(sleepHR = sleepHR)
            r
        }
    }

    private fun upsertBody(date: String, mutate: (BodyEntry) -> BodyEntry) {
        val existing = _body.value.firstOrNull { it.date == date } ?: BodyEntry(date = date)
        val updated = mutate(existing)
        _body.value = _body.value.filterNot { it.date == date } + updated
        save()
    }

    fun saveBodyFat(v: Double, date: String = today()) {
        upsertBody(date) { it.copy(bfManual = v) }
    }

    fun saveMeasurements(values: Map<String, Double>, date: String = today()) {
        upsertBody(date) { rec ->
            var r = rec
            for ((k, v) in values) if (v > 0) r = r.set(k, v)
            r
        }
    }

    fun saveManualSleep(hours: Double?, score: Int?, hrv: Double?, sleepHR: Int?, date: String = today()) {
        upsertDaily(date) { e ->
            var r = e
            if (hours != null && hours > 0) r = r.copy(sleepHours = hours)
            if (score != null) r = r.copy(sleep = min(100, max(0, score)))
            if (hrv != null && hrv > 0) r = r.copy(hrvSDNN = hrv)
            if (sleepHR != null && sleepHR > 0) r = r.copy(sleepHR = sleepHR)
            r
        }
    }

    // MARK: Saved recipes ---------------------------------------------------
    fun recentRecipes(): List<Recipe> = _recipes.value.sortedWith(
        compareByDescending<Recipe> { it.lastUsed ?: "" }.thenBy { it.name.lowercase() }
    )
    fun saveRecipe(r: Recipe): Recipe {
        val list = _recipes.value.toMutableList()
        val i = list.indexOfFirst { it.id == r.id }
        if (i >= 0) list[i] = r else list.add(r)
        _recipes.value = list
        save()
        return r
    }
    fun deleteRecipe(id: String) { _recipes.value = _recipes.value.filterNot { it.id == id }; save() }
    fun touchRecipe(id: String) {
        _recipes.value = _recipes.value.map { if (it.id == id) it.copy(lastUsed = today()) else it }
        save()
    }

    // MARK: Session editing ---------------------------------------------------
    fun deleteSession(id: String) { _sessions.value = _sessions.value.filterNot { it.id == id }; save() }

    fun duplicateSession(id: String, date: String = today()): WorkoutSession? {
        val src = _sessions.value.firstOrNull { it.id == id } ?: return null
        val copy = src.copy(
            id = java.util.UUID.randomUUID().toString(),
            date = date,
            healthUUID = null, mergedHealthUUIDs = null, exportedHealthUUID = null,
            source = null, avgHR = null, maxHRSes = null,
            exercises = src.exercises.map { e ->
                e.copy(id = java.util.UUID.randomUUID().toString(), sets = e.sets.map { it.copy(id = java.util.UUID.randomUUID().toString()) })
            }
        )
        setRestDay(date, false)
        _sessions.value = _sessions.value + copy
        save()
        return copy
    }

    fun updateSession(s: WorkoutSession) {
        val i = _sessions.value.indexOfFirst { it.id == s.id }
        if (i >= 0) {
            val list = _sessions.value.toMutableList()
            list[i] = s
            _sessions.value = list
            save()
        }
    }

    /** Fold several sessions from the same day into one. */
    fun mergeSessions(ids: List<String>, primary: String): WorkoutSession? {
        val picked = ids.mapNotNull { id -> _sessions.value.firstOrNull { it.id == id } }
        if (picked.size < 2) return null
        var merged = picked.firstOrNull { it.id == primary } ?: return null
        val others = picked.filter { it.id != primary }

        val exercises = merged.exercises.toMutableList()
        for (o in others) {
            for (ex in o.exercises) {
                val i = exercises.indexOfFirst { it.name == ex.name }
                if (i >= 0) {
                    var e = exercises[i]
                    e = e.copy(sets = e.sets + ex.sets)
                    val exRounds = ex.rounds
                    if (exRounds != null) e = e.copy(rounds = (e.rounds ?: 0) + exRounds)
                    val notes = listOf(e.notes, ex.notes).filter { it.isNotEmpty() }
                    e = e.copy(notes = notes.joinToString(" · "))
                    exercises[i] = e
                } else {
                    exercises.add(ex)
                }
            }
        }
        merged = merged.copy(exercises = exercises)

        val totalSec = picked.mapNotNull { it.durationSeconds }.sum()
        if (totalSec > 0) merged = merged.copy(durationSec = totalSec, durationMin = null)

        val hrParts = picked.mapNotNull { s -> s.avgHR?.takeIf { it > 0 }?.let { it.toDouble() to (s.durationSeconds ?: 0).toDouble() } }
        if (hrParts.isNotEmpty()) {
            val totalW = hrParts.sumOf { it.second }
            merged = if (totalW > 0) {
                merged.copy(avgHR = (hrParts.sumOf { it.first * it.second } / totalW).roundToInt())
            } else {
                merged.copy(avgHR = (hrParts.sumOf { it.first } / hrParts.size).roundToInt())
            }
        }
        picked.mapNotNull { it.maxHRSes }.maxOrNull()?.let { merged = merged.copy(maxHRSes = it) }

        val dist = picked.mapNotNull { it.distanceKm }.sum()
        if (dist > 0) merged = merged.copy(distanceKm = dist)
        picked.mapNotNull { it.elevationM }.maxOrNull()?.let { merged = merged.copy(elevationM = it) }
        val kcal = picked.sumOf { estimateCalories(it) }
        if (kcal > 0) merged = merged.copy(caloriesManual = kcal)
        merged = merged.copy(paceManual = null)

        val absorbed = others.flatMap { it.allHealthUUIDs }
        if (absorbed.isNotEmpty()) {
            merged = merged.copy(mergedHealthUUIDs = ((merged.mergedHealthUUIDs ?: emptyList()) + absorbed).distinct())
        }
        if (merged.source == null) others.mapNotNull { it.source }.firstOrNull()?.let { merged = merged.copy(source = it) }

        _sessions.value = _sessions.value.filterNot { s -> others.any { it.id == s.id } }
        updateSession(merged)
        return merged
    }
}
