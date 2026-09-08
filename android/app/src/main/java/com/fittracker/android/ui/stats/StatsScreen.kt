package com.fittracker.android.ui.stats

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.Store
import com.fittracker.android.data.exKind
import com.fittracker.android.science.PREvent
import com.fittracker.android.science.bestE1RM
import com.fittracker.android.science.e1RMSeries
import com.fittracker.android.science.prTimeline
import com.fittracker.android.utils.Helpers.trimNum
import com.fittracker.android.viewmodel.StatsViewModel

// Kotlin port of the non-HealthKit parts of ios/FitTracker/Views/StatsView.swift +
// MetricChartCard.swift. Chart rendering: NOTE — this deliberately uses a small
// hand-rolled Canvas line chart instead of the Vico charting library. Vico
// 2.1.3's Compose API surface (ModelProducer/CartesianChart wiring) changed a
// lot across major versions and couldn't be verified without a local
// SDK/Gradle build to compile-check against, so per the task brief this falls
// back to a "clearly-labeled simple Canvas-drawn chart" rather than guessing
// an API that might not compile. Swapping this for real Vico charts is the
// next thing to verify once a CI build confirms the rest compiles.
@Composable
fun StatsScreen(viewModel: StatsViewModel) {
    var selectedTab by remember { mutableStateOf("overview") }
    val tabs = listOf("overview" to "OVERVIEW", "pr" to "RECORDS", "prog" to "PROGRESS", "storico" to "HISTORY")

    Column(modifier = Modifier.fillMaxSize()) {
        ScrollableTabRow(
            selectedTabIndex = tabs.indexOfFirst { it.first == selectedTab },
            modifier = Modifier.fillMaxWidth()
        ) {
            tabs.forEachIndexed { _, tab ->
                Tab(
                    selected = selectedTab == tab.first,
                    onClick = { selectedTab = tab.first },
                    text = { Text(tab.second) }
                )
            }
        }

        when (selectedTab) {
            "overview" -> OverviewTab(viewModel)
            "pr" -> RecordsTab(viewModel)
            "prog" -> ProgressTab(viewModel)
            "storico" -> HistoryTab(viewModel)
        }
    }
}

@Composable
fun OverviewTab(viewModel: StatsViewModel) {
    val daily by viewModel.store.daily.collectAsState()
    val weightSeries = remember(daily) { viewModel.store.metricSeries({ it.weight }, Store.ChartGranularity.WEEK) }
    val sleepSeries = remember(daily) { viewModel.store.metricSeries({ it.sleep?.toDouble() }, Store.ChartGranularity.WEEK) }
    val stepsSeries = remember(daily) { viewModel.store.metricSeries({ it.steps?.toDouble() }, Store.ChartGranularity.WEEK) }
    val vo2Series = remember(daily) { viewModel.store.metricSeries({ it.vo2max }, Store.ChartGranularity.MONTH) }

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item { MetricChartCard("Weight (kg)", weightSeries.map { it.value }) }
        item { MetricChartCard("Sleep score", sleepSeries.map { it.value }) }
        item { MetricChartCard("Steps", stepsSeries.map { it.value }) }
        item { MetricChartCard("VO2 Max", vo2Series.map { it.value }) }
    }
}

