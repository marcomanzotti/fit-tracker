package com.fittracker.android.data

import com.fittracker.android.utils.Helpers.isoFormatter
import com.fittracker.android.utils.Helpers.pf
import java.util.Calendar
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Kotlin ports of the computed properties Swift attaches directly to its model
 * structs (Models.swift). Kotlin `@Serializable data class`es can't carry
 * computed stored-property-like logic inline as cleanly while staying pure
 * data holders for kotlinx.serialization, so they live here as extension
 * properties/functions with the same names/semantics as their Swift originals.
 */

// MARK: - Enums mirrored as plain string constants (kept as String raw values
// in the data classes, exactly like the Swift `rawValue` pattern, so JSON is
// backward compatible either way).

enum class ExKind(val raw: String) {
    REPS("reps"), TIMED("timed"), INTERVAL("interval");
    companion object {
        fun from(raw: String?): ExKind = values().firstOrNull { it.raw == raw } ?: REPS
    }
}

enum class TrainMethod(val raw: String) {
    NORMAL("normal"), SUPERSET("superset"), DROPSET("dropset"), RESTPAUSE("restpause"), GIANT("giant");
    companion object {
        fun from(raw: String?): TrainMethod = values().firstOrNull { it.raw == raw } ?: NORMAL
    }
}

enum class EffortMode(val raw: String) {
    RIR("rir"), RPE("rpe"), FAIL("fail");
    companion object {
        fun from(raw: String?): EffortMode? = values().firstOrNull { it.raw == raw }
    }
}

enum class Sport(val raw: String) {
    STRENGTH("strength"), RUNNING("running"), SWIMMING("swimming"), CYCLING("cycling"), WALKING("walking"), OTHER("other");
    val isCardio: Boolean get() = this != STRENGTH
    val label: String get() = com.fittracker.android.localization.L.t("sport.$raw")
    companion object {
        fun from(raw: String?): Sport = values().firstOrNull { it.raw == raw } ?: STRENGTH
    }
}

enum class GoalMode(val raw: String) {
    CUT("cut"), MAINTAIN("maintain"), BULK("bulk");
    val calorieAdjust: Double get() = when (this) {
        CUT -> -0.18; MAINTAIN -> 0.0; BULK -> 0.12
    }
    companion object {
        fun from(raw: String?): GoalMode = values().firstOrNull { it.raw == raw } ?: MAINTAIN
    }
}

enum class Activity(val raw: String) {
    SEDENTARY("sedentary"), LIGHT("light"), MODERATE("moderate"), HIGH("high"), ATHLETE("athlete");
    val multiplier: Double get() = when (this) {
        SEDENTARY -> 1.2; LIGHT -> 1.375; MODERATE -> 1.55; HIGH -> 1.725; ATHLETE -> 1.9
    }
    companion object {
        fun from(raw: String?): Activity = values().firstOrNull { it.raw == raw } ?: MODERATE
    }
}

enum class MuscleGroup(val raw: String) {
    CHEST("chest"), BACK("back"), LEGS("legs"), SHOULDERS("shoulders"), ARMS("arms"),
    CORE("core"), FULLBODY("fullbody"), CARDIO("cardio"), OTHER("other");
    companion object {
        fun from(raw: String?): MuscleGroup = values().firstOrNull { it.raw == raw } ?: OTHER
        val allCases: List<MuscleGroup> get() = values().toList()
    }
}

// MARK: - SetEntry
val SetEntry.filled: Boolean
    get() = pf(reps) > 0 || pf(weight) > 0 || (seconds ?: 0.0) > 0

// MARK: - LoggedExercise
val LoggedExercise.exKind: ExKind get() = ExKind.from(kind)
val LoggedExercise.trainMethod: TrainMethod get() = TrainMethod.from(method)
val LoggedExercise.effortScale: EffortMode? get() = EffortMode.from(effortMode)
val LoggedExercise.bodyweight: Boolean get() = isBodyweight == true

