package com.marco.fittracker.data

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID

// MARK: - Parsing helper (mirrors the web/iOS app's pf(): accepts "," or ".")
fun pf(s: String?): Double = (s ?: "").replace(",", ".").trim().toDoubleOrNull() ?: 0.0

internal fun randomId(): String = UUID.randomUUID().toString().uppercase()

// MARK: - Dates
private val isoFmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

fun today(): String = LocalDate.now().format(isoFmt)

/** "2024-05-31" -> "05-31" */
fun fmtShort(date: String): String = if (date.length >= 5) date.substring(5) else date

/** "2024-05-31" -> "31/05"  (short, readable day/month for dense charts) */
fun fmtDM(date: String): String {
    val p = date.split("-")
    return if (p.size == 3) "${p[2]}/${p[1]}" else date
}

/** Total seconds -> compact "1h 05m", "45m 30s" or "30s" for session summaries. */
fun fmtDuration(seconds: Int): String {
    val h = seconds / 3600; val m = (seconds % 3600) / 60; val s = seconds % 60
    return when {
        h > 0 -> "%dh %02dm".format(h, m)
        m > 0 -> if (s > 0) "%dm %02ds".format(m, s) else "${m}m"
        else -> "${s}s"
    }
}

/** Decimal minutes -> "m:ss" pace string. */
fun paceStr(minPerUnit: Double): String {
    val m = minPerUnit.toInt()
    val s = ((minPerUnit - m) * 60).toInt()
    return "%d:%02d".format(m, s)
}

val itMonths = listOf("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")
val enMonths = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
val itDays = listOf("Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom")
val enDays = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
val itWeekHeaders = listOf("L", "M", "M", "G", "V", "S", "D")
val enWeekHeaders = listOf("M", "T", "W", "T", "F", "S", "S")

fun headerDate(): Pair<String, String> {
    val now = LocalDate.now()
    val m = (now.monthValue - 1).coerceIn(0, 11)
    // DayOfWeek: MONDAY=1 .. SUNDAY=7 -> our itDays index 0..6
    val wd = (now.dayOfWeek.value - 1).coerceIn(0, 6)
    return Pair("${now.dayOfMonth} ${itMonths[m]} ${now.year}", itDays[wd])
}

// MARK: - Number formatting
fun trimNum(v: Double): String =
    if (v == Math.floor(v) && !v.isInfinite()) v.toLong().toString()
    else {
        val s = ((Math.round(v * 1000.0)) / 1000.0).toString()
        if (s.endsWith(".0")) s.dropLast(2) else s
    }

/** Capitalise the first letter of every word; rest lowercase. */
fun titleCased(s: String): String =
    s.split(" ").joinToString(" ") { word ->
        if (word.isEmpty()) word else word[0].uppercaseChar() + word.drop(1).lowercase()
    }

// MARK: - Daily check-in (weight + sleep + optional nutrition / recovery)
@Serializable
data class DailyEntry(
    val date: String,
    val weight: Double? = null,
    val sleep: Int? = null,
    // Nutrition (optional)
    val kcal: Int? = null,
    val protein: Double? = null,
    val carbs: Double? = null,
    val fat: Double? = null,
    val salt: Double? = null,
    val steps: Int? = null,
    val stepsManual: Boolean? = null,
    // Recovery (optional)
    val rmssd: Double? = null,
    val restHR: Int? = null,
    val hrvSDNN: Double? = null,
    val sleepHR: Int? = null,
    val sleepHours: Double? = null,
    // Daily activity from Health Connect
    val activeKcal: Int? = null,
    val exerciseMin: Int? = null,
    val vo2max: Double? = null,
    // Per-meal nutrition breakdown (optional). Keys are MealSlot raw values.
    val meals: Map<String, MealEntry>? = null,
    // Day-level individual foods (food-by-food without assigning a meal)
    val foods: List<FoodLog>? = null
) {
    val hasNutrition: Boolean
        get() = (kcal ?: 0) > 0
            || (meals?.values?.any { !it.isEmpty } == true)
            || !(foods?.isEmpty() ?: true)

    val totalKcal: Int
        get() {
            var s = 0
            meals?.values?.forEach { s += it.effKcal }
            foods?.forEach { s += it.kcal }
            return if (s > 0) s else (kcal ?: 0)
        }
    val totalProtein: Double get() = macroTotal({ it.effProtein }, { it.protein }, protein)
    val totalCarbs: Double get() = macroTotal({ it.effCarbs }, { it.carbs }, carbs)
    val totalFat: Double get() = macroTotal({ it.effFat }, { it.fat }, fat)

    private fun macroTotal(
        mealKP: (MealEntry) -> Double,
        foodKP: (FoodLog) -> Double,
        quick: Double?
    ): Double {
        var s = 0.0
        meals?.values?.forEach { s += mealKP(it) }
        foods?.forEach { s += foodKP(it) }
        return if (s > 0) s else (quick ?: 0.0)
    }
}

