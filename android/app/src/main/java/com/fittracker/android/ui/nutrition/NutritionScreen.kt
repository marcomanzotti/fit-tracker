package com.fittracker.android.ui.nutrition

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.viewmodel.StoreViewModel

@Composable
fun NutritionScreen(viewModel: StoreViewModel) {
    var editingToday by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(11.dp),
        contentPadding = PaddingValues(16.dp)
    ) {
        item {
            TargetCard(viewModel = viewModel)
        }
        item {
            TodayCard(
                viewModel = viewModel,
                onEditToday = { editingToday = true }
            )
        }
        item {
            NutritionCalendarCard()
        }
        item {
            NutritionChartsSection()
        }
        item {
            FoodDatabaseCard(viewModel = viewModel)
        }
    }

    if (editingToday) {
        // Show NutritionDayEditor
    }
}

@Composable
fun TargetCard(viewModel: StoreViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("TARGET", style = MaterialTheme.typography.labelMedium)
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("2500 kcal", style = MaterialTheme.typography.displayMedium)
                Text("TDEE 2400 - BMR 1800", style = MaterialTheme.typography.bodySmall)
            }
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("P 180g")
                Text("C 250g")
                Text("F 70g")
            }
        }
    }
}

@Composable
fun TodayCard(viewModel: StoreViewModel, onEditToday: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("TODAY", style = MaterialTheme.typography.labelMedium)
            Text("1500 / 2500 kcal", style = MaterialTheme.typography.headlineMedium)
            
            LinearProgressIndicator(progress = { 0.6f }, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp))
            
            Button(onClick = onEditToday, modifier = Modifier.fillMaxWidth()) {
                Text("Log / Edit Today")
            }
        }
    }
}

@Composable
fun FoodDatabaseCard(viewModel: StoreViewModel) {
    var showScan by remember { mutableStateOf(false) }
    var showNew by remember { mutableStateOf(false) }
    
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("MY FOODS", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 8.dp)) {
                Button(onClick = { showScan = true }, modifier = Modifier.weight(1f)) {
                    Text("Scan")
                }
                OutlinedButton(onClick = { showNew = true }, modifier = Modifier.weight(1f)) {
                    Text("New")
                }
            }
            // List of recent foods
            Text("Food list goes here...")
        }
    }
}

@Composable fun NutritionCalendarCard() {}
@Composable fun NutritionChartsSection() {}
