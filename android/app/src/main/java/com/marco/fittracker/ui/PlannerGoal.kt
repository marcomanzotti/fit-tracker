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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.marco.fittracker.data.L
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.t
import com.marco.fittracker.data.trimNum
import java.time.LocalDate

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun GoalPillRow(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        options.forEach { (value, label) ->
            val on = value == selected
            Text(
                label, color = if (on) T.bg else T.txt, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(if (on) T.acc else T.c2)
                    .border(1.dp, if (on) Color.Transparent else T.brd, RoundedCornerShape(10.dp))
                    .clickable { onSelect(value) }.padding(vertical = 9.dp, horizontal = 14.dp)
            )
        }
    }
}

@Composable
private fun GoalField(label: String, value: String, onChange: (String) -> Unit, ph: String) {
    Column(Modifier.fillMaxWidth()) {
        Lbl(label)
        Spacer(Modifier.height(7.dp))
        InputField(value, onChange, ph, KeyboardType.Decimal)
    }
}

// MARK: - Goal editor (always reachable from Home)
@Composable
fun GoalEditorDialog(onClose: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val p = store.prefs
    var goalMode by remember { mutableStateOf(p.goal.raw) }
    var startW by remember { mutableStateOf(trimNum(p.startWeight)) }
    var goalW by remember { mutableStateOf(trimNum(p.goalWeight)) }
    var goalBF by remember { mutableStateOf(trimNum(p.goalBF)) }
    var rate by remember { mutableStateOf(p.weeklyRate?.let { trimNum(it) } ?: "") }

    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier.fillMaxWidth().heightIn(max = 620.dp).clip(RoundedCornerShape(T.radius))
                .background(T.bg).border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .padding(18.dp).verticalScroll(rememberScrollState())
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("goal.title").uppercase(), color = T.txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(6.dp))
                InfoButton("goal")
                Spacer(Modifier.weight(1f))
                Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
            }
            Spacer(Modifier.height(12.dp))
            Text(t("goal.hint"), color = T.sub, fontSize = 12.sp, lineHeight = 17.sp)
            Spacer(Modifier.height(14.dp))

            Lbl(t("ob.goal_mode")); Spacer(Modifier.height(8.dp))
            GoalPillRow(listOf("cut" to t("nut.cut"), "maintain" to t("nut.maintain"), "bulk" to t("nut.bulk")), goalMode) { goalMode = it }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { GoalField(t("goal.start_weight"), startW, { startW = it }, "88") }
                Box(Modifier.weight(1f)) { GoalField(t("ob.goal_weight"), goalW, { goalW = it }, "80") }
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { GoalField(t("pc.goal_bf"), goalBF, { goalBF = it }, "15") }
                Box(Modifier.weight(1f)) { GoalField(t("ob.rate"), rate, { rate = it }, "-0.5") }
            }
            Spacer(Modifier.height(18.dp))
            BigButton(t("save")) {
                val np = store.prefs.copy(
                    goalMode = goalMode,
                    startWeight = pf(startW).takeIf { it > 0 } ?: store.prefs.startWeight,
                    goalWeight = pf(goalW).takeIf { it > 0 } ?: store.prefs.goalWeight,
                    goalBF = pf(goalBF).takeIf { it > 0 } ?: store.prefs.goalBF,
                    weeklyRate = rate.ifBlank { null }?.let { pf(it) }
                )
                store.updatePrefs(np)
                toast.show(t("goal.saved"))
                onClose()
            }
        }
    }
}