// MARK: - Per-meal nutrition entry
@Serializable
data class MealEntry(
    val kcal: Int = 0,
    val protein: Double = 0.0,
    val carbs: Double = 0.0,
    val fat: Double = 0.0,
    val foods: List<FoodLog>? = null
) {
    val hasFoods: Boolean get() = !(foods?.isEmpty() ?: true)
    val effKcal: Int get() = if (hasFoods) foods!!.sumOf { it.kcal } else kcal
    val effProtein: Double get() = if (hasFoods) foods!!.sumOf { it.protein } else protein
    val effCarbs: Double get() = if (hasFoods) foods!!.sumOf { it.carbs } else carbs
    val effFat: Double get() = if (hasFoods) foods!!.sumOf { it.fat } else fat
    val isEmpty: Boolean get() = kcal == 0 && protein == 0.0 && carbs == 0.0 && fat == 0.0 && !hasFoods
}

// MARK: - Saved food (nutrition per 100 g/ml) + a logged amount of it
@Serializable
data class FoodItem(
    val id: String = randomId(),
    val name: String,
    val brand: String? = null,
    val barcode: String? = null,
    val k100: Double = 0.0,
    val p100: Double = 0.0,
    val c100: Double = 0.0,
    val f100: Double = 0.0,
    val liquid: Boolean = false,
    val lastUsed: String? = null
) {
    val unit: String get() = if (liquid) "ml" else "g"
    val fullName: String get() = if (brand != null) "$brand – $name" else name

    fun log(grams: Double): FoodLog =
        FoodLog(foodId = id, name = fullName, grams = grams, k100 = k100, p100 = p100, c100 = c100, f100 = f100)
}

@Serializable
data class FoodLog(
    val id: String = randomId(),
    val foodId: String? = null,
    val name: String,
    val grams: Double,
    val k100: Double,
    val p100: Double,
    val c100: Double,
    val f100: Double
) {
    private fun scale(per100: Double): Double = (per100 * grams / 100 * 10).let { Math.round(it) / 10.0 }
    val kcal: Int get() = Math.round(k100 * grams / 100).toInt()
    val protein: Double get() = scale(p100)
    val carbs: Double get() = scale(c100)
    val fat: Double get() = scale(f100)
}

// MARK: - The four meal slots
enum class MealSlot(val raw: String) {
    BREAKFAST("breakfast"), LUNCH("lunch"), DINNER("dinner"), SNACKS("snacks");
    val labelKey: String get() = "meal.$raw"
    val color: String get() = when (this) {
        BREAKFAST -> "ffb000"; LUNCH -> "ffe000"; DINNER -> "b08fff"; SNACKS -> "7fc950"
    }
    companion object { val all = listOf(BREAKFAST, LUNCH, DINNER, SNACKS) }
}

// MARK: - A single logged set
@Serializable
data class SetEntry(
    val id: String = randomId(),
    val reps: String = "",
    val weight: String = "",
    val effortVal: Int? = null
) {
    val filled: Boolean get() = pf(reps) > 0 || pf(weight) > 0
}

