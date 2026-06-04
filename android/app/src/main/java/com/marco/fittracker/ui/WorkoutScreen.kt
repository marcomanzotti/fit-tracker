package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.DisposableEffect
import com.marco.fittracker.data.CardioType
import com.marco.fittracker.data.LoggedExercise
import com.marco.fittracker.data.PlanExercise
import com.marco.fittracker.data.SetEntry
import com.marco.fittracker.data.WorkoutPlan
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.fmtDuration
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.t
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum
import com.marco.fittracker.data.trimp

@Composable
fun WorkoutScreen() {
    val store = LocalStore.current
    val toast = LocalToast.current
    val activeWorkout = LocalActiveWorkout.current

    var editingPlan by remember { mutableStateOf<WorkoutPlan?>(null) }
    var isNew by remember { mutableStateOf(false) }

    val active = activeWorkout.planId?.let { store.plan(it) }
    when {
        active != null && !activeWorkout.minimized -> LiveWorkout(active, activeWorkout.log,
            onBack = { activeWorkout.minimized = true },   // minimize, keep running
            onSaved = { activeWorkout.end() })             // finish / discard ends it
        editingPlan != null -> PlanEditor(editingPlan!!, isNew,
            onSave = { p ->
                val fixed = if (p.name.trim().isEmpty()) p.copy(name = "Nuovo giorno") else p
                store.upsertPlan(fixed)
                toast.show(if (isNew) "Giorno creato" else "Giorno aggiornato")
                editingPlan = null
            },
            onDelete = { store.deletePlan(editingPlan!!.id); toast.show("Giorno eliminato"); editingPlan = null },
            onCancel = { editingPlan = null })
        else -> WorkoutGrid(
            onStart = { p -> activeWorkout.start(p) },
            onNew = { editingPlan = WorkoutPlan(name = "", sub = "", color = T.planColors.first(), exercises = emptyList()); isNew = true },
            onEdit = { editingPlan = it; isNew = false }
        )
    }
}

// MARK: - Grid of workout days
@Composable
private fun WorkoutGrid(onStart: (WorkoutPlan) -> Unit, onNew: () -> Unit, onEdit: (WorkoutPlan) -> Unit) {
    val store = LocalStore.current
    val tap = rememberTap()

    var loggingCardio by remember { mutableStateOf<CardioType?>(null) }
    var editingCardio by remember { mutableStateOf<CardioType?>(null) }
    var isNewCardio by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<WorkoutSession?>(null) }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Lbl(t("wk.select_day"), modifier = Modifier.weight(1f))
        Row(
            Modifier.clip(RoundedCornerShape(10.dp)).background(T.acc.copy(alpha = 0.07f))
                .border(1.dp, T.acc, RoundedCornerShape(10.dp))
                .clickable { tap(); onNew() }.padding(vertical = 8.dp, horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Filled.Add, null, tint = T.acc, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(6.dp))
            Text(t("wk.new_day").uppercase(), color = T.acc, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
    }

    Text(t("wk.edit_hint"), color = T.sub, fontSize = 11.sp, lineHeight = 15.sp)

    // 2-column grid built from rows
    val cells = store.plans.toList()
    val rows = (cells.size + 1 + 1) / 2  // +1 for add card
    val items: List<WorkoutPlan?> = cells + listOf(null) // null = add card
    for (r in 0 until rows) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(11.dp)) {
            for (c in 0 until 2) {
                val idx = r * 2 + c
                Box(Modifier.weight(1f)) {
                    if (idx < items.size) {
                        val p = items[idx]
                        if (p != null) DayCard(p, onStart, onEdit) else AddCard(onNew)
                    }
                }
            }
        }
    }

    // Cardio activities (saveable, customizable like strength days)
    CardioSection(
        onLog = { loggingCardio = it },
        onEdit = { editingCardio = it; isNewCardio = false },
        onNew = { editingCardio = CardioType(name = "", sport = "running", color = T.cardioColors.first()); isNewCardio = true }
    )

    // Recent sessions (tap to edit / delete)
    val recent = store.sessions.sortedByDescending { it.date }.take(5)
    if (recent.isNotEmpty()) {
        Card {
            Lbl(t("wk.recent"))
            Spacer(Modifier.height(4.dp))
            recent.forEach { s ->
                Box(Modifier.fillMaxWidth().clickable { tap(); editingSession = s }) {
                    DividerRow {
                        Column(Modifier.weight(1f)) {
                            Text(s.planName.uppercase(), color = hexColor(s.planColor), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.height(3.dp))
                            val detail = if (s.sportType.isCardio) (s.durationSeconds?.let { fmtDuration(it) } ?: s.sportType.label())
                                         else "${s.exercises.size} ${t("home.exercises")}"
                            Text("${s.date} · $detail · ${store.estimateCalories(s)} kcal", color = T.sub, fontSize = 10.sp)
                        }
                        Badge(if (s.sportType.isCardio) s.sportType.label() else "${s.totalSets} ${t("wk.sets_n")}")
                    }
                }
            }
        }
    }

    loggingCardio?.let { CardioLoggerDialog(it) { loggingCardio = null } }
    editingCardio?.let { CardioTypeEditorDialog(it, isNewCardio) { editingCardio = null } }
    editingSession?.let { SessionEditorDialog(it) { editingSession = null } }
}

