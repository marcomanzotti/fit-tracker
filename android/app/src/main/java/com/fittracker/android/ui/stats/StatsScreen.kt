package com.fittracker.android.ui.stats

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.viewmodel.StatsViewModel

@Composable
fun StatsScreen(viewModel: StatsViewModel) {
    var selectedTab by remember { mutableStateOf("overview") }
    val tabs = listOf("overview" to "OVERVIEW", "pr" to "RECORDS", "prog" to "PROGRESS", "storico" to "HISTORY")

    Column(modifier = Modifier.fillMaxSize()) {
        ScrollableTabRow(
            selectedTabIndex = tabs.indexOfFirst { it.first == selectedTab },
            modifier = Modifier.fillMaxWidth()
        ) {
            tabs.forEachIndexed { index, tab ->
                Tab(
                    selected = selectedTab == tab.first,
                    onClick = { selectedTab = tab.first },
                    text = { Text(tab.second) }
                )
            }
        }

        when (selectedTab) {
            "overview" -> OverviewTab()
            "pr" -> RecordsTab()
            "prog" -> ProgressTab()
            "storico" -> HistoryTab()
        }
    }
}

@Composable
fun OverviewTab() {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item { MetricChartCard("Weight") }
        item { MetricChartCard("Sleep") }
        item { MetricChartCard("Steps") }
        item { MetricChartCard("VO2 Max") }
        item { ProfileCard() }
    }
}

@Composable
fun RecordsTab() {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("PR FEED", style = MaterialTheme.typography.titleMedium)
                    Text("PR Feed List...")
                }
            }
        }
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("CURRENT MAXES", style = MaterialTheme.typography.titleMedium)
                    Text("Maxes List...")
                }
            }
        }
    }
}

@Composable
fun ProgressTab() {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Select Exercise", style = MaterialTheme.typography.titleMedium)
                    OutlinedTextField(value = "", onValueChange = {}, label = { Text("Search") }, modifier = Modifier.fillMaxWidth())
                    Text("Exercise List...", modifier = Modifier.padding(top = 8.dp))
                }
            }
        }
    }
}

@Composable
fun HistoryTab() {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
        item {
            Text("WORKOUTS", style = MaterialTheme.typography.titleMedium)
            Text("Workout Calendar...")
        }
        item {
            Text("NUTRITION", style = MaterialTheme.typography.titleMedium)
            Text("Nutrition Calendar...")
        }
    }
}

@Composable
fun MetricChartCard(title: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text("Chart Placeholder", modifier = Modifier.height(100.dp).padding(top = 8.dp))
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
