package com.fittracker.android.ui.train

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.PlanExercise
import com.fittracker.android.data.WorkoutPlan

@Composable
fun PlanEditor(
    plan: WorkoutPlan,
    isNew: Boolean,
    onSave: () -> Unit,
    onDelete: () -> Unit,
    onCancel: () -> Unit
) {
    var name by remember { mutableStateOf(plan.name) }
    var sub by remember { mutableStateOf(plan.sub) }
    var confirmDelete by remember { mutableStateOf(false) }
    var browsing by remember { mutableStateOf(false) }
    
    // Convert to mutable state list for UI driving
    val exercises = remember { mutableStateListOf(*plan.exercises.toTypedArray()) }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            TextButton(onClick = onCancel) {
                Text("← Cancel")
            }
            Text(if (isNew) "NEW DAY" else "EDIT DAY", style = MaterialTheme.typography.titleLarge)
        }

        LazyColumn(modifier = Modifier.weight(1f).padding(horizontal = 16.dp)) {
            item {
                Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it },
                            label = { Text("Day Name") },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = sub,
                            onValueChange = { sub = it },
                            label = { Text("Subtitle") },
                            modifier = Modifier.fillMaxWidth()
                        )
                        // Color picker would go here
                    }
                }
            }

            item {
                Text("Exercises (${exercises.size})", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
            }

            items(exercises) { ex ->
                ExerciseEditRow(
                    exercise = ex,
                    onDelete = { exercises.remove(ex) }
                )
            }

            item {
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { browsing = true }, modifier = Modifier.weight(1f)) {
                        Text("Browse")
                    }
                    OutlinedButton(onClick = { exercises.add(PlanExercise(name = "")) }, modifier = Modifier.weight(1f)) {
                        Text("Blank")
                    }
                }
            }

            item {
                Button(onClick = onSave, modifier = Modifier.fillMaxWidth()) {
                    Text(if (isNew) "Create Day" else "Save Changes")
                }
                if (!isNew) {
                    OutlinedButton(
                        onClick = { confirmDelete = true },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) {
                        Text("Delete Day", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete Day?") },
            text = { Text("Are you sure you want to delete this plan?") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    onDelete()
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (browsing) {
        // ExercisePickerSheet equivalent
    }
}

@Composable
fun ExerciseEditRow(exercise: PlanExercise, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row {
                // ExerciseNameField equivalent
                Text("Exercise Name Field", modifier = Modifier.weight(1f))
                IconButton(onClick = onDelete) {
                    Text("X") // Replace with Icon
                }
            }
            // Kind selector, params row, rest row...
        }
    }
}