@Composable
private fun DayCard(p: WorkoutPlan, onStart: (WorkoutPlan) -> Unit, onEdit: (WorkoutPlan) -> Unit) {
    val tap = rememberTap()
    val pc = hexColor(p.color)
    Box {
        // Card body — tap opens plan editor
        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(T.radius))
                .background(T.c1)
                .drawBehind { drawRect(color = pc, size = androidx.compose.ui.geometry.Size(3.dp.toPx(), size.height)) }
                .border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .clickable { tap(); onEdit(p) }
                .padding(vertical = 15.dp, horizontal = 14.dp)
        ) {
            Text(t("wk.day").uppercase(), color = pc, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp,
                modifier = Modifier.padding(end = 30.dp))
            Spacer(Modifier.height(5.dp))
            Text(p.name.uppercase(), color = T.txt, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Spacer(Modifier.height(3.dp))
            Text(p.sub, color = T.sub, fontSize = 11.sp, maxLines = 1)
            Spacer(Modifier.height(11.dp))
            Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
            Spacer(Modifier.height(8.dp))
            Text("${p.exercises.size} ${t("wk.exercises_n").uppercase()}", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
            Spacer(Modifier.height(4.dp))
        }
        // Edit icon — top-right
        Box(
            Modifier.align(Alignment.TopEnd).padding(8.dp).size(26.dp)
                .clip(CircleShape).background(pc.copy(alpha = 0.85f))
                .clickable { tap(); onEdit(p) },
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Filled.Edit, "edit", tint = T.bg, modifier = Modifier.size(12.dp))
        }
        // Circular Play button — bottom-right, starts the workout immediately
        PlayCircle(pc, Modifier.align(Alignment.BottomEnd).padding(10.dp)) { tap(); onStart(p) }
    }
}

// MARK: - Circular Play button (shared by strength & cardio cards)
@Composable
fun PlayCircle(color: androidx.compose.ui.graphics.Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(38.dp).clip(CircleShape).background(color).clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(Icons.Filled.PlayArrow, "start", tint = T.bg, modifier = Modifier.size(20.dp))
    }
}

