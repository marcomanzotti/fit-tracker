package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.marco.fittracker.data.CardioType
import com.marco.fittracker.data.LoggedExercise
import com.marco.fittracker.data.SetEntry
import com.marco.fittracker.data.Sport
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.t
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum

@Composable
private fun DialogShell(onClose: () -> Unit, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier
                .fillMaxWidth()
                .heightIn(max = 620.dp)
                .clip(RoundedCornerShape(T.radius))
                .background(T.bg)
                .border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .padding(18.dp)
                .verticalScroll(rememberScrollState()),
            content = content
        )
    }
}

@Composable
private fun Field(label: String, value: String, onChange: (String) -> Unit, ph: String, kb: KeyboardType = KeyboardType.Number) {
    Column(Modifier.fillMaxWidth()) {
        Lbl(label)
        Spacer(Modifier.height(7.dp))
        InputField(value, onChange, ph, kb)
    }
}

// MARK: - Cardio logger
@Composable
fun CardioLoggerDialog(type: CardioType, onClose: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    var duration by remember { mutableStateOf("") }
    var distance by remember { mutableStateOf("") }
    var avgHR by remember { mutableStateOf("") }
    var rpe by remember { mutableStateOf("") }
    var rmssd by remember { mutableStateOf("") }
    val pc = hexColor(type.color)

    fun build(dur: Int) = WorkoutSession(
        date = today(), planId = "cardio-${type.id}", planName = type.name, planColor = type.color,
        exercises = emptyList(), sport = type.sport, durationMin = dur,
        rpe = rpe.toIntOrNull(), avgHR = avgHR.toIntOrNull(),
        rmssd = if (rmssd.isEmpty()) null else pf(rmssd),
        distanceKm = if (distance.isEmpty()) null else pf(distance)
    )
    val est = duration.toIntOrNull()?.takeIf { it > 0 }?.let { store.estimateCalories(build(it)) }

    DialogShell(onClose) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Lbl(t("wk.log_cardio"), T.sub)
                Text(type.name.uppercase(), color = pc, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
            Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f)) { Field(t("wk.duration"), duration, { duration = it }, "40") }
            Box(Modifier.weight(1f)) { Field(t("wk.distance"), distance, { distance = it }, "8", KeyboardType.Decimal) }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f)) { Field(t("wk.avg_hr"), avgHR, { avgHR = it }, "150") }
            Box(Modifier.weight(1f)) { Field(t("wk.rpe"), rpe, { rpe = it }, "6") }
        }
        Spacer(Modifier.height(12.dp))
        Field(t("wk.rmssd"), rmssd, { rmssd = it }, "—", KeyboardType.Decimal)
        Spacer(Modifier.height(14.dp))
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c1)
                .border(1.dp, T.brd, RoundedCornerShape(T.radiusS)).padding(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Lbl(t("wk.est_calories"), T.acc2)
                Spacer(Modifier.width(5.dp)); InfoButton("calories", T.acc2)
                Spacer(Modifier.weight(1f))
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(est?.toString() ?: "—", color = T.acc, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(4.dp))
                    Text("kcal", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(t("wk.est_cal_hint"), color = T.sub, fontSize = 10.sp)
        }
        Spacer(Modifier.height(16.dp))
        BigButton(t("save")) {
            val dur = duration.toIntOrNull()
            if (dur == null || dur <= 0) { toast.show(t("wk.duration")) } else {
                store.addSession(build(dur)); toast.show(t("save")); onClose()
            }
        }
    }
}

