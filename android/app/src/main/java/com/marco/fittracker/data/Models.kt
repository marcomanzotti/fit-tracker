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

val itMonths = listOf("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")
val itDays = listOf("Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom")

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
        // %g-like: strip trailing zeros
        val s = ((Math.round(v * 1000.0)) / 1000.0).toString()
        if (s.endsWith(".0")) s.dropLast(2) else s
    }

// MARK: - Daily check-in (weight + sleep + optional nutrition / recovery)
// Every field added after the original schema has a default, so old saved JSON
// keeps decoding (kotlinx.serialization uses the default for missing keys).
@Serializable
data class DailyEntry(
    val date: String,          // yyyy-MM-dd
    val weight: Double? = null,
    val sleep: Int? = null,
    // Nutrition (optional)
    val kcal: Int? = null,
    val protein: Double? = null,
    val carbs: Double? = null,
    val fat: Double? = null,
    val salt: Double? = null,
    val steps: Int? = null,
    // Recovery (optional, manual entry)
    val rmssd: Double? = null,
    val restHR: Int? = null,
    val hrvSDNN: Double? = null    // HRV SDNN imported from a health platform (ms)
)

// MARK: - A single logged set
@Serializable
data class SetEntry(
    val id: String = randomId(),
    val reps: String = "",
    val weight: String = ""
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

// MARK: - An exercise as logged inside a session
@Serializable
data class LoggedExercise(
    val id: String = randomId(),
    val name: String,
    val sets: List<SetEntry> = emptyList(),
    val notes: String = "",
    val target: String = "",
    val supersetGroup: Int? = null,
    val method: String? = null
) {
    val volume: Double get() = sets.sumOf { pf(it.reps) * pf(it.weight) }
    val maxWeight: Double get() = sets.maxOfOrNull { pf(it.weight) } ?: 0.0
    val trainMethod: TrainMethod get() = TrainMethod.from(method)
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
    fun label(): String = L.t("sport." + raw)
    companion object { fun from(r: String?) = entries.firstOrNull { it.raw == r } ?: STRENGTH }
}

// MARK: - A saved, customizable cardio activity type (mirrors WorkoutPlan)
@Serializable
data class CardioType(
    val id: String = randomId(),
    val name: String,
    val sport: String,         // Sport raw value
    val color: String          // hex from T.cardioColors
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
    // Internal-load / cardio fields (all optional, backward compatible)
    val sport: String? = null,
    val durationMin: Int? = null,
    val rpe: Int? = null,
    val avgHR: Int? = null,
    val maxHRSes: Int? = null,
    val rmssd: Double? = null,
    val distanceKm: Double? = null,
    val elevationM: Double? = null,
    val poolLengthM: Int? = null,
    val caloriesManual: Int? = null
) {
    val totalSets: Int get() = exercises.sumOf { it.sets.size }
    val volume: Double get() = exercises.sumOf { it.volume }
    val sportType: Sport get() = Sport.from(sport ?: "strength")
    /** sRPE internal load = duration (min) x session RPE. */
    val sRPE: Double?
        get() {
            val d = durationMin; val r = rpe
            return if (d != null && r != null && d > 0 && r > 0) (d * r).toDouble() else null
        }
    /** Average pace: min/km (run/walk/bike) or min/100m (swim). */
    val pace: Double?
        get() {
            val d = durationMin ?: return null
            if (d <= 0) return null
            val dist = distanceKm ?: return null
            if (dist <= 0) return null
            return if (sportType == Sport.SWIMMING) d / (dist * 1000 / 100) else d / dist
        }
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
    val method: String? = null
) {
    val trainMethod: TrainMethod get() = TrainMethod.from(method)
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
    // Clean, generic male defaults; onboarding swaps in female defaults when the
    // user picks "Female". Existing users keep their saved values.
    val goalWeight: Double = 75.0,
    val goalBF: Double = 15.0,
    val startWeight: Double = 80.0,
    val height: Double = 1.80,
    // optional (backward-compatible) profile fields
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
    // Optional weekly schedule: 7 entries Mon..Sun, each a plan id / cardio id /
    // "rest" / "" (auto). When any slot is set, "next workout" follows the week.
    val schedule: List<String>? = null,
    val healthKit: Boolean? = null,
    // Days explicitly marked as rest (yyyy-MM-dd). A marker, not a session.
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
            val d = runCatching { java.time.LocalDate.parse(b) }.getOrNull() ?: return null
            return java.time.Period.between(d, java.time.LocalDate.now()).years.coerceAtLeast(0)
        }
    val estMaxHR: Int
        get() {
            maxHR?.let { if (it > 0) return it }
            return Math.round(208 - 0.7 * (age ?: 30)).toInt()
        }
    val restHRorDefault: Int get() = restingHR?.takeIf { it > 0 } ?: 60
    val healthKitEnabled: Boolean get() = healthKit == true
    val restDaySet: Set<String> get() = (restDays ?: emptyList()).toSet()
    /** Schedule normalized to exactly 7 slots (Mon..Sun); missing -> all empty. */
    val weekSchedule: List<String> get() = schedule?.takeIf { it.size == 7 } ?: List(7) { "" }
    val hasSchedule: Boolean get() = weekSchedule.any { it.isNotEmpty() && it != "rest" }
}

// MARK: - The whole persisted document
@Serializable
data class AppData(
    val daily: List<DailyEntry> = emptyList(),
    val sessions: List<WorkoutSession> = emptyList(),
    val body: List<BodyEntry> = emptyList(),
    val plans: List<WorkoutPlan> = emptyList(),
    val prefs: Prefs = Prefs(),
    val cardioTypes: List<CardioType> = emptyList()
)
