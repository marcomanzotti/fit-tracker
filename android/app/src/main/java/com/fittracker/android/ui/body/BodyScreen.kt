package com.fittracker.android.ui.body

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.value
import com.fittracker.android.utils.Helpers.today
import com.fittracker.android.utils.Helpers.trimNum
import com.fittracker.android.viewmodel.BodyViewModel
import com.fittracker.android.viewmodel.ToastCenter

// Kotlin port of the non-HealthKit parts of ios/FitTracker/Views/BodyView.swift:
// weight check-in, manual sleep, steps, body-fat analysis, tape measurements,
// and a simple recent-trend list (full charts live in the Stats tab).
@Composable
fun BodyScreen(viewModel: BodyViewModel, toast: ToastCenter) {
    var weightInput by remember { mutableStateOf("") }
    var bfInput by remember { mutableStateOf("") }
    var stepsInput by remember { mutableStateOf("") }
    var showManualSleep by remember { mutableStateOf(false) }
    var sleepHours by remember { mutableStateOf("") }
    var sleepScore by remember { mutableStateOf("") }

    val daily by viewModel.daily.collectAsState()
    val body by viewModel.body.collectAsState()
    val prefs by viewModel.prefs.collectAsState()

    val todayEntry = remember(daily) { daily.firstOrNull { it.date == today() } }
    val lastWeight = remember(daily) { daily.sortedBy { it.date }.lastOrNull { it.weight != null }?.weight ?: prefs.startWeight }
    val bodyLatest = remember(body) { body.sortedByDescending { it.date }.firstOrNull() }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(11.dp),
        contentPadding = PaddingValues(16.dp)
    ) {
        item {
            CheckInCard(
                lastWeight = lastWeight,
                goalWeight = prefs.goalWeight,
                weightInput = weightInput,
                onWeightChange = { weightInput = it },
                onSave = {
                    viewModel.saveCheckIn(weightInput)
                    weightInput = ""
                    toast.show("Check-in saved")
                }
            )
        }

        item {
            SleepCard(
                sleepHours = todayEntry?.sleepHours,
                sleepScore = todayEntry?.sleep,
                showManual = showManualSleep,
                onToggleManual = { showManualSleep = !showManualSleep },
                hoursInput = sleepHours,
                onHoursChange = { sleepHours = it },
                scoreInput = sleepScore,
                onScoreChange = { sleepScore = it },
                onSave = {
                    viewModel.saveManualSleep(sleepHours, sleepScore)
                    sleepHours = ""; sleepScore = ""
                    showManualSleep = false
                    toast.show("Sleep saved")
                }
            )
        }

        item {
            StepsCard(
                currentSteps = todayEntry?.steps,
                stepsInput = stepsInput,
                onStepsChange = { stepsInput = it },
                onSave = {
                    viewModel.saveSteps(stepsInput)
                    stepsInput = ""
                    toast.show("Steps saved")
                }
            )
        }

        item {
            AnalysisCard(
                currentBF = bodyLatest?.bfManual,
                bfInput = bfInput,
                onBfChange = { bfInput = it },
                onSave = {
                    viewModel.saveBf(bfInput)
                    bfInput = ""
                    toast.show("Body fat saved")
                }
            )
        }

        item {
            MeasurementsCard(
                latest = bodyLatest,
                onSave = { values ->
                    viewModel.saveMeasurements(values)
                    toast.show("Measurements saved")
                }
            )
        }

        item {
            TrendCard(entries = daily.filter { it.weight != null }.sortedByDescending { it.date }.take(10))
        }
    }
}

@Composable
fun CheckInCard(lastWeight: Double, goalWeight: Double, weightInput: String, onWeightChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Check-in", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text("Last: ${trimNum(lastWeight)} kg", style = MaterialTheme.typography.bodySmall)
                Text("Goal: ${trimNum(goalWeight)} kg", style = MaterialTheme.typography.bodySmall)
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                OutlinedTextField(
                    value = weightInput,
                    onValueChange = onWeightChange,
                    label = { Text("Weight (kg)") },
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                Button(onClick = onSave) { Text("Save") }
            }
        }
    }
}

@Composable
fun SleepCard(
    sleepHours: Double?,
    sleepScore: Int?,
    showManual: Boolean,
    onToggleManual: () -> Unit,
    hoursInput: String,
    onHoursChange: (String) -> Unit,
    scoreInput: String,
    onScoreChange: (String) -> Unit,
    onSave: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Sleep", style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = onToggleManual) { Text(if (showManual) "Hide" else "Manual") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(top = 4.dp)) {
                Text(sleepHours?.let { "${trimNum(it)}h" } ?: "—h", style = MaterialTheme.typography.bodyMedium)
                Text(sleepScore?.let { "score $it" } ?: "no score", style = MaterialTheme.typography.bodyMedium)
            }
            if (showManual) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                    OutlinedTextField(value = hoursInput, onValueChange = onHoursChange, label = { Text("Hours") }, modifier = Modifier.weight(1f))
                    Spacer(Modifier.width(8.dp))
                    OutlinedTextField(value = scoreInput, onValueChange = onScoreChange, label = { Text("Score") }, modifier = Modifier.weight(1f))
                }
                Button(onClick = onSave, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text("Save") }
            }
        }
    }
}

@Composable
fun StepsCard(currentSteps: Int?, stepsInput: String, onStepsChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Steps today: ${currentSteps ?: 0}", style = MaterialTheme.typography.titleMedium)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                OutlinedTextField(
                    value = stepsInput,
                    onValueChange = onStepsChange,
                    label = { Text("Steps") },
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                Button(onClick = onSave) { Text("Save") }
            }
        }
    }
}

@Composable
fun AnalysisCard(currentBF: Double?, bfInput: String, onBfChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Body fat: ${currentBF?.let { "${trimNum(it)}%" } ?: "—"}", style = MaterialTheme.typography.titleMedium)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                OutlinedTextField(
                    value = bfInput,
                    onValueChange = onBfChange,
                    label = { Text("Body Fat %") },
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                Button(onClick = onSave) { Text("Save") }
            }
        }
    }
}

private val measureKeys = listOf("waist", "chest", "arms", "legs", "neck", "hips")

@Composable
fun MeasurementsCard(latest: com.fittracker.android.data.BodyEntry?, onSave: (Map<String, String>) -> Unit) {
    val inputs = remember { mutableStateMapOf<String, String>() }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Measurements (cm)", style = MaterialTheme.typography.titleMedium)
            measureKeys.chunked(2).forEach { pair ->
                Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEach { key ->
                        val current = latest?.value(key)
                        OutlinedTextField(
                            value = inputs[key] ?: "",
                            onValueChange = { inputs[key] = it },
                            label = { Text(key.replaceFirstChar { c -> c.uppercase() } + (current?.let { " (${trimNum(it)})" } ?: "")) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
            Button(
                onClick = { onSave(inputs.toMap()); inputs.clear() },
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
            ) { Text("Save measurements") }
        }
    }
}

@Composable
fun TrendCard(entries: List<com.fittracker.android.data.DailyEntry>) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Recent weigh-ins", style = MaterialTheme.typography.titleMedium)
            if (entries.isEmpty()) {
                Text("No entries yet", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
            } else {
                entries.forEach { e ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(e.date, style = MaterialTheme.typography.bodySmall)
                        Text("${trimNum(e.weight ?: 0.0)} kg", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}