// MARK: - Training method for an exercise (supersets etc.)
enum class TrainMethod(val raw: String) {
    NORMAL("normal"), SUPERSET("superset"), DROPSET("dropset"),
    RESTPAUSE("restpause"), GIANT("giant");
    val short: String get() = when (this) {
        NORMAL -> ""; SUPERSET -> "SS"; DROPSET -> "DROP"; RESTPAUSE -> "RP"; GIANT -> "GIANT"
    }
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: NORMAL }
}

// MARK: - Effort tracking scale for per-set feedback
enum class EffortMode(val raw: String) {
    RIR("rir"), RPE("rpe"), FAIL("fail");
    val label: String get() = when (this) { RIR -> "RIR"; RPE -> "RPE"; FAIL -> "FAIL" }
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } }
}

// MARK: - An exercise as logged inside a session
@Serializable
data class LoggedExercise(
    val id: String = randomId(),
    val name: String,
    val sets: List<SetEntry> = emptyList(),
    val notes: String = "",
    val target: String = "",
    val supersetGroup: Int? = null,
    val method: String? = null,
    val effortMode: String? = null,
    val isBodyweight: Boolean? = null
) {
    val volume: Double get() = sets.sumOf { pf(it.reps) * pf(it.weight) }
    val maxWeight: Double get() = sets.maxOfOrNull { pf(it.weight) } ?: 0.0
    val trainMethod: TrainMethod get() = TrainMethod.from(method)
    val effortScale: EffortMode? get() = EffortMode.from(effortMode)
    val bodyweight: Boolean get() = isBodyweight == true
}

// MARK: - Sport kinds
enum class Sport(val raw: String) {
    STRENGTH("strength"), RUNNING("running"), SWIMMING("swimming"),
    CYCLING("cycling"), WALKING("walking"), OTHER("other");
    val isCardio: Boolean get() = this != STRENGTH
    val color: String get() = when (this) {
        STRENGTH -> "ffe000"; RUNNING -> "ff5a52"; SWIMMING -> "4fb8c4"
        CYCLING -> "7fc950"; WALKING -> "b08fff"; OTHER -> "ffb000"
    }
    fun label(): String = L.t("sport.$raw")
    fun icon(): String = when (this) {
        STRENGTH -> "dumbbell"; RUNNING -> "directions_run"; SWIMMING -> "pool"
        CYCLING -> "directions_bike"; WALKING -> "directions_walk"; OTHER -> "fitness_center"
    }
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: STRENGTH }
}

// MARK: - A saved, customizable cardio activity type (mirrors WorkoutPlan)
@Serializable
data class CardioType(
    val id: String = randomId(),
    val name: String,
    val sport: String,
    val color: String,
    val sub: String? = null
) {
    val sportType: Sport get() = Sport.from(sport)
}