val LoggedExercise.volume: Double
    get() = when (exKind) {
        ExKind.REPS -> sets.sumOf { pf(it.reps) * pf(it.weight) }
        ExKind.TIMED -> sets.sumOf { (it.seconds ?: 0.0) * max(1.0, pf(it.weight)) }
        ExKind.INTERVAL -> ((rounds ?: 0) * (workSec ?: 0)).toDouble()
    }
val LoggedExercise.maxWeight: Double get() = sets.maxOfOrNull { pf(it.weight) } ?: 0.0
val LoggedExercise.maxSeconds: Double get() = sets.mapNotNull { it.seconds }.maxOrNull() ?: 0.0

// MARK: - PlanExercise
val PlanExercise.exKind: ExKind get() = ExKind.from(kind)
val PlanExercise.trainMethod: TrainMethod get() = TrainMethod.from(method)
val PlanExercise.effortScale: EffortMode? get() = EffortMode.from(effortMode)
val PlanExercise.bodyweight: Boolean get() = isBodyweight == true
val PlanExercise.effectiveTargetSec: Int
    get() {
        if ((targetSec ?: 0) > 0) return targetSec!!
        val lower = reps.lowercase()
        if (lower.contains(":")) {
            val parts = lower.split(":")
            if (parts.size == 2) {
                val m = parts[0].toIntOrNull()
                val s = parts[1].toIntOrNull()
                if (m != null && s != null) return m * 60 + s
            }
        }
        val nums = Regex("[0-9]+").findAll(lower).map { it.value.toInt() }.toList()
        return nums.maxOrNull() ?: 0
    }

// MARK: - CardioType
val CardioType.sportType: Sport get() = Sport.from(sport)

// MARK: - WorkoutSession
val WorkoutSession.allHealthUUIDs: List<String>
    get() = (healthUUID?.let { listOf(it) } ?: emptyList()) + (mergedHealthUUIDs ?: emptyList())
val WorkoutSession.totalSets: Int get() = exercises.sumOf { it.sets.size }
val WorkoutSession.volume: Double get() = exercises.sumOf { it.volume }
val WorkoutSession.sportType: Sport get() = Sport.from(sport ?: "strength")
val WorkoutSession.durationSeconds: Int?
    get() {
        if ((durationSec ?: 0) > 0) return durationSec
        if ((durationMin ?: 0) > 0) return durationMin!! * 60
        return null
    }
val WorkoutSession.durationMinutesD: Double? get() = durationSeconds?.let { it / 60.0 }
val WorkoutSession.sRPE: Double?
    get() {
        val d = durationMinutesD ?: return null
        val r = rpe ?: return null
        if (d <= 0 || r <= 0) return null
        return d * r
    }
val WorkoutSession.paceIsSpeed: Boolean get() = sportType == Sport.CYCLING
val WorkoutSession.paceUnit: String
    get() = when (sportType) {
        Sport.CYCLING -> "km/h"
        Sport.SWIMMING -> "/100m"
        else -> "/km"
    }
val WorkoutSession.autoPace: Double?
    get() {
        val mins = durationMinutesD ?: return null
        val dist = distanceKm ?: return null
        if (mins <= 0 || dist <= 0) return null
        return when (sportType) {
            Sport.CYCLING -> dist / (mins / 60)
            Sport.SWIMMING -> mins / (dist * 1000 / 100)
            else -> mins / dist
        }
    }
val WorkoutSession.effectivePace: Double? get() = paceManual ?: autoPace

// MARK: - DailyEntry
val DailyEntry.hasNutrition: Boolean
    get() = (kcal ?: 0) > 0 ||
        (meals?.values?.any { !it.isEmpty() } ?: false) ||
        !(foods.isNullOrEmpty())