// MARK: - Cardio type editor
@Composable
fun CardioTypeEditorDialog(initial: CardioType, isNew: Boolean, onClose: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    var type by remember { mutableStateOf(initial) }
    val kinds = listOf("running", "swimming", "cycling", "walking", "other")
    val pc = hexColor(type.color)

    DialogShell(onClose) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text((if (isNew) t("wk.new_cardio") else t("wk.edit_cardio")).uppercase(),
                color = pc, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
        }
        Spacer(Modifier.height(14.dp))
        Field(t("wk.activity_name"), type.name, { type = type.copy(name = it) }, t("wk.activity_name_ph"), KeyboardType.Text)
        Spacer(Modifier.height(14.dp))
        Lbl(t("wk.cardio_kind"))
        Spacer(Modifier.height(8.dp))
        Pills(kinds, type.sport, title = { Sport.from(it).label() }) { type = type.copy(sport = it) }
        Spacer(Modifier.height(14.dp))
        Lbl(t("pe.color"))
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            T.cardioColors.forEach { c ->
                Box(
                    Modifier.size(30.dp).clip(CircleShape).background(hexColor(c))
                        .border(if (type.color == c) 2.dp else 0.dp, T.txt, CircleShape)
                        .clickable { type = type.copy(color = c) }
                )
            }
        }
        Spacer(Modifier.height(18.dp))
        BigButton(if (isNew) t("add") else t("save")) {
            var ct = type
            if (ct.name.trim().isEmpty()) ct = ct.copy(name = Sport.from(ct.sport).label())
            store.commitCardioType(ct); toast.show(t("wk.cardio_saved")); onClose()
        }
        if (!isNew) {
            Spacer(Modifier.height(10.dp))
            Text(t("delete"), color = T.red, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp).clip(RoundedCornerShape(T.radiusS))
                    .border(1.dp, T.red.copy(alpha = 0.4f), RoundedCornerShape(T.radiusS))
                    .clickable { store.deleteCardioType(type.id); toast.show(t("wk.cardio_deleted")); onClose() }
                    .padding(vertical = 14.dp))
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun Pills(options: List<String>, selected: String, title: (String) -> String, onSelect: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        options.forEach { opt ->
            val on = opt == selected
            Text(
                title(opt), color = if (on) T.bg else T.txt, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(if (on) T.acc else T.c2)
                    .border(1.dp, if (on) Color.Transparent else T.brd, RoundedCornerShape(10.dp))
                    .clickable { onSelect(opt) }.padding(vertical = 9.dp, horizontal = 14.dp)
            )
        }
    }
}

// MARK: - Session editor (edit / delete a past session)
@Composable
fun SessionEditorDialog(initial: WorkoutSession, onClose: () -> Unit) {
    val store = LocalStore.current
    var s by remember { mutableStateOf(initial) }
    DialogShell(onClose) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(t("wk.edit_session").uppercase(), color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("${s.planName} · ${s.date}", color = T.sub, fontSize = 11.sp)
            }
            Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
        }
        Spacer(Modifier.height(14.dp))
        // Internal-load fields
        Lbl(t("load.title")); Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { Field(t("wk.duration"), s.durationMin?.toString() ?: "", { s = s.copy(durationMin = it.toIntOrNull()) }, "—") }
            Box(Modifier.weight(1f)) { Field(t("wk.rpe"), s.rpe?.toString() ?: "", { s = s.copy(rpe = it.toIntOrNull()) }, "—") }
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { Field(t("wk.avg_hr"), s.avgHR?.toString() ?: "", { s = s.copy(avgHR = it.toIntOrNull()) }, "—") }
            Box(Modifier.weight(1f)) { Field(t("wk.rmssd"), s.rmssd?.let { trimNum(it) } ?: "", { s = s.copy(rmssd = if (it.isEmpty()) null else pf(it)) }, "—", KeyboardType.Decimal) }
        }
        Spacer(Modifier.height(14.dp))
        // Per-exercise set editing
        s.exercises.forEachIndexed { ei, ex ->
            Text(ex.name, color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            ex.sets.forEachIndexed { si, set ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${t("wk.reps")} ${si + 1}", color = T.sub, fontSize = 11.sp, modifier = Modifier.width(54.dp))
                    SmallNumField(set.reps, { v -> s = updateSet(s, ei, si) { it.copy(reps = v) } }, placeholder = t("wk.reps"))
                    Text("×", color = T.sub)
                    SmallNumField(set.weight, { v -> s = updateSet(s, ei, si) { it.copy(weight = v) } }, placeholder = "kg")
                }
                Spacer(Modifier.height(6.dp))
            }
            Spacer(Modifier.height(8.dp))
        }
        Spacer(Modifier.height(6.dp))
        BigButton(t("save")) { store.updateSession(s); onClose() }
        Spacer(Modifier.height(10.dp))
        Text(t("wk.del_session"), color = T.red, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(T.radiusS))
                .border(1.dp, T.red.copy(alpha = 0.4f), RoundedCornerShape(T.radiusS))
                .clickable { store.deleteSession(s.id); onClose() }.padding(vertical = 13.dp))
    }
}