// MARK: - A completed workout session (strength or cardio)
@Serializable
data class WorkoutSession(
    val id: String = randomId(),
    val date: String,
    val planId: String,
    val planName: String,
    val planColor: String,
    val exercises: List<LoggedExercise> = emptyList(),
    val sport: String? = null,
    val durationMin: Int? = null,
    val durationSec: Int? = null,
    val rpe: Int? = null,
    val avgHR: Int? = null,
    val maxHRSes: Int? = null,
    val rmssd: Double? = null,
    val distanceKm: Double? = null,
    val paceManual: Double? = null,
    val elevationM: Double? = null,
    val poolLengthM: Int? = null,
    val caloriesManual: Int? = null,
    val healthUUID: String? = null,
    val source: String? = null
) {
    val totalSets: Int get() = exercises.sumOf { it.sets.size }
    val volume: Double get() = exercises.sumOf { it.volume }
    val sportType: Sport get() = Sport.from(sport ?: "strength")

    val durationSeconds: Int?
        get() = when {
            (durationSec ?: 0) > 0 -> durationSec
            (durationMin ?: 0) > 0 -> durationMin!! * 60
            else -> null
        }
    val durationMinutesD: Double? get() = durationSeconds?.let { it / 60.0 }

    val sRPE: Double?
        get() {
            val d = durationMinutesD; val r = rpe
            return if (d != null && r != null && d > 0 && r > 0) d * r else null
        }

    val paceIsSpeed: Boolean get() = sportType == Sport.CYCLING
    val paceUnit: String get() = when (sportType) {
        Sport.CYCLING -> "km/h"; Sport.SWIMMING -> "/100m"; else -> "/km"
    }
    val autoPace: Double?
        get() {
            val mins = durationMinutesD ?: return null
            if (mins <= 0) return null
            val dist = distanceKm ?: return null
            if (dist <= 0) return null
            return when (sportType) {
                Sport.CYCLING -> dist / (mins / 60)
                Sport.SWIMMING -> mins / (dist * 1000 / 100)
                else -> mins / dist
            }
        }
    val effectivePace: Double? get() = paceManual ?: autoPace
    val pace: Double? get() = autoPace
}

// MARK: - Body measurements
@Serializable
data class BodyEntry(
    val date: String,
    val waist: Double? = null,
    val chest: Double? = null,
    val arms: Double? = null,
    val legs: Double? = null,
    val neck: Double? = null,
    val hips: Double? = null,
    val bfManual: Double? = null
) {
    fun value(key: String): Double? = when (key) {
        "waist" -> waist; "chest" -> chest; "arms" -> arms
        "legs" -> legs; "neck" -> neck; "hips" -> hips
        else -> null
    }
    fun withValue(key: String, v: Double): BodyEntry = when (key) {
        "waist" -> copy(waist = v); "chest" -> copy(chest = v); "arms" -> copy(arms = v)
        "legs" -> copy(legs = v); "neck" -> copy(neck = v); "hips" -> copy(hips = v)
        else -> this
    }
}

data class MeasureField(val key: String, val label: String, val color: String)

val measureFields = listOf(
    MeasureField("waist", "Vita", "ff5a52"),
    MeasureField("chest", "Petto", "4fb8c4"),
    MeasureField("arms", "Braccia", "ffb000"),
    MeasureField("legs", "Gambe", "7fc950"),
    MeasureField("neck", "Collo", "b08fff"),
    MeasureField("hips", "Fianchi", "ffe000")
)

// MARK: - Custom workout plans (fully editable)
@Serializable
data class PlanExercise(
    val id: String = randomId(),
    val name: String,
    val sets: Int = 3,
    val reps: String = "10",
    val supersetGroup: Int? = null,
    val method: String? = null,
    val effortMode: String? = null,
    val isBodyweight: Boolean? = null,
    val muscle: String? = null
) {
    val trainMethod: TrainMethod get() = TrainMethod.from(method)
    val effortScale: EffortMode? get() = EffortMode.from(effortMode)
    val bodyweight: Boolean get() = isBodyweight == true
}

@Serializable
data class WorkoutPlan(
    val id: String = randomId(),
    val name: String,
    val sub: String = "",
    val color: String = "ffe000",
    val exercises: List<PlanExercise> = emptyList()
)

// MARK: - Goal / energy mode
enum class GoalMode(val raw: String) {
    CUT("cut"), MAINTAIN("maintain"), BULK("bulk");
    val defaultWeeklyPct: Double get() = when (this) { CUT -> -0.6; MAINTAIN -> 0.0; BULK -> 0.25 }
    val calorieAdjust: Double get() = when (this) { CUT -> -0.18; MAINTAIN -> 0.0; BULK -> 0.12 }
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: MAINTAIN }
}

// MARK: - Activity level (TDEE multiplier)
enum class Activity(val raw: String, val multiplier: Double) {
    SEDENTARY("sedentary", 1.2), LIGHT("light", 1.375), MODERATE("moderate", 1.55),
    HIGH("high", 1.725), ATHLETE("athlete", 1.9);
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: MODERATE }
}