fun MealEntry.isEmpty(): Boolean = kcal == 0 && protein == 0.0 && carbs == 0.0 && fat == 0.0 && !hasFoods
val MealEntry.hasFoods: Boolean get() = !(foods.isNullOrEmpty())
val MealEntry.effKcal: Int get() = if (hasFoods) foods!!.sumOf { it.kcal } else kcal
val MealEntry.effProtein: Double get() = if (hasFoods) foods!!.sumOf { it.protein } else protein
val MealEntry.effCarbs: Double get() = if (hasFoods) foods!!.sumOf { it.carbs } else carbs
val MealEntry.effFat: Double get() = if (hasFoods) foods!!.sumOf { it.fat } else fat

val DailyEntry.totalKcal: Int
    get() {
        var s = 0
        meals?.let { s += it.values.sumOf { m -> m.effKcal } }
        foods?.let { s += it.sumOf { f -> f.kcal } }
        return if (s > 0) s else (kcal ?: 0)
    }
val DailyEntry.totalProtein: Double
    get() {
        var s = 0.0
        meals?.let { s += it.values.sumOf { m -> m.effProtein } }
        foods?.let { s += it.sumOf { f -> f.protein } }
        return if (s > 0) s else (protein ?: 0.0)
    }
val DailyEntry.totalCarbs: Double
    get() {
        var s = 0.0
        meals?.let { s += it.values.sumOf { m -> m.effCarbs } }
        foods?.let { s += it.sumOf { f -> f.carbs } }
        return if (s > 0) s else (carbs ?: 0.0)
    }
val DailyEntry.totalFat: Double
    get() {
        var s = 0.0
        meals?.let { s += it.values.sumOf { m -> m.effFat } }
        foods?.let { s += it.sumOf { f -> f.fat } }
        return if (s > 0) s else (fat ?: 0.0)
    }

// MARK: - FoodItem / FoodLog
val FoodItem.unit: String get() = if (liquid) "ml" else "g"
val FoodItem.fullName: String get() = brand?.let { "$it – $name" } ?: name
fun FoodItem.log(grams: Double): FoodLog =
    FoodLog(foodId = id, name = fullName, grams = grams, k100 = k100, p100 = p100, c100 = c100, f100 = f100)

private fun scale100(per100: Double, grams: Double): Double = ((per100 * grams / 100) * 10).roundToInt() / 10.0
val FoodLog.kcal: Int get() = (k100 * grams / 100).roundToInt()
val FoodLog.protein: Double get() = scale100(p100, grams)
val FoodLog.carbs: Double get() = scale100(c100, grams)
val FoodLog.fat: Double get() = scale100(f100, grams)

// MARK: - RecipeIngredient / Recipe
val RecipeIngredient.kcal: Int get() = (k100 * grams / 100).roundToInt()
val RecipeIngredient.protein: Double get() = ((p100 * grams / 100) * 10).roundToInt() / 10.0
val RecipeIngredient.carbs: Double get() = ((c100 * grams / 100) * 10).roundToInt() / 10.0
val RecipeIngredient.fat: Double get() = ((f100 * grams / 100) * 10).roundToInt() / 10.0

val Recipe.effK100: Double get() = if (perServing && servings > 0) k100 / servings else k100
val Recipe.effP100: Double get() = if (perServing && servings > 0) p100 / servings else p100
val Recipe.effC100: Double get() = if (perServing && servings > 0) c100 / servings else c100
val Recipe.effF100: Double get() = if (perServing && servings > 0) f100 / servings else f100

fun Recipe.log(amount: Double): FoodLog {
    val grams = if (perServing) amount * 100 else amount
    return FoodLog(
        foodId = null, name = name, grams = grams,
        k100 = effK100, p100 = effP100, c100 = effC100, f100 = effF100,
        portions = if (perServing) amount else null
    )
}

