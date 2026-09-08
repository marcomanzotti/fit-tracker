package com.fittracker.android.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.fittracker.android.data.CardioType
import com.fittracker.android.data.LoggedExercise
import com.fittracker.android.data.SetEntry
import com.fittracker.android.data.Store
import com.fittracker.android.data.WorkoutPlan
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.utils.Helpers.today
import kotlin.math.max

/**
 * Thin Compose state holders wrapping [Store]. These aren't androidx.lifecycle
 * ViewModels (the app has no process-death/config-change concern worth the
 * extra factory boilerplate here) — they're plain classes created once in
 * MainActivity via `remember { ... }` and passed down, per the single-Store,
 * single-source-of-truth convention the rest of the app uses. All persisted
 * state still flows through Store's StateFlow; these only hold ephemeral UI
 * state (which screen is active, an in-progress live workout, a toast).
 */

/** Thin pass-through to Store for screens that only need read/write access to
 * plans, cardio types and sessions. Screens collect the StateFlow properties
 * directly with `collectAsState()`. */
class StoreViewModel(val store: Store) {
    val plans get() = store.plans
    val cardioTypes get() = store.cardioTypes
    val sessions get() = store.sessions
    val daily get() = store.daily
    val prefs get() = store.prefs
    val foods get() = store.foods
    val recipes get() = store.recipes

    fun plan(id: String) = store.plan(id)
    fun cardioType(id: String) = store.cardioType(id)
    fun commitPlan(plan: WorkoutPlan, isNew: Boolean) = store.commitPlan(plan, isNew)
    fun deletePlan(plan: WorkoutPlan) = store.deletePlan(plan)
    fun commitCardioType(type: CardioType) = store.commitCardioType(type)
    fun deleteCardioType(id: String) = store.deleteCardioType(id)

    fun dailyEntry(date: String) = store.dailyEntry(date)
    fun recentFoods() = store.recentFoods()
    fun saveFood(f: com.fittracker.android.data.FoodItem) = store.saveFood(f)
    fun deleteFood(id: String) = store.deleteFood(id)
    fun saveDayFoods(date: String, logs: List<com.fittracker.android.data.FoodLog>) = store.saveDayFoods(date, logs)
    fun recentRecipes() = store.recentRecipes()
    fun saveRecipe(r: com.fittracker.android.data.Recipe) = store.saveRecipe(r)
    fun deleteRecipe(id: String) = store.deleteRecipe(id)
}

/** Simple transient toast/snackbar message queue. */
class ToastCenter {
    var message by mutableStateOf<String?>(null)
        private set

    fun show(msg: String) { message = msg }
    fun consume() { message = null }
}

/** Tracks the in-progress strength workout (if any) started from the Train tab. */
class ActiveWorkoutViewModel(private val store: Store) {
    var planId by mutableStateOf<String?>(null)
        private set
    var minimized by mutableStateOf(false)

    /** Mutable log of exercises for the live session; committed to Store on save.
     * Backed by a Compose SnapshotStateList so in-place edits (add/remove/replace
     * a set or exercise) recompose LiveWorkout without needing to reassign the
     * whole `log` reference. */
    var log: androidx.compose.runtime.snapshots.SnapshotStateList<LoggedExercise> = androidx.compose.runtime.mutableStateListOf()
        private set

    fun start(plan: WorkoutPlan) {
        planId = plan.id
        minimized = false
        val last = store.lastSession(plan.id)
        val fresh = if (last != null) {
            last.exercises.map { e ->
                e.copy(id = java.util.UUID.randomUUID().toString(), sets = e.sets.map { SetEntry() })
            }
        } else {
            plan.exercises.map { pe ->
                LoggedExercise(
                    name = pe.name,
                    sets = (0 until max(1, pe.sets)).map { SetEntry() },
                    target = "${pe.sets}×${pe.reps}",
                    supersetGroup = pe.supersetGroup, method = pe.method,
                    kind = pe.kind, workSec = pe.workSec, restSec = pe.restSec, rounds = pe.rounds
                )
            }
        }
        log.clear()
        log.addAll(fresh)
    }

    fun end() {
        planId = null
        minimized = false
        log.clear()
    }
}

/** Tracks the in-progress cardio session (if any) started from the Train tab. */
class ActiveCardioViewModel(private val store: Store) {
    var typeId by mutableStateOf<String?>(null)
        private set
    var minimized by mutableStateOf(false)

    fun start(type: CardioType) {
        typeId = type.id
        minimized = false
    }

    fun end() {
        typeId = null
        minimized = false
    }
}

/** Body tab: parses free-text inputs and forwards them to Store. */
class BodyViewModel(val store: Store) {
    val daily get() = store.daily
    val body get() = store.body
    val prefs get() = store.prefs

    fun saveCheckIn(weight: String) {
        val w = pf(weight).takeIf { it > 0 }
        store.saveCheckIn(weight = w, sleep = null)
    }
    fun saveSteps(steps: String) {
        val s = steps.toIntOrNull()
        if (s != null) store.saveDailyExtras(steps = s)
    }
    fun saveBf(bf: String) {
        val v = pf(bf).takeIf { it > 0 }
        if (v != null) store.saveBodyFat(v)
    }
    fun saveManualSleep(hours: String, score: String) {
        store.saveManualSleep(
            hours = hours.toDoubleOrNull(),
            score = score.toIntOrNull(),
            hrv = null,
            sleepHR = null
        )
    }
    fun saveMeasurements(values: Map<String, String>) {
        val parsed = values.mapNotNull { (k, v) -> pf(v).takeIf { it > 0 }?.let { k to it } }.toMap()
        if (parsed.isNotEmpty()) store.saveMeasurements(parsed)
    }
}

/** Stats tab: currently a thin wrapper; the science/Metrics extension
 * functions on Store back every chart/number the Stats screens will show. */
class StatsViewModel(val store: Store)