// MARK: - Weekly planner dialog (assign each weekday a plan / cardio / rest)
@Composable
fun WeeklyPlanDialog(onClose: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val dayNames = if (L.lang == "en")
        listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    else listOf("Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica")
    val todayMon = (LocalDate.now().dayOfWeek.value - 1).coerceIn(0, 6)

    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier.fillMaxWidth().heightIn(max = 640.dp).clip(RoundedCornerShape(T.radius))
                .background(T.bg).border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .padding(18.dp).verticalScroll(rememberScrollState())
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("plan.week").uppercase(), color = T.txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(6.dp))
                InfoButton("weekplan")
                Spacer(Modifier.weight(1f))
                Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
            }
            Spacer(Modifier.height(12.dp))
            Text(t("plan.week_hint"), color = T.sub, fontSize = 12.sp, lineHeight = 17.sp)
            Spacer(Modifier.height(14.dp))

            for (wd in 0 until 7) {
                DayScheduleRow(wd, dayNames[wd], wd == todayMon)
                if (wd < 6) { Spacer(Modifier.height(4.dp)); Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd)); Spacer(Modifier.height(4.dp)) }
            }

            if (store.prefs.hasSchedule) {
                Spacer(Modifier.height(16.dp))
                Box(Modifier.fillMaxWidth().heightIn(min = 46.dp).clip(RoundedCornerShape(T.radiusS))
                    .border(1.dp, T.red.copy(alpha = 0.4f), RoundedCornerShape(T.radiusS))
                    .clickable { store.clearSchedule(); toast.show(t("plan.saved")) }
                    .padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                    Text(t("plan.clear"), color = T.red, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun DayScheduleRow(wd: Int, dayName: String, isToday: Boolean) {
    val store = LocalStore.current
    var open by remember { mutableStateOf(false) }
    val cur = store.prefs.weekSchedule[wd]
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(dayName, color = if (isToday) T.acc else T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            if (isToday) Text(t("plan.today").uppercase(), color = T.acc, fontSize = 8.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
        Box {
            Row(
                Modifier.clip(RoundedCornerShape(9.dp)).background(T.c2).border(1.dp, T.brd, RoundedCornerShape(9.dp))
                    .clickable { open = true }.padding(vertical = 8.dp, horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(9.dp).clip(CircleShape).background(slotColor(store, cur)))
                Spacer(Modifier.width(6.dp))
                Text(slotLabel(store, cur), color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                DropdownMenuItem(text = { Text(t("plan.auto")) }, onClick = { store.setSchedule(wd, ""); open = false })
                DropdownMenuItem(text = { Text(t("plan.rest")) }, onClick = { store.setSchedule(wd, "rest"); open = false })
                store.plans.forEach { p ->
                    DropdownMenuItem(text = { Text(p.name) }, onClick = { store.setSchedule(wd, p.id); open = false })
                }
                store.cardioTypes.forEach { c ->
                    DropdownMenuItem(text = { Text(c.name) }, onClick = { store.setSchedule(wd, c.id); open = false })
                }
            }
        }
    }
}

private fun slotLabel(store: com.marco.fittracker.data.Store, id: String): String = when {
    id.isEmpty() -> t("plan.auto")
    id == "rest" -> t("plan.rest")
    else -> store.plans.firstOrNull { it.id == id }?.name
        ?: store.cardioTypes.firstOrNull { it.id == id }?.name ?: t("plan.auto")
}
private fun slotColor(store: com.marco.fittracker.data.Store, id: String): Color = when {
    id.isEmpty() -> T.brd2
    id == "rest" -> T.restFill
    else -> store.plans.firstOrNull { it.id == id }?.let { hexColor(it.color) }
        ?: store.cardioTypes.firstOrNull { it.id == id }?.let { hexColor(it.color) } ?: T.brd2
}

// MARK: - Compact weekly-plan card for Home
@Composable
fun WeeklyPlanCard() {
    val store = LocalStore.current
    var editing by remember { mutableStateOf(false) }
    val sched = store.prefs.weekSchedule
    val todayMon = (LocalDate.now().dayOfWeek.value - 1).coerceIn(0, 6)
    val heads = L.weekHeaders
    Card(modifier = Modifier.clickable { editing = true }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("plan.week"), T.acc2)
            Spacer(Modifier.width(5.dp))
            InfoButton("weekplan", T.acc2)
            Spacer(Modifier.weight(1f))
            Text((if (store.prefs.hasSchedule) t("plan.scheduled") else t("plan.rotation")).uppercase(),
                color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = T.sub, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (wd in 0 until 7) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(heads[wd], color = if (wd == todayMon) T.acc else T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(6.dp))
                    Box(
                        Modifier.fillMaxWidth().height(30.dp).clip(RoundedCornerShape(8.dp))
                            .background(slotChipColor(store, sched[wd]))
                            .border(1.5.dp, if (wd == todayMon) T.acc else Color.Transparent, RoundedCornerShape(8.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (sched[wd] == "rest") Icon(restIcon, null, tint = T.bg, modifier = Modifier.size(13.dp))
                    }
                }
            }
        }
    }
    if (editing) WeeklyPlanDialog { editing = false }
}

private fun slotChipColor(store: com.marco.fittracker.data.Store, id: String): Color = when {
    id.isEmpty() -> T.c3
    id == "rest" -> T.restFill
    else -> store.plans.firstOrNull { it.id == id }?.let { hexColor(it.color) }
        ?: store.cardioTypes.firstOrNull { it.id == id }?.let { hexColor(it.color) } ?: T.c3
}
