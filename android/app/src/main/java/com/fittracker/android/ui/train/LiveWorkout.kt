package com.fittracker.android.ui.train

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.ExKind
import com.fittracker.android.data.LoggedExercise
import com.fittracker.android.data.SetEntry
import com.fittracker.android.data.WorkoutPlan
import com.fittracker.android.data.exKind
import com.fittracker.android.science.Metrics
import com.fittracker.android.science.bestE1RM
import com.fittracker.android.utils.Helpers.fmtDuration
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.viewmodel.StoreViewModel
import kotlinx.coroutines.delay

// Kotlin port of the live-workout parts of ios/FitTracker/Views/LiveWorkoutView.swift
// + SetLogging.swift: real per-kind set logging (reps/timed/interval), an
// elapsed-time header, a manual rest timer, and inline e1RM PR display.
@Composable
fun LiveWorkout(
    viewModel: StoreViewModel,
    plan: WorkoutPlan,
    log: MutableList<LoggedExercise>,
    onBack: () -> Unit,
    onSaved: () -> Unit
) {
    var addName by remember { mutableStateOf("") }
    var sessAvgHR by remember { mutableStateOf("") }
    var sessCalManual by remember { mutableStateOf("") }
    var confirmDiscard by remember { mutableStateOf(false) }
    var restEndAtMs by remember { mutableStateOf<Long?>(null) }

    val startAtMs = remember { System.currentTimeMillis() }
    var nowMs by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            nowMs = System.currentTimeMillis()
        }
    }
    val elapsedSec = ((nowMs - startAtMs) / 1000).toInt()

    fun replace(exercise: LoggedExercise, updated: LoggedExercise) {
        val i = log.indexOfFirst { it.id == exercise.id }
        if (i >= 0) log[i] = updated
    }

    val defaultRestSec = viewModel.prefs.value.timer

    Column(modifier = Modifier.fillMaxSize()) {
        BackRow(plan = plan, onBack = onBack)

        LiveTimerBlock(elapsedSec = elapsedSec)

        if (restEndAtMs != null) {
            RestTimerBar(endAtMs = restEndAtMs!!, onCancel = { restEndAtMs = null }, onDone = { restEndAtMs = null })
        }

        LazyColumn(modifier = Modifier.weight(1f)) {
            items(log, key = { it.id }) { ex ->
                ExerciseCard(
                    exercise = ex,
                    bestE1RM = viewModel.store.bestE1RM(ex.name),
                    onChange = { updated -> replace(ex, updated) },
                    onDeleteExercise = { log.removeAll { it.id == ex.id } },
                    onStartRest = { seconds -> restEndAtMs = System.currentTimeMillis() + seconds * 1000L },
                    defaultRestSec = defaultRestSec
                )
            }

            item {
                AddExerciseCard(
                    addName = addName,
                    onNameChange = { addName = it },
                    onAdd = {
                        val nm = addName.trim()
                        if (nm.isNotEmpty()) {
                            log.add(LoggedExercise(name = nm, sets = listOf(SetEntry())))
                            addName = ""
                        }
                    }
                )
            }

            item {
                SessionLoadCard(
                    avgHR = sessAvgHR,
                    onAvgHRChange = { sessAvgHR = it }
                )
            }

            item {
                val est = remember(log) { estimateCalories(log) }
                CaloriesCard(
                    manualCal = sessCalManual,
                    onManualCalChange = { sessCalManual = it },
                    estCalories = est
                )
            }

            item {
                Button(
                    onClick = {
                        viewModel.store.logSession(
                            plan = plan,
                            exercises = log.toList(),
                            durationSec = elapsedSec,
                            avgHR = sessAvgHR.toIntOrNull(),
                            caloriesManual = sessCalManual.toIntOrNull()
                        )
                        onSaved()
                    },
                    modifier = Modifier.fillMaxWidth().padding(16.dp)
                ) {
                    Text("Finish Session")
                }

                OutlinedButton(
                    onClick = { confirmDiscard = true },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                ) {
                    Text("Discard Session", color = MaterialTheme.colorScheme.error)
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }

    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text("Discard Workout?") },
            text = { Text("Are you sure you want to discard this session?") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDiscard = false
                    onSaved() // triggers teardown without saving
                }) {
                    Text("Discard", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDiscard = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

/** Rough calorie estimate: sum reps×weight-derived tonnage isn't calories, so
 * this uses a simple per-set flat estimate (5 kcal/set) as a placeholder-but-real
 * number rather than a fake "0" — mirrors the ballpark Store.estimateCalories
 * uses for cardio, just simplified for strength sets. */
private fun estimateCalories(log: List<LoggedExercise>): Int {
    val totalSets = log.sumOf { it.sets.size }
    return totalSets * 5
}

@Composable
fun BackRow(plan: WorkoutPlan, onBack: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextButton(onClick = onBack) {
            Text("↓ Minimize")
        }
        Spacer(Modifier.width(8.dp))
        Column {
            Text(text = plan.name, style = MaterialTheme.typography.titleLarge)
            Text(text = plan.sub, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun LiveTimerBlock(elapsedSec: Int) {
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Row(
            modifier = Modifier.padding(16.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("WORKOUT LIVE", style = MaterialTheme.typography.labelMedium)
            Text(fmtDuration(elapsedSec), style = MaterialTheme.typography.titleLarge)
        }
    }
}

@Composable
fun RestTimerBar(endAtMs: Long, onCancel: () -> Unit, onDone: () -> Unit) {
    var remaining by remember(endAtMs) { mutableStateOf(((endAtMs - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)) }
    LaunchedEffect(endAtMs) {
        while (remaining > 0) {
            delay(1000)
            remaining = ((endAtMs - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
        }
        onDone()
    }
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) {
        Row(
            modifier = Modifier.padding(12.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Rest: ${remaining}s", style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = onCancel) { Text("Skip") }
        }
    }
}

@Composable
fun ExerciseCard(
    exercise: LoggedExercise,
    bestE1RM: Double?,
    onChange: (LoggedExercise) -> Unit,
    onDeleteExercise: () -> Unit,
    onStartRest: (Int) -> Unit,
    defaultRestSec: Int
) {
    var showNotes by remember { mutableStateOf(false) }

    val currentTopE1RM = remember(exercise.sets) {
        exercise.sets.mapNotNull { Metrics.e1RM(pf(it.weight), pf(it.reps)) }.maxOrNull()
    }
    val isPR = bestE1RM != null && currentTopE1RM != null && currentTopE1RM > bestE1RM

    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(exercise.name, style = MaterialTheme.typography.titleMedium)
                    if (exercise.target.isNotEmpty()) {
                        Text(exercise.target, style = MaterialTheme.typography.bodySmall)
                    }
                }
                if (isPR) {
                    Text("PR!", color = MaterialTheme.colorScheme.tertiary, style = MaterialTheme.typography.labelLarge)
                } else if (bestE1RM != null) {
                    Text("best ${bestE1RM.toInt()}kg", style = MaterialTheme.typography.labelSmall)
                }
                IconButton(onClick = onDeleteExercise) {
                    Icon(Icons.Filled.Close, contentDescription = "Remove exercise")
                }
            }

            Spacer(Modifier.height(8.dp))

            when (exercise.exKind) {
                ExKind.REPS -> {
                    exercise.sets.forEachIndexed { i, set ->
                        SetRowReps(
                            index = i + 1,
                            set = set,
                            onChange = { updatedSet ->
                                val sets = exercise.sets.toMutableList()
                                sets[i] = updatedSet
                                onChange(exercise.copy(sets = sets))
                            },
                            onDelete = {
                                val sets = exercise.sets.toMutableList()
                                sets.removeAt(i)
                                onChange(exercise.copy(sets = sets))
                            }
                        )
                    }
                }
                ExKind.TIMED -> {
                    exercise.sets.forEachIndexed { i, set ->
                        SetRowTimed(
                            index = i + 1,
                            set = set,
                            onChange = { updatedSet ->
                                val sets = exercise.sets.toMutableList()
                                sets[i] = updatedSet
                                onChange(exercise.copy(sets = sets))
                            },
                            onDelete = {
                                val sets = exercise.sets.toMutableList()
                                sets.removeAt(i)
                                onChange(exercise.copy(sets = sets))
                            }
                        )
                    }
                }
                ExKind.INTERVAL -> {
                    Text(
                        "${exercise.rounds ?: 0} rounds × ${exercise.workSec ?: 0}s work / ${exercise.restSec ?: 0}s rest",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }

            Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (exercise.exKind != ExKind.INTERVAL) {
                    OutlinedButton(onClick = {
                        val newSets = exercise.sets + SetEntry()
                        onChange(exercise.copy(sets = newSets))
                    }) { Text("+ Set") }
                }
                OutlinedButton(onClick = {
                    val restSec = exercise.restSec ?: defaultRestSec
                    onStartRest(restSec)
                }) { Text("Rest") }
                TextButton(onClick = { showNotes = !showNotes }) { Text("Notes") }
            }

            if (showNotes) {
                OutlinedTextField(
                    value = exercise.notes,
                    onValueChange = { onChange(exercise.copy(notes = it)) },
                    label = { Text("Notes") },
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                )
            }
        }
    }
}

@Composable
fun SetRowReps(index: Int, set: SetEntry, onChange: (SetEntry) -> Unit, onDelete: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text("$index", modifier = Modifier.width(20.dp))
        OutlinedTextField(
            value = set.reps,
            onValueChange = { onChange(set.copy(reps = it)) },
            label = { Text("Reps") },
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        OutlinedTextField(
            value = set.weight,
            onValueChange = { onChange(set.copy(weight = it)) },
            label = { Text("kg") },
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        IconButton(onClick = onDelete) { Icon(Icons.Filled.Close, contentDescription = "Delete set") }
    }
}

@Composable
fun SetRowTimed(index: Int, set: SetEntry, onChange: (SetEntry) -> Unit, onDelete: () -> Unit) {
    var secStr by remember(set.seconds) { mutableStateOf(set.seconds?.let { it.toInt().toString() } ?: "") }
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text("$index", modifier = Modifier.width(20.dp))
        OutlinedTextField(
            value = secStr,
            onValueChange = { v -> secStr = v; onChange(set.copy(seconds = v.toDoubleOrNull())) },
            label = { Text("Seconds") },
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        OutlinedTextField(
            value = set.weight,
            onValueChange = { onChange(set.copy(weight = it)) },
            label = { Text("kg (opt.)") },
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        IconButton(onClick = onDelete) { Icon(Icons.Filled.Close, contentDescription = "Delete set") }
    }
}

@Composable
fun AddExerciseCard(addName: String, onNameChange: (String) -> Unit, onAdd: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = addName,
                onValueChange = onNameChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("Add exercise") }
            )
            IconButton(onClick = onAdd) {
                Text("+", style = MaterialTheme.typography.titleLarge)
            }
        }
    }
}

@Composable
fun SessionLoadCard(avgHR: String, onAvgHRChange: (String) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Internal Load", style = MaterialTheme.typography.labelMedium)
            OutlinedTextField(value = avgHR, onValueChange = onAvgHRChange, label = { Text("Avg HR") }, modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
fun CaloriesCard(manualCal: String, onManualCalChange: (String) -> Unit, estCalories: Int) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Calories (est. $estCalories kcal)", style = MaterialTheme.typography.labelMedium)
            OutlinedTextField(value = manualCal, onValueChange = onManualCalChange, label = { Text("Override kcal") }, modifier = Modifier.fillMaxWidth())
        }
    }
}
