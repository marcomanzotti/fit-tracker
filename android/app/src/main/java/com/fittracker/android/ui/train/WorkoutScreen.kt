package com.fittracker.android.ui.train

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.CardioType
import com.fittracker.android.data.WorkoutPlan
import com.fittracker.android.data.WorkoutSession
import com.fittracker.android.data.sportType
import com.fittracker.android.viewmodel.ActiveCardioViewModel
import com.fittracker.android.viewmodel.ActiveWorkoutViewModel
import com.fittracker.android.viewmodel.StoreViewModel
import com.fittracker.android.viewmodel.ToastCenter

@Composable
fun WorkoutScreen(
    viewModel: StoreViewModel,
    activeWorkout: ActiveWorkoutViewModel,
    activeCardio: ActiveCardioViewModel,
    toast: ToastCenter
) {
    var editingPlan by remember { mutableStateOf<WorkoutPlan?>(null) }
    var isNew by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<WorkoutSession?>(null) }
    var loggingCardio by remember { mutableStateOf<CardioType?>(null) }
    var editingCardio by remember { mutableStateOf<CardioType?>(null) }
    var isNewCardio by remember { mutableStateOf(false) }
    
    var sessionQuery by remember { mutableStateOf("") }
    var showAllSessions by remember { mutableStateOf(false) }

    when {
        activeWorkout.planId != null && !activeWorkout.minimized -> {
            val plan = activeWorkout.planId?.let { viewModel.plan(it) }
            if (plan != null) {
                LiveWorkout(
                    viewModel = viewModel,
                    plan = plan,
                    log = activeWorkout.log,
                    onBack = { activeWorkout.minimized = true },
                    onSaved = {
                        activeWorkout.end()
                    }
                )
            }
        }
        activeCardio.typeId != null && !activeCardio.minimized -> {
            val type = activeCardio.typeId?.let { viewModel.cardioType(it) }
            if (type != null) {
                LiveCardioView(
                    type = type,
                    onBack = { activeCardio.minimized = true },
                    onSaved = { activeCardio.end() }
                )
            }
        }
        editingPlan != null -> {
            PlanEditor(
                plan = editingPlan!!,
                isNew = isNew,
                onSave = { edited ->
                    viewModel.commitPlan(edited, isNew)
                    editingPlan = null
                    toast.show(if (isNew) "Day created" else "Day updated")
                },
                onDelete = {
                    viewModel.deletePlan(editingPlan!!)
                    editingPlan = null
                    toast.show("Day deleted")
                },
                onCancel = { editingPlan = null }
            )
        }
        else -> {
            WorkoutGrid(
                viewModel = viewModel,
                onEditPlan = { plan, new -> 
                    editingPlan = plan
                    isNew = new
                },
                onStartPlan = { plan ->
                    activeWorkout.start(plan)
                },
                onEditCardio = { type, new ->
                    editingCardio = type
                    isNewCardio = new
                },
                onStartCardio = { type ->
                    activeCardio.start(type)
                },
                sessionQuery = sessionQuery,
                onSessionQueryChange = { sessionQuery = it },
                showAllSessions = showAllSessions,
                onShowAllSessionsChange = { showAllSessions = it },
                onEditSession = { editingSession = it },
                onLogCardio = { loggingCardio = it }
            )
        }
    }
}

@Composable
fun WorkoutGrid(
    viewModel: StoreViewModel,
    onEditPlan: (WorkoutPlan, Boolean) -> Unit,
    onStartPlan: (WorkoutPlan) -> Unit,
    onEditCardio: (CardioType, Boolean) -> Unit,
    onStartCardio: (CardioType) -> Unit,
    sessionQuery: String,
    onSessionQueryChange: (String) -> Unit,
    showAllSessions: Boolean,
    onShowAllSessionsChange: (Boolean) -> Unit,
    onEditSession: (WorkoutSession) -> Unit,
    onLogCardio: (CardioType) -> Unit
) {
    val plans by viewModel.plans.collectAsState()
    val cardioTypes by viewModel.cardioTypes.collectAsState()
    val sessions by viewModel.sessions.collectAsState()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(11.dp),
        contentPadding = PaddingValues(16.dp)
    ) {
        item {
            Text(text = "Edit hint", style = MaterialTheme.typography.bodySmall)
            Text(text = "Select day", style = MaterialTheme.typography.titleMedium)
        }

        // CardGrid equivalent
        items(plans) { plan ->
            DayCard(
                plan = plan,
                onEdit = { onEditPlan(plan, false) },
                onStart = { onStartPlan(plan) }
            )
        }
        item {
            AddCard(onClick = { onEditPlan(WorkoutPlan(name = ""), true) })
        }

        // Cardio Section
        item {
            Text(text = "Cardio Types", style = MaterialTheme.typography.titleMedium)
        }
        items(cardioTypes) { type ->
            CardioTile(
                type = type,
                onEdit = { onEditCardio(type, false) },
                onStart = { onStartCardio(type) },
                onLog = { onLogCardio(type) }
            )
        }
        item {
            AddCardioTile(onClick = { onEditCardio(CardioType(name = "", sport = "other", color = "ffb000"), true) })
        }

        item {
            CalendarCard()
        }
        
        item {
            RecentSessionsList(
                sessions = sessions,
                query = sessionQuery,
                onQueryChange = onSessionQueryChange,
                showAll = showAllSessions,
                onShowAllChange = onShowAllSessionsChange,
                onEditSession = onEditSession
            )
        }
    }
}