fun Recipe.rebuildFromIngredients(): Recipe {
    if (ingredients.isEmpty()) return this
    val totalGrams = ingredients.sumOf { it.grams }
    if (totalGrams <= 0) return this
    val tK = ingredients.sumOf { it.kcal }.toDouble()
    val tP = ingredients.sumOf { it.protein }
    val tC = ingredients.sumOf { it.carbs }
    val tF = ingredients.sumOf { it.fat }
    return if (perServing) {
        copy(k100 = tK, p100 = tP, c100 = tC, f100 = tF)
    } else {
        copy(k100 = tK / totalGrams * 100, p100 = tP / totalGrams * 100, c100 = tC / totalGrams * 100, f100 = tF / totalGrams * 100)
    }
}

// MARK: - BodyEntry
fun BodyEntry.value(key: String): Double? = when (key) {
    "waist" -> waist; "chest" -> chest; "arms" -> arms; "legs" -> legs; "neck" -> neck; "hips" -> hips
    else -> null
}
fun BodyEntry.set(key: String, v: Double): BodyEntry = when (key) {
    "waist" -> copy(waist = v)
    "chest" -> copy(chest = v)
    "arms" -> copy(arms = v)
    "legs" -> copy(legs = v)
    "neck" -> copy(neck = v)
    "hips" -> copy(hips = v)
    else -> this
}

// MARK: - Prefs
val Prefs.langCode: String
    get() {
        if (language == "it" || language == "en") return language!!
        return if (java.util.Locale.getDefault().language.startsWith("it")) "it" else "en"
    }
val Prefs.didOnboard: Boolean get() = onboarded == true
val Prefs.sex_: String get() = sex ?: "m"
val Prefs.goal: GoalMode get() = GoalMode.from(goalMode)
val Prefs.activityLevel: Activity get() = Activity.from(activity)
val Prefs.sleepEnabled: Boolean get() = sleepTracking ?: true
val Prefs.age: Int?
    get() {
        val bd = birthDate ?: return null
        val d = try { isoFormatter.parse(bd) } catch (e: Exception) { null } ?: return null
        val birthCal = Calendar.getInstance().apply { time = d }
        val nowCal = Calendar.getInstance()
        var yrs = nowCal.get(Calendar.YEAR) - birthCal.get(Calendar.YEAR)
        if (nowCal.get(Calendar.DAY_OF_YEAR) < birthCal.get(Calendar.DAY_OF_YEAR)) yrs -= 1
        return max(0, yrs)
    }
val Prefs.estMaxHR: Int
    get() {
        if ((maxHR ?: 0) > 0) return maxHR!!
        val a = (age ?: 30).toDouble()
        return (208 - 0.7 * a).roundToInt()
    }
val Prefs.restHRorDefault: Int get() = if ((restingHR ?: 0) > 0) restingHR!! else 60
val Prefs.healthKitEnabled: Boolean get() = healthKit == true
val Prefs.imperial: Boolean get() = units == "imperial"
val Prefs.holdPrep: Int get() = min(30, max(0, holdPrepSec ?: 7))
val Prefs.autoRest: Boolean get() = autoRestTimer != false
val Prefs.bar: Double get() = if ((barWeight ?: 0.0) > 0) barWeight!! else 20.0
val Prefs.plateSet: List<Double>
    get() {
        val p = (plates ?: emptyList()).filter { it > 0 }
        return if (p.isEmpty()) listOf(25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25) else p.sortedDescending()
    }
val Prefs.exportsToHealth: Boolean get() = exportToHealth == true
val Prefs.liveActivityEnabled: Boolean get() = liveActivity != false
val Prefs.restDaySet: Set<String> get() = (restDays ?: emptyList()).toSet()
val Prefs.weekSchedule: List<String>
    get() {
        val s = schedule
        if (s == null || s.size != 7) return List(7) { "" }
        return s
    }
val Prefs.hasSchedule: Boolean get() = weekSchedule.any { it.isNotEmpty() && it != "rest" }
fun Prefs.goalDirection(current: Double): Int {
    val diff = goalWeight - current
    if (kotlin.math.abs(diff) < 0.3) return 0
    return if (diff > 0) 1 else -1
}
val Prefs.importWorkoutsEnabled: Boolean get() = importWorkouts != false
