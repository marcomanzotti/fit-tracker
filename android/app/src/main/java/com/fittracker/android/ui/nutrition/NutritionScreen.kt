package com.fittracker.android.ui.nutrition

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.fittracker.android.data.FoodItem
import com.fittracker.android.data.totalCarbs
import com.fittracker.android.data.totalFat
import com.fittracker.android.data.totalKcal
import com.fittracker.android.data.totalProtein
import com.fittracker.android.data.unit
import com.fittracker.android.localization.L
import com.fittracker.android.utils.Helpers.today
import com.fittracker.android.utils.Helpers.trimNum
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
            FoodDatabaseCard(viewModel = viewModel)
        }
    }

    if (editingToday) {
        NutritionDayEditor(viewModel = viewModel, onDismiss = { editingToday = false })
    }
}

@Composable
fun TargetCard(viewModel: StoreViewModel) {
    val prefs by viewModel.prefs.collectAsState()
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(L.t("nut.target").uppercase(), style = MaterialTheme.typography.labelMedium)
            Text("${(prefs.goalWeight * 30).toInt()} kcal", style = MaterialTheme.typography.displayMedium)
        }
    }
}

@Composable
fun TodayCard(viewModel: StoreViewModel, onEditToday: () -> Unit) {
    val daily by viewModel.daily.collectAsState()
    val entry = remember(daily) { daily.firstOrNull { it.date == today() } }
    val kcal = entry?.totalKcal ?: 0
    val protein = entry?.totalProtein ?: 0.0
    val carbs = entry?.totalCarbs ?: 0.0
    val fat = entry?.totalFat ?: 0.0

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(L.t("nut.today").uppercase(), style = MaterialTheme.typography.labelMedium)
            Text("$kcal kcal", style = MaterialTheme.typography.headlineMedium)
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
                Text("P ${trimNum(protein)}g")
                Text("C ${trimNum(carbs)}g")
                Text("F ${trimNum(fat)}g")
            }
            Button(onClick = onEditToday, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text(L.t("nut.log_edit_today"))
            }
        }
    }
}

/** Full-screen editor for today's food log — the day-level list of [FoodLog]s,
 * mirroring the "day editor" sheet reachable from the iOS NutritionScreen's
 * TodayCard. Backed by Store.saveDayFoods. */
@Composable
fun NutritionDayEditor(viewModel: StoreViewModel, onDismiss: () -> Unit) {
    val date = remember { today() }
    val daily by viewModel.daily.collectAsState()
    val entry = remember(daily) { daily.firstOrNull { it.date == date } }
    var logs by remember(entry) { mutableStateOf(entry?.foods ?: emptyList()) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(L.t("nut.today"), style = MaterialTheme.typography.headlineSmall)
                    IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
                }
                Spacer(Modifier.height(12.dp))
                FoodLogSection(
                    viewModel = viewModel,
                    logs = logs,
                    onLogsChange = { newLogs ->
                        logs = newLogs
                        viewModel.saveDayFoods(date, newLogs)
                    }
                )
            }
        }
    }
}

@Composable
fun FoodDatabaseCard(viewModel: StoreViewModel) {
    var showNew by remember { mutableStateOf(false) }
    var editingFood by remember { mutableStateOf<FoodItem?>(null) }
    val foods by viewModel.foods.collectAsState()
    val recent = remember(foods) { viewModel.recentFoods().take(8) }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(L.t("nut.my_foods").uppercase(), style = MaterialTheme.typography.titleMedium)
            OutlinedButton(
                onClick = { showNew = true },
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
            ) { Text(L.t("nut.new_food")) }

            if (recent.isEmpty()) {
                Text(L.t("food.none"), style = MaterialTheme.typography.bodySmall)
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    recent.forEach { f ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(f.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                                Text(
                                    "${trimNum(f.k100)} kcal /100${f.unit}",
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                            TextButton(onClick = { editingFood = f }) { Text(L.t("edit")) }
                        }
                    }
                }
            }
        }
    }

    if (showNew) {
        FoodFormSheet(
            food = FoodItem(name = ""),
            onSave = { viewModel.saveFood(it); showNew = false },
            onDelete = { showNew = false },
            onDismiss = { showNew = false }
        )
    }
    editingFood?.let { food ->
        FoodFormSheet(
            food = food,
            onSave = { viewModel.saveFood(it); editingFood = null },
            onDelete = { viewModel.deleteFood(it); editingFood = null },
            onDismiss = { editingFood = null }
        )
    }
}
