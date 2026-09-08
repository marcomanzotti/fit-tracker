package com.fittracker.android.ui.train

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.LoggedExercise
import com.fittracker.android.data.WorkoutPlan
import com.fittracker.android.data.WorkoutSession
import com.fittracker.android.data.CardioType
import com.fittracker.android.data.sportType

@Composable
fun LiveWorkout(
    plan: WorkoutPlan,
    log: MutableList<LoggedExercise>,
    onBack: () -> Unit,
    onSaved: () -> Unit
) {
    var addName by remember { mutableStateOf("") }
    var showNotes by remember { mutableStateOf(setOf<String>()) }
    var saved by remember { mutableStateOf(false) }
    var sessDurationSec by remember { mutableStateOf<Int?>(null) }
    var sessAvgHR by remember { mutableStateOf("") }
    var sessCalManual by remember { mutableStateOf("") }
    var confirmDiscard by remember { mutableStateOf(false) }
    
    // Live timer
    var now by remember { mutableStateOf(System.currentTimeMillis()) }

    Column(modifier = Modifier.fillMaxSize()) {
        BackRow(plan = plan, onBack = onBack)
        
        LiveTimerBlock(elapsedSec = 0) // Compute from start date
        
        LazyColumn(modifier = Modifier.weight(1f)) {
            items(log) { ex ->
                ExerciseCard(
                    exercise = ex,
                    onAddSet = { /* ... */ },
                    onDeleteSet = { /* ... */ },
                    onNotesToggle = { /* ... */ }
                )
            }
            
            item {
                AddExerciseCard(
                    addName = addName,
                    onNameChange = { addName = it },
                    onAdd = { /* Add exercise logic */ }
                )
            }
            
            item {
                SessionLoadCard(
                    durationSec = sessDurationSec,
                    onDurationChange = { sessDurationSec = it },
                    avgHR = sessAvgHR,
                    onAvgHRChange = { sessAvgHR = it }
                )
            }
            
            item {
                CaloriesCard(
                    manualCal = sessCalManual,
                    onManualCalChange = { sessCalManual = it },
                    estCalories = 0 // Compute est
                )
            }
            
            item {
                Button(
                    onClick = { 
                        saved = true
                        onSaved()
                    },
                    modifier = Modifier.fillMaxWidth().padding(16.dp)
                ) {
                    Text(if (saved) "Saved" else "Finish Session")
                }
                
                OutlinedButton(
                    onClick = { confirmDiscard = true },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                ) {
                    Text("Discard Session", color = MaterialTheme.colorScheme.error)
                }
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

@Composable
fun BackRow(plan: WorkoutPlan, onBack: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        TextButton(onClick = onBack) {
            Text("↓ Minimize")
        }
        Column {
            Text(text = plan.name, style = MaterialTheme.typography.titleLarge)
            Text(text = plan.sub, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun LiveTimerBlock(elapsedSec: Int) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Row(modifier = Modifier.padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("WORKOUT LIVE")
            Text("00:00") // Format elapsedSec
        }
    }
}

@Composable
fun ExerciseCard(exercise: LoggedExercise, onAddSet: () -> Unit, onDeleteSet: () -> Unit, onNotesToggle: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(exercise.name, style = MaterialTheme.typography.titleMedium)
            // Sets row iteration...
            Row {
                Button(onClick = onAddSet) { Text("Add Set") }
                Button(onClick = onNotesToggle) { Text("Notes") }
            }
        }
    }
}

@Composable
fun AddExerciseCard(addName: String, onNameChange: (String) -> Unit, onAdd: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Row(modifier = Modifier.padding(16.dp)) {
            OutlinedTextField(
                value = addName,
                onValueChange = onNameChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("Add exercise") }
            )
            IconButton(onClick = onAdd) {
                Text("+") // Use icon
            }
        }
    }
}

@Composable
fun SessionLoadCard(durationSec: Int?, onDurationChange: (Int?) -> Unit, avgHR: String, onAvgHRChange: (String) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Internal Load")
            // HMSField equivalent
            OutlinedTextField(value = avgHR, onValueChange = onAvgHRChange, label = { Text("Avg HR") })
        }
    }
}

@Composable
fun CaloriesCard(manualCal: String, onManualCalChange: (String) -> Unit, estCalories: Int) {
    Card(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Calories")
            OutlinedTextField(value = manualCal, onValueChange = onManualCalChange, label = { Text("Override Cal") })
        }
    }
}