private fun updateSet(s: WorkoutSession, ei: Int, si: Int, transform: (SetEntry) -> SetEntry): WorkoutSession {
    val exs = s.exercises.toMutableList()
    val ex = exs[ei]
    val sets = ex.sets.toMutableList()
    sets[si] = transform(sets[si])
    exs[ei] = ex.copy(sets = sets)
    return s.copy(exercises = exs)
}

// MARK: - Cardio activities grid section (used inside the workout screen)
@Composable
fun CardioSection(onLog: (CardioType) -> Unit, onEdit: (CardioType) -> Unit, onNew: () -> Unit) {
    val store = LocalStore.current
    val tap = rememberTap()
    Row(verticalAlignment = Alignment.CenterVertically) {
        Lbl(t("wk.cardio_types"), modifier = Modifier.weight(1f))
        Row(
            Modifier.clip(RoundedCornerShape(10.dp)).background(T.blue.copy(alpha = 0.07f))
                .border(1.dp, T.blue, RoundedCornerShape(10.dp))
                .clickable { tap(); onNew() }.padding(vertical = 8.dp, horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(t("wk.add_cardio").uppercase(), color = T.blue, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
    }
    val items: List<CardioType?> = store.cardioTypes.toList() + listOf(null)
    val rows = (items.size + 1) / 2
    for (r in 0 until rows) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(11.dp)) {
            for (c in 0 until 2) {
                val idx = r * 2 + c
                Box(Modifier.weight(1f)) {
                    if (idx < items.size) {
                        val ct = items[idx]
                        if (ct != null) CardioCard(ct, onLog, onEdit) else CardioAddCard(onNew)
                    }
                }
            }
        }
    }
}

@Composable
private fun CardioCard(ct: CardioType, onLog: (CardioType) -> Unit, onEdit: (CardioType) -> Unit) {
    val tap = rememberTap()
    val pc = hexColor(ct.color)
    Box {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radius)).background(T.c1)
                .border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .clickable { tap(); onLog(ct) }.padding(vertical = 15.dp, horizontal = 14.dp)
        ) {
            Text(t("wk.cardio").uppercase(), color = pc, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp)
            Spacer(Modifier.height(10.dp))
            Text(ct.name.uppercase(), color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Spacer(Modifier.height(3.dp))
            Text(ct.sportType.label(), color = T.sub, fontSize = 10.sp)
        }
        Icon(Icons.Filled.Edit, "edit",
            tint = T.sub, modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(18.dp).clickable { tap(); onEdit(ct) })
    }
}

@Composable
private fun CardioAddCard(onNew: () -> Unit) {
    val tap = rememberTap()
    Column(
        Modifier.fillMaxWidth().heightIn(min = 104.dp).clip(RoundedCornerShape(T.radius))
            .background(T.c1.copy(alpha = 0.5f)).border(1.dp, T.brd2, RoundedCornerShape(T.radius))
            .clickable { tap(); onNew() }.padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
    ) {
        Text(t("wk.new_cardio"), color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
    }
}
