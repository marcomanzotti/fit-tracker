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

// MARK: - Daily check-in (weight + sleep score)
@Serializable
data class DailyEntry(
    val date: String,          // yyyy-MM-dd
    val weight: Double? = null,
    val sleep: Int? = null
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

// MARK: - An exercise as logged inside a session
@Serializable
data class LoggedExercise(
    val id: String = randomId(),
    val name: String,
    val sets: List<SetEntry> = emptyList(),
    val notes: String = "",
    val target: String = ""
) {
    val volume: Double get() = sets.sumOf { pf(it.reps) * pf(it.weight) }
    val maxWeight: Double get() = sets.maxOfOrNull { pf(it.weight) } ?: 0.0
}

// MARK: - A completed workout session
@Serializable
data class WorkoutSession(
    val id: String = randomId(),
    val date: String,
    val planId: String,
    val planName: String,
    val planColor: String,
    val exercises: List<LoggedExercise> = emptyList()
) {
    val totalSets: Int get() = exercises.sumOf { it.sets.size }
    val volume: Double get() = exercises.sumOf { it.volume }
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
    MeasureField("hips", "Fianchi", "ff6a00")
)

// MARK: - Custom workout plans (fully editable)
@Serializable
data class PlanExercise(
    val id: String = randomId(),
    val name: String,
    val sets: Int = 3,
    val reps: String = "10"
)

@Serializable
data class WorkoutPlan(
    val id: String = randomId(),
    val name: String,
    val sub: String = "",
    val color: String = "ff6a00",
    val exercises: List<PlanExercise> = emptyList()
)

// MARK: - User preferences / goals
@Serializable
data class Prefs(
    val timer: Int = 60,
    val goalWeight: Double = 80.0,
    val goalBF: Double = 15.0,
    val startWeight: Double = 88.0,
    val height: Double = 1.85
)

// MARK: - The whole persisted document
@Serializable
data class AppData(
    val daily: List<DailyEntry> = emptyList(),
    val sessions: List<WorkoutSession> = emptyList(),
    val body: List<BodyEntry> = emptyList(),
    val plans: List<WorkoutPlan> = emptyList(),
    val prefs: Prefs = Prefs()
)
