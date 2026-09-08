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
import com.fittracker.android.data.PlanExercise
import com.fittracker.android.data.WorkoutPlan
import com.fittracker.android.data.exKind

// Kotlin port of ios/FitTracker/Views/PlanEditorView.swift. Fixes the
// pre-existing bug where local `name`/`sub`/`exercises` edits never made it
// back to the caller: onSave now hands back the fully-edited WorkoutPlan
// instead of a bare Unit signal, and the caller commits *that* plan (not the
// stale `editingPlan` it opened the editor with).
@Composable
fun PlanEditor(
    plan: WorkoutPlan,
    isNew: Boolean,
    onSave: (WorkoutPlan) -> Unit,
    onDelete: () -> Unit,
    onCancel: () -> Unit
) {
    var name by remember { mutableStateOf(plan.name) }
    var sub by remember { mutableStateOf(plan.sub) }
    var confirmDelete by remember { mutableStateOf(false) }

    val exercises = remember { mutableStateListOf(*plan.exercises.toTypedArray()) }

    fun buildPlan(): WorkoutPlan = plan.copy(
        name = name.trim().ifEmpty { plan.name },
        sub = sub,
        exercises = exercises.toList()
    )

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(onClick = onCancel) { Text("← Cancel") }
            Text(if (isNew) "NEW DAY" else "EDIT DAY", style = MaterialTheme.typography.titleLarge)
            Spacer(modifier = Modifier.width(64.dp))
        }

        LazyColumn(modifier = Modifier.weight(1f).padding(horizontal = 16.dp)) {
            item {
                Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                    }
                }
            }

            item {
                Text("Exercises (${exercises.size})", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
            }

            items(exercises, key = { it.id }) { ex ->
                ExerciseEditRow(
                    exercise = ex,
                    onChange = { updated ->
                        val i = exercises.indexOfFirst { it.id == ex.id }
                        if (i >= 0) exercises[i] = updated
                    },
                    onDelete = { exercises.removeAll { it.id == ex.id } }
                )
            }

            item {
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { exercises.add(PlanExercise(name = "New exercise")) },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("+ Add exercise") }
                }
            }

            item {
                Button(onClick = { onSave(buildPlan()) }, modifier = Modifier.fillMaxWidth()) {
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
                Spacer(modifier = Modifier.height(24.dp))
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
}

@Composable
fun ExerciseEditRow(exercise: PlanExercise, onChange: (PlanExercise) -> Unit, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = exercise.name,
                    onValueChange = { onChange(exercise.copy(name = it)) },
                    label = { Text("Exercise name") },
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onDelete) {
                    Icon(Icons.Filled.Close, contentDescription = "Delete exercise")
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ExKind.entries.forEach { k ->
                    val active = exercise.exKind == k
                    FilterChip(
                        selected = active,
                        onClick = { onChange(exercise.copy(kind = k.raw)) },
                        label = { Text(k.raw) }
                    )
                }
            }

            when (exercise.exKind) {
                ExKind.REPS -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = exercise.sets.toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(sets = it)) } },
                            label = { Text("Sets") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = exercise.reps,
                            onValueChange = { onChange(exercise.copy(reps = it)) },
                            label = { Text("Reps") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                ExKind.TIMED -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = exercise.sets.toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(sets = it)) } },
                            label = { Text("Sets") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = (exercise.targetSec ?: 0).toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(targetSec = it)) } },
                            label = { Text("Hold (s)") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                ExKind.INTERVAL -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = (exercise.rounds ?: 1).toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(rounds = it)) } },
                            label = { Text("Rounds") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = (exercise.workSec ?: 0).toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(workSec = it)) } },
                            label = { Text("Work (s)") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = (exercise.restSec ?: 0).toString(),
                            onValueChange = { v -> v.toIntOrNull()?.let { onChange(exercise.copy(restSec = it)) } },
                            label = { Text("Rest (s)") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}
