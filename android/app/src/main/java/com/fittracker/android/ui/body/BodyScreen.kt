package com.fittracker.android.ui.body

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.viewmodel.BodyViewModel
import com.fittracker.android.viewmodel.ToastCenter

@Composable
fun BodyScreen(viewModel: BodyViewModel, toast: ToastCenter) {
    var weightInput by remember { mutableStateOf("") }
    var bfInput by remember { mutableStateOf("") }
    var stepsInput by remember { mutableStateOf("") }
    var showManualSleep by remember { mutableStateOf(false) }
    var day by remember { mutableStateOf("today") } // use actual date representations

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(11.dp),
        contentPadding = PaddingValues(16.dp)
    ) {
        item {
            DaySelector(
                day = day,
                onPrevious = { /* logic */ },
                onNext = { /* logic */ },
                onHistory = { /* open history */ }
            )
        }
        
        item {
            CheckInCard(
                day = day,
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
                showManual = showManualSleep,
                onToggleManual = { showManualSleep = it }
            )
        }
        
        item {
            StepsCard(
                stepsInput = stepsInput,
                onStepsChange = { stepsInput = it },
                onSave = { viewModel.saveSteps(stepsInput) }
            )
        }
        
        item {
            AnalysisCard(
                bfInput = bfInput,
                onBfChange = { bfInput = it },
                onSave = { viewModel.saveBf(bfInput) }
            )
        }
        
        item {
            MeasurementsCard()
        }
        
        item {
            ChartsSection()
        }
        
        item {
            BackupCard()
        }
    }
}

@Composable
fun DaySelector(day: String, onPrevious: () -> Unit, onNext: () -> Unit, onHistory: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            IconButton(onClick = onPrevious) { Text("<") }
            Text(day, style = MaterialTheme.typography.titleMedium)
            IconButton(onClick = onNext) { Text(">") }
            IconButton(onClick = onHistory) { Text("H") } // History icon
        }
    }
}

@Composable
fun CheckInCard(day: String, weightInput: String, onWeightChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Check-in - $day", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = weightInput,
                onValueChange = onWeightChange,
                label = { Text("Weight") },
                modifier = Modifier.fillMaxWidth()
            )
            Button(onClick = onSave, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("Save")
            }
        }
    }
}

@Composable
fun SleepCard(showManual: Boolean, onToggleManual: (Boolean) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Sleep", style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = { onToggleManual(!showManual) }) {
                    Text(if (showManual) "Hide" else "Manual")
                }
            }
            // Stats Tiles...
            if (showManual) {
                // Manual entry forms
                Text("Manual entry form goes here")
            }
        }
    }
}

@Composable
fun StepsCard(stepsInput: String, onStepsChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Steps", style = MaterialTheme.typography.titleMedium)
            Row {
                OutlinedTextField(
                    value = stepsInput,
                    onValueChange = onStepsChange,
                    modifier = Modifier.weight(1f)
                )
                Button(onClick = onSave) { Text("Save") }
            }
        }
    }
}

@Composable
fun AnalysisCard(bfInput: String, onBfChange: (String) -> Unit, onSave: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Analysis", style = MaterialTheme.typography.titleMedium)
            // StatTiles...
            Row {
                OutlinedTextField(
                    value = bfInput,
                    onValueChange = onBfChange,
                    label = { Text("Body Fat %") },
                    modifier = Modifier.weight(1f)
                )
                Button(onClick = onSave) { Text("Save") }
            }
        }
    }
}

@Composable fun MeasurementsCard() {
    Card(modifier = Modifier.fillMaxWidth()) {
        Text("Measurements", modifier = Modifier.padding(16.dp))
    }
}

@Composable fun ChartsSection() {}
@Composable fun BackupCard() {}
