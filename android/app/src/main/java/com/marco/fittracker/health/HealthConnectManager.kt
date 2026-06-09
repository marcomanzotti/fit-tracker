package com.marco.fittracker.health

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.marco.fittracker.data.*
import java.time.Instant
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

// MARK: - Health Connect availability check
object HealthConnectAvailability {
    fun isAvailable(context: Context): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    fun openPlayStore(context: Context) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.apps.healthdata"))
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}

// MARK: - Main Health Connect reader
class HealthConnectManager(private val context: Context) {
    private val client: HealthConnectClient? = runCatching {
        if (HealthConnectAvailability.isAvailable(context)) HealthConnectClient.getOrCreate(context) else null
    }.getOrNull()

    val isAvailable get() = client != null

    // MARK: - Read daily health samples (last N days)
    suspend fun readDailySamples(days: Int = 30): List<HealthDaySample> {
        val c = client ?: return emptyList()
        val end = Instant.now()
        val start = end.minus(days.toLong(), ChronoUnit.DAYS)
        val filter = TimeRangeFilter.between(start, end)
        val result = mutableMapOf<String, HealthDaySample>()

        fun date(instant: Instant): String = instant.atZone(java.time.ZoneId.systemDefault()).toLocalDate().toString()

        runCatching {
            // Steps
            c.readRecords(ReadRecordsRequest(StepsRecord::class, filter)).records.forEach { r ->
                val d = date(r.startTime)
                val cur = result[d] ?: HealthDaySample(d)
                result[d] = cur.copy(steps = (cur.steps ?: 0) + r.count.toInt())
            }
        }
        runCatching {
            // Resting HR
            c.readRecords(ReadRecordsRequest(RestingHeartRateRecord::class, filter)).records.forEach { r ->
                val d = date(r.time)
                val cur = result[d] ?: HealthDaySample(d)
                val existing = cur.restHR
                val bpm = r.beatsPerMinute.toInt()
                result[d] = cur.copy(restHR = if (existing == null || bpm < existing) bpm else existing)
            }
        }
        runCatching {
            // HRV (RMSSD)
            c.readRecords(ReadRecordsRequest(HeartRateVariabilityRmssdRecord::class, filter)).records.forEach { r ->
                val d = date(r.time)
                val cur = result[d] ?: HealthDaySample(d)
                result[d] = cur.copy(rmssd = r.heartRateVariabilityMillis)
            }
        }
        runCatching {
            // Sleep duration
            c.readRecords(ReadRecordsRequest(SleepSessionRecord::class, filter)).records.forEach { r ->
                val d = date(r.startTime)
                val hours = ChronoUnit.MINUTES.between(r.startTime, r.endTime) / 60.0
                val cur = result[d] ?: HealthDaySample(d)
                val tot = (cur.sleepHours ?: 0.0) + hours
                result[d] = cur.copy(sleepHours = tot)
            }
        }
        runCatching {
            // Active calories
            c.readRecords(ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, filter)).records.forEach { r ->
                val d = date(r.startTime)
                val cur = result[d] ?: HealthDaySample(d)
                result[d] = cur.copy(activeKcal = (cur.activeKcal ?: 0) + r.energy.inKilocalories.toInt())
            }
        }
        runCatching {
            // Exercise minutes
            c.readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, filter)).records.forEach { r ->
                val d = date(r.startTime)
                val mins = ChronoUnit.MINUTES.between(r.startTime, r.endTime).toInt()
                val cur = result[d] ?: HealthDaySample(d)
                result[d] = cur.copy(exerciseMin = (cur.exerciseMin ?: 0) + mins)
            }
        }
        runCatching {
            // VO2 max
            c.readRecords(ReadRecordsRequest(Vo2MaxRecord::class, filter)).records.forEach { r ->
                val d = date(r.time)
                val cur = result[d] ?: HealthDaySample(d)
                if (cur.vo2max == null) result[d] = cur.copy(vo2max = r.vo2MillilitersPerMinuteKilogram)
            }
        }

        return result.values.sortedByDescending { it.date }
    }

    // MARK: - Read workout sessions from Health Connect
    suspend fun readWorkouts(days: Int = 30): List<HealthWorkout> {
        val c = client ?: return emptyList()
        val end = Instant.now()
        val start = end.minus(days.toLong(), ChronoUnit.DAYS)
        val filter = TimeRangeFilter.between(start, end)

        return runCatching {
            c.readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, filter)).records
                .mapNotNull { r ->
                    val durationSec = ChronoUnit.SECONDS.between(r.startTime, r.endTime).toInt()
                    if (durationSec < 60) return@mapNotNull null
                    HealthWorkout(
                        uuid = r.metadata.id,
                        sport = exerciseTypeSport(r.exerciseType),
                        date = r.startTime.atZone(java.time.ZoneId.systemDefault()).toLocalDate().toString(),
                        durationSec = durationSec,
                        avgHR = null,
                        calories = null,
                        distance = null
                    )
                }
        }.getOrDefault(emptyList())
    }

    // MARK: - Apply samples to store (gap-fill — manual values win)
    fun applyToStore(store: Store, prefs: com.marco.fittracker.data.Prefs, samples: List<HealthDaySample>) {
        if (!prefs.healthConnectEnabled) return
        store.applyHealthSamples(samples.filter { s ->
            HealthCategory.entries.any { cat -> prefs.importsHealth(cat.raw) && s.hasCategory(cat) }
        })
    }

    // MARK: - Import Health Connect workouts, merge with phone data
    fun importWorkouts(store: Store, prefs: com.marco.fittracker.data.Prefs, workouts: List<HealthWorkout>) {
        if (!prefs.healthConnectEnabled || !prefs.importWorkoutsEnabled) return
        store.applyHealthWorkouts(workouts)
    }
}

// MARK: - Map ExerciseSessionRecord type → Sport
// Integer values from Health Connect 1.1.0-alpha07 ExerciseSessionRecord constants
private fun exerciseTypeSport(type: Int): String = when (type) {
    56, 57 -> "running"    // RUNNING, RUNNING_TREADMILL
    8, 9   -> "cycling"    // BIKING, BIKING_STATIONARY
    82, 83 -> "swimming"   // SWIMMING_POOL, SWIMMING_OPEN_WATER
    79     -> "walking"    // WALKING
    45, 97 -> "strength"   // STRENGTH_TRAINING, WEIGHTLIFTING
    else   -> "other"
}

// MARK: - HealthDaySample extension to check category coverage
private fun HealthDaySample.hasCategory(cat: HealthCategory): Boolean = when (cat) {
    HealthCategory.STEPS -> steps != null
    HealthCategory.REST_HR -> restHR != null
    HealthCategory.HRV -> rmssd != null
    HealthCategory.SLEEP, HealthCategory.SLEEP_HR -> sleepHours != null
    HealthCategory.ACTIVE_KCAL -> activeKcal != null
    HealthCategory.EXERCISE_MIN -> exerciseMin != null
    HealthCategory.VO2MAX -> vo2max != null
}
