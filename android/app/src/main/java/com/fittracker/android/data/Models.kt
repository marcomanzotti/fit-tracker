package com.fittracker.android.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import java.util.UUID

@Serializable
data class DailyEntry(
    var date: String,
    var weight: Double? = null,
    var sleep: Int? = null,
    var kcal: Int? = null,
    var protein: Double? = null,
    var carbs: Double? = null,
    var fat: Double? = null,
    var salt: Double? = null,
    var steps: Int? = null,
    var stepsManual: Boolean? = null,
    var rmssd: Double? = null,
    var restHR: Int? = null,
    var hrvSDNN: Double? = null,
    var sleepHR: Int? = null,
    var sleepHours: Double? = null,
    var activeKcal: Int? = null,
    var exerciseMin: Int? = null,
    var vo2max: Double? = null,
    var meals: Map<String, MealEntry>? = null,
    var foods: List<FoodLog>? = null
)

@Serializable
data class MealEntry(
    var kcal: Int = 0,
    var protein: Double = 0.0,
    var carbs: Double = 0.0,
    var fat: Double = 0.0,
    var foods: List<FoodLog>? = null
)

@Serializable
data class FoodItem(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var brand: String? = null,
    var barcode: String? = null,
    var k100: Double = 0.0,
    var p100: Double = 0.0,
    var c100: Double = 0.0,
    var f100: Double = 0.0,
    var liquid: Boolean = false,
    var lastUsed: String? = null
)

@Serializable
data class FoodLog(
    var id: String = UUID.randomUUID().toString(),
    var foodId: String? = null,
    var name: String,
    var grams: Double,
    var k100: Double,
    var p100: Double,
    var c100: Double,
    var f100: Double,
    var portions: Double? = null
)

@Serializable
data class SetEntry(
    var id: String = UUID.randomUUID().toString(),
    var reps: String = "",
    var weight: String = "",
    var effortVal: Int? = null,
    var seconds: Double? = null
)

@Serializable
data class LoggedExercise(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var sets: List<SetEntry> = emptyList(),
    var notes: String = "",
    var target: String = "",
    var supersetGroup: Int? = null,
    var method: String? = null,
    var effortMode: String? = null,
    var isBodyweight: Boolean? = null,
    var kind: String? = null,
    var workSec: Int? = null,
    var restSec: Int? = null,
    var rounds: Int? = null
)

@Serializable
data class CardioType(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var sport: String,
    var color: String,
    var sub: String? = null
)

@Serializable
data class WorkoutSession(
    var id: String = UUID.randomUUID().toString(),
    var date: String,
    var planId: String,
    var planName: String,
    var planColor: String,
    var exercises: List<LoggedExercise> = emptyList(),
    var sport: String? = null,
    var durationMin: Int? = null,
    var durationSec: Int? = null,
    var rpe: Int? = null,
    var avgHR: Int? = null,
    var maxHRSes: Int? = null,
    var rmssd: Double? = null,
    var distanceKm: Double? = null,
    var paceManual: Double? = null,
    var elevationM: Double? = null,
    var poolLengthM: Int? = null,
    var caloriesManual: Int? = null,
    var healthUUID: String? = null,
    var source: String? = null,
    var mergedHealthUUIDs: List<String>? = null,
    var exportedHealthUUID: String? = null
)

@Serializable
data class BodyEntry(
    var date: String,
    var waist: Double? = null,
    var chest: Double? = null,
    var arms: Double? = null,
    var legs: Double? = null,
    var neck: Double? = null,
    var hips: Double? = null,
    var bfManual: Double? = null
)

@Serializable
data class PlanExercise(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var sets: Int = 3,
    var reps: String = "10",
    var supersetGroup: Int? = null,
    var method: String? = null,
    var effortMode: String? = null,
    var isBodyweight: Boolean? = null,
    var muscle: String? = null,
    var kind: String? = null,
    var workSec: Int? = null,
    var restSec: Int? = null,
    var rounds: Int? = null,
    var targetSec: Int? = null,
    var restTimerSec: Int? = null
)

@Serializable
data class WorkoutPlan(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var sub: String = "",
    var color: String = "ffe000",
    var exercises: List<PlanExercise> = emptyList()
)

@Serializable
data class Prefs(
    var timer: Int = 60,
    var goalWeight: Double = 75.0,
    var goalBF: Double = 15.0,
    var startWeight: Double = 80.0,
    var height: Double = 1.80,
    var language: String? = null,
    var onboarded: Boolean? = null,
    var sex: String? = null,
    var birthDate: String? = null,
    var goalMode: String? = null,
    var weeklyRate: Double? = null,
    var activity: String? = null,
    var trainingDays: Int? = null,
    var restingHR: Int? = null,
    var maxHR: Int? = null,
    var sleepTracking: Boolean? = null,
    var schedule: List<String>? = null,
    var healthKit: Boolean? = null,
    var healthImport: List<String>? = null,
    var importWorkouts: Boolean? = null,
    var healthBackfilled: Boolean? = null,
    var holdPrepSec: Int? = null,
    var autoRestTimer: Boolean? = null,
    var barWeight: Double? = null,
    var plates: List<Double>? = null,
    var exportToHealth: Boolean? = null,
    var liveActivity: Boolean? = null,
    var volumeTargets: Map<String, Int>? = null,
    var units: String? = null,
    var restDays: List<String>? = null,
    var foodSort: String? = null,
    var foodSortAsc: Boolean? = null,
    var seededExercises: Boolean? = null
)

@Serializable
data class ExerciseItem(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var isBodyweight: Boolean = false,
    var lastUsed: String? = null,
    var base: String? = null,
    var category: String? = null
)

@Serializable
data class RecipeIngredient(
    var id: String = UUID.randomUUID().toString(),
    var foodId: String? = null,
    var name: String,
    var grams: Double,
    var k100: Double,
    var p100: Double,
    var c100: Double,
    var f100: Double
)

@Serializable
data class Recipe(
    var id: String = UUID.randomUUID().toString(),
    var name: String,
    var ingredients: List<RecipeIngredient> = emptyList(),
    var perServing: Boolean = false,
    var servings: Double = 1.0,
    var k100: Double = 0.0,
    var p100: Double = 0.0,
    var c100: Double = 0.0,
    var f100: Double = 0.0,
    var lastUsed: String? = null
)

@Serializable
data class AppData(
    var schemaVersion: Int? = null,
    var daily: List<DailyEntry> = emptyList(),
    var sessions: List<WorkoutSession> = emptyList(),
    var body: List<BodyEntry> = emptyList(),
    var plans: List<WorkoutPlan> = emptyList(),
    var prefs: Prefs = Prefs(),
    var cardioTypes: List<CardioType>? = emptyList(),
    var foods: List<FoodItem>? = emptyList(),
    var exerciseItems: List<ExerciseItem>? = emptyList(),
    var recipes: List<Recipe>? = emptyList()
) {
    companion object {
        const val currentSchemaVersion = 1
    }
}