// MARK: - User preferences / goals / profile
@Serializable
data class Prefs(
    val timer: Int = 60,
    val goalWeight: Double = 75.0,
    val goalBF: Double = 15.0,
    val startWeight: Double = 80.0,
    val height: Double = 1.80,
    val language: String? = null,
    val onboarded: Boolean? = null,
    val sex: String? = null,
    val birthDate: String? = null,
    val goalMode: String? = null,
    val weeklyRate: Double? = null,
    val activity: String? = null,
    val trainingDays: Int? = null,
    val restingHR: Int? = null,
    val maxHR: Int? = null,
    val sleepTracking: Boolean? = null,
    val schedule: List<String>? = null,
    val healthConnect: Boolean? = null,
    val healthImport: List<String>? = null,
    val importWorkouts: Boolean? = null,
    val units: String? = null,
    val restDays: List<String>? = null
) {
    val langCode: String get() = if (language == "it" || language == "en") language!! else "it"
    val didOnboard: Boolean get() = onboarded == true
    val sexCode: String get() = sex ?: "m"
    val goal: GoalMode get() = GoalMode.from(goalMode)
    val activityLevel: Activity get() = Activity.from(activity)
    val sleepEnabled: Boolean get() = sleepTracking ?: true
    val age: Int?
        get() {
            val b = birthDate ?: return null
            val d = runCatching { LocalDate.parse(b) }.getOrNull() ?: return null
            return java.time.Period.between(d, LocalDate.now()).years.coerceAtLeast(0)
        }
    val estMaxHR: Int
        get() {
            maxHR?.let { if (it > 0) return it }
            return Math.round(208 - 0.7 * (age ?: 30)).toInt()
        }
    val restHRorDefault: Int get() = restingHR?.takeIf { it > 0 } ?: 60
    val healthConnectEnabled: Boolean get() = healthConnect == true
    val healthCategories: Set<String> get() = (healthImport ?: HealthCategory.allKeys).toSet()
    fun importsHealth(key: String): Boolean = healthCategories.contains(key)
    val importWorkoutsEnabled: Boolean get() = importWorkouts != false
    val imperial: Boolean get() = units == "imperial"
    val restDaySet: Set<String> get() = (restDays ?: emptyList()).toSet()
    val weekSchedule: List<String> get() = schedule?.takeIf { it.size == 7 } ?: List(7) { "" }
    val hasSchedule: Boolean get() = weekSchedule.any { it.isNotEmpty() && it != "rest" }
}

// MARK: - Health Connect import categories (user-selectable)
enum class HealthCategory(val raw: String) {
    STEPS("steps"), REST_HR("restHR"), HRV("hrv"), SLEEP("sleep"),
    SLEEP_HR("sleepHR"), ACTIVE_KCAL("activeKcal"), EXERCISE_MIN("exerciseMin"), VO2MAX("vo2max");
    val labelKey: String get() = "hk.cat.$raw"
    companion object {
        val allKeys: List<String> = entries.map { it.raw }
        fun from(r: String?) = entries.firstOrNull { it.raw == r }
    }
}

// MARK: - Saved exercise entry (exercise library)
@Serializable
data class ExerciseItem(
    val id: String = randomId(),
    val name: String,
    val isBodyweight: Boolean = false,
    val lastUsed: String? = null,
    val base: String? = null,
    val category: String? = null
)

// MARK: - Muscle-group categories
enum class MuscleGroup(val raw: String) {
    CHEST("chest"), BACK("back"), LEGS("legs"), SHOULDERS("shoulders"),
    ARMS("arms"), CORE("core"), FULLBODY("fullbody"), CARDIO("cardio"), OTHER("other");
    val labelKey: String get() = "mg.$raw"
    val color: String get() = when (this) {
        CHEST -> "ff5a52"; BACK -> "4fb8c4"; LEGS -> "ffb000"; SHOULDERS -> "b08fff"
        ARMS -> "7fc950"; CORE -> "ff5da2"; FULLBODY -> "ffe000"; CARDIO -> "53a8ff"; OTHER -> "8a857d"
    }
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: OTHER }
}