@Composable
fun RecordsTab(viewModel: StatsViewModel) {
    val sessions by viewModel.store.sessions.collectAsState()
    val prs = remember(sessions) { viewModel.store.prTimeline(30) }
    val maxes = remember(sessions) {
        sessions.flatMap { it.exercises }
            .filter { it.exKind == com.fittracker.android.data.ExKind.REPS }
            .map { it.name }
            .distinct()
            .mapNotNull { name -> viewModel.store.bestE1RM(name)?.let { name to it } }
            .sortedByDescending { it.second }
    }

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("PR FEED", style = MaterialTheme.typography.titleMedium)
                    if (prs.isEmpty()) {
                        Text("No records yet. Log some sets with weight.", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
                    } else {
                        prs.take(20).forEach { pr -> PRRow(pr) }
                    }
                }
            }
        }
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("CURRENT MAXES", style = MaterialTheme.typography.titleMedium)
                    if (maxes.isEmpty()) {
                        Text("No maxes yet", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
                    } else {
                        maxes.forEach { (name, e1) ->
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(name, style = MaterialTheme.typography.bodyMedium)
                                Text("${trimNum(e1)} kg e1RM", style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PRRow(pr: PREvent) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column {
            Text(pr.exercise, style = MaterialTheme.typography.bodyMedium)
            Text(pr.date, style = MaterialTheme.typography.bodySmall)
        }
        Text("${trimNum(pr.value)}${pr.unit}", style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
fun ProgressTab(viewModel: StatsViewModel) {
    val sessions by viewModel.store.sessions.collectAsState()
    var search by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf<String?>(null) }

    val names = remember(sessions) {
        sessions.flatMap { it.exercises }.map { it.name }.distinct().sorted()
            .filter { search.isEmpty() || it.contains(search, ignoreCase = true) }
    }

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Select Exercise", style = MaterialTheme.typography.titleMedium)
                    OutlinedTextField(
                        value = search,
                        onValueChange = { search = it },
                        label = { Text("Search") },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    )
                }
            }
        }
        items(names) { name ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                onClick = { selected = name }
            ) {
                Text(name, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium)
            }
        }
        selected?.let { name ->
            item {
                val series = remember(name, sessions) { viewModel.store.e1RMSeries(name) }
                MetricChartCard("$name — e1RM", series.map { it.value })
            }
        }
    }
}

@Composable
fun HistoryTab(viewModel: StatsViewModel) {
    val sessions by viewModel.store.sessions.collectAsState()
    val daily by viewModel.store.daily.collectAsState()
    val recentSessions = remember(sessions) { sessions.sortedByDescending { it.date }.take(20) }
    val recentNutrition = remember(daily) { daily.filter { (it.kcal ?: 0) > 0 || !it.meals.isNullOrEmpty() || !it.foods.isNullOrEmpty() }.sortedByDescending { it.date }.take(20) }

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item { Text("WORKOUTS", style = MaterialTheme.typography.titleMedium) }
        items(recentSessions) { s ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.padding(12.dp).fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(s.planName, style = MaterialTheme.typography.bodyMedium)
                    Text(s.date, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item { Spacer(Modifier.height(8.dp)); Text("NUTRITION", style = MaterialTheme.typography.titleMedium) }
        items(recentNutrition) { e ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.padding(12.dp).fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(e.date, style = MaterialTheme.typography.bodySmall)
                    Text("${e.kcal ?: 0} kcal", style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

/** A small labeled line chart card. Draws with plain Canvas (see the file-level
 * note on Vico) — normalizes [values] to the card's height and connects them
 * with straight segments; min/max are annotated as text. */
@Composable
fun MetricChartCard(title: String, values: List<Double> = emptyList()) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            if (values.size < 2) {
                Text(
                    if (values.isEmpty()) "No data yet" else "${trimNum(values.first())}",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 8.dp)
                )
            } else {
                val lineColor = MaterialTheme.colorScheme.primary
                Canvas(modifier = Modifier.fillMaxWidth().height(100.dp).padding(top = 8.dp)) {
                    val min = values.min()
                    val max = values.max()
                    val range = (max - min).takeIf { it > 0.0001 } ?: 1.0
                    val stepX = size.width / (values.size - 1)
                    val path = androidx.compose.ui.graphics.Path()
                    values.forEachIndexed { i, v ->
                        val x = i * stepX
                        val y = size.height - ((v - min) / range * size.height).toFloat()
                        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                    }
                    drawPath(path, color = lineColor, style = Stroke(width = 4f))
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("min ${trimNum(values.min())}", style = MaterialTheme.typography.bodySmall)
                    Text("max ${trimNum(values.max())}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
fun ProfileCard() {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("PROFILE & GOALS", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                OutlinedTextField(value = "", onValueChange = {}, label = { Text("Goal Weight") }, modifier = Modifier.weight(1f))
                OutlinedTextField(value = "", onValueChange = {}, label = { Text("Goal BF%") }, modifier = Modifier.weight(1f))
            }
            Button(onClick = {}, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("Save")
            }
        }
    }
}