@Composable
fun DayCard(plan: WorkoutPlan, onEdit: () -> Unit, onStart: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().height(130.dp),
        onClick = onEdit
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = plan.name, style = MaterialTheme.typography.titleLarge)
                Text(text = plan.sub, style = MaterialTheme.typography.bodyMedium)
                Spacer(modifier = Modifier.weight(1f))
                Text(text = "${plan.exercises.size} Exercises", style = MaterialTheme.typography.labelSmall)
            }
            IconButton(
                onClick = onStart,
                modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
            ) {
                Icon(imageVector = Icons.Filled.PlayArrow, contentDescription = "Start")
            }
        }
    }
}

@Composable
fun CardioTile(type: CardioType, onEdit: () -> Unit, onStart: () -> Unit, onLog: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().height(112.dp),
        onClick = onLog
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = type.name, style = MaterialTheme.typography.titleLarge)
                Text(text = type.sub ?: type.sportType.label, style = MaterialTheme.typography.bodyMedium)
            }
            IconButton(
                onClick = onStart,
                modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
            ) {
                Icon(imageVector = Icons.Filled.PlayArrow, contentDescription = "Start")
            }
            IconButton(
                onClick = onEdit,
                modifier = Modifier.align(Alignment.TopEnd).padding(8.dp)
            ) {
                Icon(imageVector = Icons.Filled.Edit, contentDescription = "Edit")
            }
        }
    }
}

@Composable
fun AddCard(onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().height(130.dp),
        onClick = onClick
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("+ New day", style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
fun AddCardioTile(onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().height(112.dp),
        onClick = onClick
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("+ New cardio", style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
fun CalendarCard() {}

@Composable
fun RecentSessionsList(
    sessions: List<WorkoutSession>,
    query: String,
    onQueryChange: (String) -> Unit,
    showAll: Boolean,
    onShowAllChange: (Boolean) -> Unit,
    onEditSession: (WorkoutSession) -> Unit
) {
    val filtered = remember(sessions, query, showAll) {
        val base = sessions.sortedByDescending { it.date }
        val bySearch = if (query.isBlank()) base else base.filter {
            it.planName.contains(query, ignoreCase = true)
        }
        if (showAll) bySearch else bySearch.take(5)
    }

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Recent sessions", style = MaterialTheme.typography.titleMedium)
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            placeholder = { Text("Search sessions...") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        if (filtered.isEmpty()) {
            Text("No sessions yet", style = MaterialTheme.typography.bodySmall)
        } else {
            filtered.forEach { s ->
                Card(modifier = Modifier.fillMaxWidth(), onClick = { onEditSession(s) }) {
                    Row(
                        modifier = Modifier.padding(12.dp).fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(s.planName, style = MaterialTheme.typography.titleSmall)
                            Text(s.date, style = MaterialTheme.typography.bodySmall)
                        }
                        Text("${s.exercises.size} ex", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            if (!showAll && sessions.size > 5) {
                TextButton(onClick = { onShowAllChange(true) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Show all (${sessions.size})")
                }
            }
        }
    }
}

@Composable
fun LiveCardioView(type: CardioType, onBack: () -> Unit, onSaved: () -> Unit) {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = onBack) { Text("← Minimize") }
            Text(type.name, style = MaterialTheme.typography.titleLarge)
        }
        Spacer(modifier = Modifier.weight(1f))
        Button(onClick = onSaved, modifier = Modifier.fillMaxWidth()) {
            Text("Finish")
        }
    }
}