@Composable
private fun AddCard(onNew: () -> Unit) {
    val tap = rememberTap()
    Column(
        Modifier.fillMaxWidth().heightIn(min = 120.dp)
            .clip(RoundedCornerShape(T.radius))
            .background(T.c1.copy(alpha = 0.5f))
            .border(1.dp, T.brd2, RoundedCornerShape(T.radius))
            .clickable { tap(); onNew() }
            .padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(Icons.Filled.AddCircle, null, tint = T.sub, modifier = Modifier.size(26.dp))
        Spacer(Modifier.height(8.dp))
        Text("Crea giorno", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
    }
}

// MARK: - Live workout
@Composable
private fun LiveWorkout(plan: WorkoutPlan, log: SnapshotStateList<LoggedExercise>, onBack: () -> Unit, onSaved: () -> Unit) {
    val store = LocalStore.current
    val timer = LocalTimer.current
    val toast = LocalToast.current
    val activeWorkout = LocalActiveWorkout.current
    val tap = rememberTap()
    val view = LocalView.current
    val pc = hexColor(plan.color)

    var addName by remember { mutableStateOf("") }
    val showNotes = remember { mutableStateListOf<String>() }
    var saved by remember { mutableStateOf(false) }
    var sessDurationSec by remember { mutableStateOf<Int?>(null) }
    var sessAvgHR by remember { mutableStateOf("") }
    var sessRMSSD by remember { mutableStateOf("") }
    var sessCalManual by remember { mutableStateOf("") }
    var confirmDiscard by remember { mutableStateOf(false) }

    DisposableEffect(Unit) { view.keepScreenOn = true; onDispose { view.keepScreenOn = false } }

    // Live elapsed timer (counts up from workout start)
    var elapsedSec by remember { mutableStateOf(0) }
    LaunchedEffect(activeWorkout.startMs) {
        while (activeWorkout.isActive) {
            elapsedSec = ((System.currentTimeMillis() - activeWorkout.startMs) / 1000).toInt()
            kotlinx.coroutines.delay(1000)
        }
    }

    // Back row — MINIMIZES the workout (keeps running); never discards.
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        GhostButton("↓ ${t("wk.minimize")}") { onBack() }
        Column(Modifier.weight(1f)) {
            Text(plan.name.uppercase(), color = pc, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("${plan.sub} · ${today()}", color = T.sub, fontSize = 10.sp)
        }
    }

    // Live elapsed timer (replaces the last-session block while active). Past
    // sessions are visible elsewhere; the running time is more useful here.
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(pc.copy(alpha = 0.06f))
            .drawBehind { drawRect(color = pc, size = androidx.compose.ui.geometry.Size(2.dp.toPx(), size.height)) }
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(pc))
        Spacer(Modifier.width(8.dp))
        Text(t("wk.workout_live").uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        Spacer(Modifier.weight(1f))
        Text("%d:%02d".format(elapsedSec / 60, elapsedSec % 60), color = T.txt, fontSize = 30.sp, fontWeight = FontWeight.Bold)
    }

    // Exercise cards
    log.indices.forEach { i -> ExerciseCard(plan, log, i, showNotes) }

    // Add exercise on the fly
    Card {
        Lbl("Aggiungi esercizio")
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp), verticalAlignment = Alignment.CenterVertically) {
            BasicTextField(
                value = addName, onValueChange = { addName = it },
                textStyle = TextStyle(color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.Medium),
                cursorBrush = SolidColor(T.acc), singleLine = true,
                modifier = Modifier.weight(1f).clip(RoundedCornerShape(T.radiusS)).background(T.c2)
                    .border(1.dp, T.brd, RoundedCornerShape(T.radiusS)).padding(vertical = 12.dp, horizontal = 14.dp),
                decorationBox = { inner -> if (addName.isEmpty()) Text("es. Dip alle parallele", color = T.sub, fontSize = 15.sp); inner() }
            )
            Box(
                Modifier.size(50.dp, 48.dp).clip(RoundedCornerShape(T.radiusS)).background(T.acc)
                    .clickable {
                        val name = addName.trim()
                        if (name.isNotEmpty()) {
                            tap()
                            log.add(LoggedExercise(name = name, sets = List(3) { SetEntry() }, target = "3×10"))
                            store.addExerciseToPlan(plan.id, name)
                            addName = ""; toast.show("Esercizio aggiunto")
                        }
                    },
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Filled.Add, null, tint = T.bg) }
        }
        Spacer(Modifier.height(8.dp))
        Text("Aggiunto alla sessione e salvato nel giorno per le prossime volte.", color = T.sub, fontSize = 10.sp)
    }

    // Session internal-load capture (TRIMP from duration + avg HR)
    Card {
        InfoLbl(t("load.title"), "load", T.acc2)
        Spacer(Modifier.height(10.dp))
        HMSField(t("wk.duration"), sessDurationSec) { sessDurationSec = it }
        Spacer(Modifier.height(12.dp))
        LoadField(t("wk.avg_hr"), sessAvgHR, "trimp") { sessAvgHR = it }
        val liveTrimp = run {
            val d = sessDurationSec; val hr = sessAvgHR.toIntOrNull()
            if (d != null && d > 0 && hr != null && hr > 0)
                store.trimp(WorkoutSession(date = today(), planId = plan.id, planName = plan.name, planColor = plan.color, durationSec = d, avgHR = hr))
            else null
        }
        liveTrimp?.let { v ->
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("TRIMP", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
                Spacer(Modifier.width(6.dp))
                Text("${Math.round(v)}", color = T.acc2, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                Text(t("load.trimp_hint"), color = T.sub, fontSize = 9.sp)
            }
        }
        Spacer(Modifier.height(11.dp))
        Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
        Spacer(Modifier.height(11.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(t("load.recommended").uppercase(), color = T.sub, fontSize = 8.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
            Spacer(Modifier.width(7.dp))
            Badge(t("load.sensor"), T.blue, T.blue.copy(alpha = 0.12f))
        }
        Spacer(Modifier.height(9.dp))
        LoadField(t("wk.rmssd"), sessRMSSD, "rmssd", KeyboardType.Decimal) { sessRMSSD = it }
    }

    // Calories — NOT prefilled at start. Pressing Play begins a live session, it
    // isn't a completed log. The estimate appears only once there's real data
    // (duration or HR); the duration falls back to the live elapsed time.
    val caloriesReady = sessCalManual.isNotEmpty() || (sessDurationSec ?: 0) > 0 || (sessAvgHR.toIntOrNull() ?: 0) > 0
    val estCal = run {
        val snap = WorkoutSession(date = today(), planId = plan.id, planName = plan.name, planColor = plan.color,
            exercises = log.toList(), durationSec = sessDurationSec ?: (if (elapsedSec > 0) elapsedSec else null), avgHR = sessAvgHR.toIntOrNull())
        store.estimateCalories(snap)
    }
    Card(accent = T.acc) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("wk.calories"), T.acc2)
            Spacer(Modifier.width(5.dp)); InfoButton("calories", T.acc2)
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(if (sessCalManual.isNotEmpty()) sessCalManual else if (caloriesReady) "$estCal" else "—",
                    color = if (caloriesReady) T.acc else T.sub, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(4.dp))
                Text("kcal", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(t("wk.cal_override").uppercase(), color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp, modifier = Modifier.weight(1f))
            Box(Modifier.width(110.dp)) { InputField(sessCalManual, { sessCalManual = it }, if (caloriesReady) "$estCal" else "—", KeyboardType.Number) }
        }
        Spacer(Modifier.height(6.dp))
        Text(if (caloriesReady) t("wk.cal_hint") else t("wk.cal_at_finish"), color = T.sub, fontSize = 9.sp)
    }

    // Finish (primary) — duration source of truth: typed value, else live elapsed.
    BigButton(if (saved) t("wk.saved") else t("wk.finish_session"), color = if (saved) T.good else T.acc) {
        if (!saved) {
            val exercises = log.map { e -> e.copy(sets = e.sets.filter { it.filled }) }.filter { it.sets.isNotEmpty() }
            if (exercises.isEmpty()) { toast.show("Nessuna serie da salvare") } else {
                store.addSession(WorkoutSession(
                    date = today(), planId = plan.id, planName = plan.name, planColor = plan.color, exercises = exercises,
                    durationSec = sessDurationSec ?: (if (elapsedSec > 0) elapsedSec else null), avgHR = sessAvgHR.toIntOrNull(),
                    rmssd = if (sessRMSSD.isEmpty()) null else pf(sessRMSSD),
                    caloriesManual = sessCalManual.toIntOrNull()?.takeIf { it > 0 }))
                saved = true; timer.stop()
                view.performHapticFeedback(android.view.HapticFeedbackConstants.CONFIRM)
                toast.show("Sessione salvata")
                onSaved()
            }
        }
    }

    // Discard (destructive, red) — only ends the workout via explicit confirm.
    Spacer(Modifier.height(4.dp))
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(T.radiusS))
            .border(1.dp, T.red.copy(alpha = 0.45f), RoundedCornerShape(T.radiusS))
            .clickable { tap(); confirmDiscard = true }.padding(vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center
    ) {
        Icon(Icons.Filled.Delete, null, tint = T.red, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text(t("wk.discard_session"), color = T.red, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }

    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text(t("wk.discard_session"), color = T.txt) },
            text = { Text(t("wk.discard_q"), color = T.sub) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDiscard = false
                    timer.stop()
                    view.performHapticFeedback(android.view.HapticFeedbackConstants.REJECT)
                    toast.show(t("wk.discarded"))
                    onSaved()
                }) { Text(t("wk.discard_session"), color = T.red) }
            },
            dismissButton = { TextButton(onClick = { confirmDiscard = false }) { Text(t("cancel"), color = T.sub) } },
            containerColor = T.c1
        )
    }
}