// MARK: - Recipe
@Serializable
data class RecipeIngredient(
    val id: String = randomId(),
    val foodId: String? = null,
    val name: String,
    val grams: Double,
    val k100: Double,
    val p100: Double,
    val c100: Double,
    val f100: Double
) {
    val kcal: Int get() = Math.round(k100 * grams / 100).toInt()
    val protein: Double get() = (p100 * grams / 100 * 10).let { Math.round(it) / 10.0 }
    val carbs: Double get() = (c100 * grams / 100 * 10).let { Math.round(it) / 10.0 }
    val fat: Double get() = (f100 * grams / 100 * 10).let { Math.round(it) / 10.0 }
}

@Serializable
data class Recipe(
    val id: String = randomId(),
    val name: String,
    val ingredients: List<RecipeIngredient> = emptyList(),
    val perServing: Boolean = false,
    val servings: Double = 1.0,
    val k100: Double = 0.0,
    val p100: Double = 0.0,
    val c100: Double = 0.0,
    val f100: Double = 0.0,
    val lastUsed: String? = null
) {
    val effK100: Double get() = if (perServing && servings > 0) k100 / servings else k100
    val effP100: Double get() = if (perServing && servings > 0) p100 / servings else p100
    val effC100: Double get() = if (perServing && servings > 0) c100 / servings else c100
    val effF100: Double get() = if (perServing && servings > 0) f100 / servings else f100

    fun log(amount: Double): FoodLog =
        FoodLog(foodId = null, name = name, grams = amount, k100 = effK100, p100 = effP100, c100 = effC100, f100 = effF100)

    fun rebuildFromIngredients(): Recipe {
        if (ingredients.isEmpty()) return this
        val totalGrams = ingredients.sumOf { it.grams }
        if (totalGrams <= 0) return this
        val tK = ingredients.sumOf { it.kcal }.toDouble()
        val tP = ingredients.sumOf { it.protein }
        val tC = ingredients.sumOf { it.carbs }
        val tF = ingredients.sumOf { it.fat }
        return if (perServing) copy(k100 = tK, p100 = tP, c100 = tC, f100 = tF)
        else copy(k100 = tK / totalGrams * 100, p100 = tP / totalGrams * 100,
                  c100 = tC / totalGrams * 100, f100 = tF / totalGrams * 100)
    }
}

// MARK: - Health Connect daily sample (for gap-fill import)
data class HealthDaySample(
    val date: String,
    val steps: Int? = null, val restHR: Int? = null, val rmssd: Double? = null,
    val activeKcal: Int? = null, val exerciseMin: Int? = null,
    val sleepHours: Double? = null, val sleepHR: Int? = null, val vo2max: Double? = null
)

// MARK: - Health Connect workout record (for merge)
data class HealthWorkout(
    val uuid: String,
    val date: String,
    val sport: String,
    val durationSec: Int,
    val avgHR: Int? = null,
    val maxHR: Int? = null,
    val calories: Int? = null,
    val distance: Double? = null,
    val sourceName: String = "",
    val displayName: String = ""
)

// MARK: - The whole persisted document
@Serializable
data class AppData(
    val daily: List<DailyEntry> = emptyList(),
    val sessions: List<WorkoutSession> = emptyList(),
    val body: List<BodyEntry> = emptyList(),
    val plans: List<WorkoutPlan> = emptyList(),
    val prefs: Prefs = Prefs(),
    val cardioTypes: List<CardioType> = emptyList(),
    val foods: List<FoodItem> = emptyList(),
    val exerciseItems: List<ExerciseItem> = emptyList(),
    val recipes: List<Recipe> = emptyList()
)