// MARK: - Labeled numeric field with optional info popup (session-load capture)
@Composable
private fun LoadField(label: String, value: String, info: String? = null,
                      keyboard: KeyboardType = KeyboardType.Number, onChange: (String) -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(label)
            if (info != null) { Spacer(Modifier.width(4.dp)); InfoButton(info) }
        }
        Spacer(Modifier.height(6.dp))
        InputField(value, onChange, "—", keyboard)
    }
}

@Composable
private fun ExerciseCard(plan: WorkoutPlan, log: SnapshotStateList<LoggedExercise>, i: Int, showNotes: SnapshotStateList<String>) {
    val store = LocalStore.current
    val timer = LocalTimer.current
    val tap = rememberTap()
    val ex = log[i]
    val pr = store.exercisePR(ex.name)
    val prevEx = store.lastSession(plan.id)?.exercises?.firstOrNull { it.name == ex.name }
    val sug = store.suggested(plan.id, ex.name)

    Card {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(ex.name, color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                if (ex.target.isNotEmpty()) { Spacer(Modifier.height(6.dp)); Tag(ex.target) }
            }
            if (pr > 0) {
                Column(horizontalAlignment = Alignment.End) {
                    Text("PR", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
                    Text("${trimNum(pr)} kg", color = T.acc, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
        Spacer(Modifier.height(10.dp))

        if (prevEx != null && prevEx.sets.isNotEmpty()) {
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(T.blue.copy(alpha = 0.05f))
                    .border(1.dp, T.blue.copy(alpha = 0.12f), RoundedCornerShape(10.dp)).padding(vertical = 9.dp, horizontal = 12.dp)
            ) {
                Text("ULTIMA VOLTA", color = T.blue, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp)
                Spacer(Modifier.height(6.dp))
                ChipsFlow(prevEx.sets.mapIndexed { idx, s -> "S${idx + 1}: ${disp(s.weight)}×${disp(s.reps)}" })
            }
            Spacer(Modifier.height(10.dp))
        }

        if (sug != null) {
            Row(
                Modifier.clip(CircleShape).background(T.acc.copy(alpha = 0.09f))
                    .border(1.dp, T.acc.copy(alpha = 0.22f), CircleShape).padding(vertical = 6.dp, horizontal = 13.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.NorthEast, null, tint = T.acc2, modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(6.dp))
                Text("Prova ${trimNum(sug)} kg", color = T.acc2, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(11.dp))
        }

        // Column headers
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Spacer(Modifier.width(28.dp))
            Text("RIP", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp, modifier = Modifier.width(66.dp), textAlign = TextAlign.Center)
            Text("KG", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp, modifier = Modifier.width(66.dp), textAlign = TextAlign.Center)
        }
        Spacer(Modifier.height(6.dp))

        log[i].sets.indices.forEach { j -> SetRow(log, i, j, pr) }

        // Footer
        Row(Modifier.fillMaxWidth().padding(top = 9.dp), verticalAlignment = Alignment.CenterVertically) {
            GhostButton("+ Serie") { log[i] = log[i].copy(sets = log[i].sets + SetEntry()) }
            Spacer(Modifier.width(8.dp))
            GhostButton("Timer ${store.prefs.timer}s", color = T.blue) { timer.start(store.prefs.timer) }
            Spacer(Modifier.weight(1f))
            if (log[i].volume > 0)
                Text("Vol ${log[i].volume.toInt()} · Max ${trimNum(log[i].maxWeight)} kg", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }

        // Notes
        Spacer(Modifier.height(9.dp))
        if (showNotes.contains(ex.id)) {
            BasicTextField(
                value = log[i].notes, onValueChange = { log[i] = log[i].copy(notes = it) },
                textStyle = TextStyle(color = T.txt, fontSize = 13.sp), cursorBrush = SolidColor(T.acc),
                modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).background(T.c2)
                    .border(1.dp, T.brd, RoundedCornerShape(10.dp)).padding(vertical = 10.dp, horizontal = 14.dp),
                decorationBox = { inner -> if (log[i].notes.isEmpty()) Text("Note…", color = T.sub, fontSize = 13.sp); inner() }
            )
        } else {
            Text("+ Note", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(9.dp)).background(T.c2).border(1.dp, T.brd, RoundedCornerShape(9.dp))
                    .clickable { tap(); showNotes.add(ex.id) }.padding(vertical = 8.dp, horizontal = 12.dp))
        }
    }
}

@Composable
private fun SetRow(log: SnapshotStateList<LoggedExercise>, i: Int, j: Int, pr: Double) {
    val tap = rememberTap()
    val s = log[i].sets[j]
    val w = pf(s.weight)
    val isPR = w > pr && w > 0
    fun editSet(transform: (SetEntry) -> SetEntry) {
        val newSets = log[i].sets.toMutableList().also { it[j] = transform(it[j]) }
        log[i] = log[i].copy(sets = newSets)
    }
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp)
            .clip(RoundedCornerShape(9.dp)).background(if (isPR) T.acc.copy(alpha = 0.05f) else Color.Transparent),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        Text("S${j + 1}", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(28.dp), textAlign = TextAlign.Center)
        SmallNumField(s.reps, { v -> editSet { it.copy(reps = v) } }, highlight = isPR)
        SmallNumField(s.weight, { v -> editSet { it.copy(weight = v) } }, highlight = isPR)
        if (isPR) {
            Text("PR", color = T.acc, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        } else {
            Icon(Icons.Filled.Close, "rimuovi", tint = T.red.copy(alpha = 0.5f),
                modifier = Modifier.size(34.dp, 42.dp).clickable {
                    tap(); log[i] = log[i].copy(sets = log[i].sets.toMutableList().also { it.removeAt(j) })
                })
        }
    }
}

// MARK: - Plan editor
@Composable
private fun PlanEditor(initial: WorkoutPlan, isNew: Boolean, onSave: (WorkoutPlan) -> Unit, onDelete: () -> Unit, onCancel: () -> Unit) {
    val tap = rememberTap()
    var plan by remember { mutableStateOf(initial) }
    var confirmDelete by remember { mutableStateOf(false) }
    val pc = hexColor(plan.color)

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        GhostButton("← Annulla") { onCancel() }
        Column(Modifier.weight(1f)) {
            Text(if (isNew) "NUOVO GIORNO" else "MODIFICA GIORNO", color = pc, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Text("Personalizza esercizi, serie e ripetizioni", color = T.sub, fontSize = 10.sp)
        }
    }

    Card {
        Lbl("Nome giorno"); Spacer(Modifier.height(8.dp))
        InputField(plan.name, { plan = plan.copy(name = com.marco.fittracker.data.titleCased(it)) }, "es. Push, Petto, Gambe…", KeyboardType.Text)
        Spacer(Modifier.height(10.dp))
        Lbl("Sottotitolo"); Spacer(Modifier.height(8.dp))
        InputField(plan.sub, { plan = plan.copy(sub = it) }, "es. Spalle + Petto", KeyboardType.Text)
        Spacer(Modifier.height(12.dp))
        Lbl("Colore"); Spacer(Modifier.height(8.dp))
        ColorSwatches(plan.color) { plan = plan.copy(color = it) }
    }

    Card {
        Lbl("Esercizi (${plan.exercises.size})")
        Spacer(Modifier.height(10.dp))
        if (plan.exercises.isEmpty())
            Text("Nessun esercizio. Aggiungine uno qui sotto.", color = T.sub, fontSize = 12.sp, modifier = Modifier.padding(vertical = 8.dp))
        plan.exercises.indices.forEach { i ->
            PlanExerciseRow(
                plan.exercises[i], i, plan.exercises.size,
                onChange = { upd -> plan = plan.copy(exercises = plan.exercises.toMutableList().also { it[i] = upd }) },
                onRemove = { plan = plan.copy(exercises = plan.exercises.toMutableList().also { it.removeAt(i) }) },
                onMoveUp = { if (i > 0) plan = plan.copy(exercises = plan.exercises.toMutableList().also { java.util.Collections.swap(it, i, i - 1) }) },
                onMoveDown = { if (i < plan.exercises.size - 1) plan = plan.copy(exercises = plan.exercises.toMutableList().also { java.util.Collections.swap(it, i, i + 1) }) }
            )
            Spacer(Modifier.height(8.dp))
        }
        Row(
            Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(T.radiusS))
                .background(T.acc.copy(alpha = 0.07f)).border(1.dp, T.acc.copy(alpha = 0.4f), RoundedCornerShape(T.radiusS))
                .clickable { tap(); plan = plan.copy(exercises = plan.exercises + PlanExercise(name = "")) }.padding(12.dp),
            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Filled.Add, null, tint = T.acc, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Aggiungi esercizio", color = T.acc, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }

    BigButton(if (isNew) "Crea giorno" else "Salva modifiche") { onSave(plan) }

    if (!isNew) {
        Text("Elimina giorno", color = T.red, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp).border(1.dp, T.red.copy(alpha = 0.4f), RoundedCornerShape(T.radiusS))
                .clickable { tap(); confirmDelete = true }.padding(vertical = 14.dp))
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Eliminare questo giorno?", color = T.txt) },
            confirmButton = { TextButton(onClick = { confirmDelete = false; onDelete() }) { Text("Elimina", color = T.red) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Annulla", color = T.sub) } },
            containerColor = T.c1
        )
    }
}

@Composable
private fun PlanExerciseRow(ex: PlanExercise, i: Int, count: Int, onChange: (PlanExercise) -> Unit, onRemove: () -> Unit, onMoveUp: () -> Unit, onMoveDown: () -> Unit) {
    val tap = rememberTap()
    val store = LocalStore.current
    var showSuggestions by remember { mutableStateOf(false) }

    val suggestions = remember(ex.name) {
        val q = ex.name.trim()
        if (q.length < 2) emptyList()
        else store.allExerciseNames()
            .map { it.second }
            .filter { it.contains(q, ignoreCase = true) && !it.equals(q, ignoreCase = true) }
            .take(5)
    }

    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c2)
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS)).padding(vertical = 11.dp, horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) {
                BasicTextField(
                    value = ex.name,
                    onValueChange = { v ->
                        val titled = com.marco.fittracker.data.titleCased(v)
                        onChange(ex.copy(name = titled))
                        showSuggestions = suggestions.isNotEmpty()
                    },
                    textStyle = TextStyle(color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.Medium), cursorBrush = SolidColor(T.acc),
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                    decorationBox = { inner -> if (ex.name.isEmpty()) Text(t("pe.ex_name_ph"), color = T.sub, fontSize = 14.sp); inner() }
                )
                if (showSuggestions && suggestions.isNotEmpty()) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c1)
                            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
                    ) {
                        suggestions.forEachIndexed { idx, s ->
                            Text(
                                s, color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                                modifier = Modifier.fillMaxWidth().clickable { tap(); onChange(ex.copy(name = s)); showSuggestions = false }
                                    .padding(vertical = 9.dp, horizontal = 12.dp)
                            )
                            if (idx < suggestions.lastIndex) Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
                        }
                    }
                }
            }
            Icon(Icons.Filled.Close, "rimuovi", tint = T.red.copy(alpha = 0.7f), modifier = Modifier.size(30.dp).clickable { tap(); onRemove() })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("SERIE", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(26.dp).clip(CircleShape).background(T.c3).clickable { tap(); if (ex.sets > 1) onChange(ex.copy(sets = ex.sets - 1)) }, contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Remove, null, tint = T.txt, modifier = Modifier.size(14.dp))
            }
            Text("${ex.sets}", color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(24.dp), textAlign = TextAlign.Center)
            Box(Modifier.size(26.dp).clip(CircleShape).background(T.c3).clickable { tap(); onChange(ex.copy(sets = ex.sets + 1)) }, contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Add, null, tint = T.txt, modifier = Modifier.size(14.dp))
            }
            Spacer(Modifier.weight(1f))
            Text("RIP", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
            Spacer(Modifier.width(8.dp))
            BasicTextField(
                value = ex.reps, onValueChange = { onChange(ex.copy(reps = it)) },
                textStyle = TextStyle(color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center),
                cursorBrush = SolidColor(T.acc), singleLine = true,
                modifier = Modifier.width(64.dp).clip(RoundedCornerShape(8.dp)).background(T.c2).border(1.dp, T.brd, RoundedCornerShape(8.dp)).padding(vertical = 7.dp),
                decorationBox = { inner -> Box(contentAlignment = Alignment.Center) { if (ex.reps.isEmpty()) Text("10", color = T.sub, fontSize = 14.sp); inner() } }
            )
            Spacer(Modifier.width(8.dp))
            Column {
                Icon(Icons.Filled.KeyboardArrowUp, "su", tint = if (i > 0) T.sub else T.brd, modifier = Modifier.size(22.dp).clickable { tap(); onMoveUp() })
                Icon(Icons.Filled.KeyboardArrowDown, "giu", tint = if (i < count - 1) T.sub else T.brd, modifier = Modifier.size(22.dp).clickable { tap(); onMoveDown() })
            }
        }
    }
}

private fun disp(s: String): String = if (s.isEmpty()) "?" else s
