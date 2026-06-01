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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marco.fittracker.data.DailyEntry
import com.marco.fittracker.data.L
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.fmtShort
import com.marco.fittracker.data.t
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum
import java.time.LocalDate

fun bmiCategory(b: Double): Pair<String, Color> = when {
    b < 18.5 -> t("bmi.under") to T.blue
    b < 25 -> t("bmi.normal") to T.good
    b < 30 -> t("bmi.over") to T.acc2
    else -> t("bmi.obese") to T.red
}

@Composable
fun HomeScreen(onTab: (Tab) -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val context = LocalContext.current

    var weightInput by remember { mutableStateOf("") }
    var sleepInput by remember { mutableStateOf("") }
    var editingGoal by remember { mutableStateOf(false) }

    val lw = store.lastWeight
    val bmi = store.bmi(lw)
    val cat = bmiCategory(bmi)

    // Check-in
    if (!store.hasCheckedIn()) {
        Card(borderColor = T.acc.copy(alpha = 0.3f)) {
            Lbl(t("home.checkin"), T.acc2)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LabeledField("${t("home.weight")} (KG)", "87,5", weightInput, { weightInput = it }, Modifier.weight(1f))
                if (store.prefs.sleepEnabled)
                    LabeledField("${t("home.sleep")} (0-100)", "78", sleepInput, { sleepInput = it }, Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            FilledButton(t("home.save_checkin")) {
                val w = pf(weightInput); val s = pf(sleepInput)
                val hasW = w in 30.0..250.0; val hasS = s > 0 && s <= 100
                if (hasW || hasS) {
                    store.saveCheckIn(if (hasW) w else null, if (hasS) Math.round(s).toInt() else null)
                    weightInput = ""; sleepInput = ""; toast.show(t("home.checkin_saved"))
                }
            }
        }
    } else {
        val tw = store.daily.firstOrNull { it.date == today() }
        Card(accent = T.good) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(t("home.checkin_done").uppercase(), color = T.good, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
                    Spacer(Modifier.height(3.dp))
                    val sleepStr = tw?.sleep?.let { " · ${t("home.sleep")} $it/100" } ?: ""
                    Text("${t("home.weight")} ${trimNum(tw?.weight ?: store.lastWeight)} kg$sleepStr", color = T.sub, fontSize = 11.sp)
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    Text("${store.streak}", color = T.good, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(3.dp))
                    Text(if (store.streak == 1) t("home.day") else t("home.days"), color = T.sub, fontSize = 11.sp)
                }
            }
        }
    }

    // Key stats
    Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        RowScopeStatTile(t("home.weight"), trimNum(lw), "kg", note = "BMI ${trimNum(bmi)} · ${cat.first}", info = "bmi", modifier = Modifier.weight(1f))
        RowScopeStatTile(t("home.streak"), "${store.streak}", valueColor = T.acc, note = if (store.streak == 1) t("home.day") else t("home.days"), info = "streak", modifier = Modifier.weight(1f))
        RowScopeStatTile(t("home.sessions"), "${store.sessions.size}", valueColor = T.blue, note = t("home.total"), modifier = Modifier.weight(1f))
    }

    // Sporty week-activity strip
    WeekStrip()

    // Next workout (schedule-aware: strength plan or cardio activity)
    store.nextUp()?.let { item ->
        val pc = hexColor(item.color)
        Card(accent = pc, modifier = Modifier.clickable { onTab(Tab.ALLENA) }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Lbl(t("home.next_workout"))
                        Spacer(Modifier.width(6.dp))
                        Text("· " + (if (store.prefs.hasSchedule) t("plan.scheduled") else t("plan.rotation")),
                            color = T.sub, fontSize = 8.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(item.name.uppercase(), color = pc, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    if (item.sub.isNotEmpty()) {
                        Spacer(Modifier.height(5.dp))
                        Text(item.sub + (if (item is com.marco.fittracker.data.Store.NextItem.Plan) " · ${item.plan.exercises.size} ${t("home.exercises")}" else ""),
                            color = T.sub, fontSize = 11.sp)
                    }
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = T.sub)
            }
        }
    }

    // Weekly plan
    WeeklyPlanCard()

    // Goals (locked; only changes via the Change Goal button)
    run {
        val p = store.prefs
        val denom = p.goalWeight - p.startWeight
        val wtPct = if (kotlin.math.abs(denom) < 0.1) 1.0 else ((lw - p.startWeight) / denom).coerceIn(0.0, 1.0)
        val bf = store.currentBF
        val bfPct = bf?.let { ((it - p.goalBF) / maxOf(0.1, 35 - p.goalBF)).coerceIn(0.0, 1.0) }
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Lbl(t("home.goals"), T.acc2)
                Spacer(Modifier.width(5.dp))
                InfoButton("goal", T.acc2)
                Spacer(Modifier.weight(1f))
                Text(t("goal.change").uppercase(), color = T.acc, fontSize = 9.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(T.acc.copy(alpha = 0.10f))
                        .border(1.dp, T.acc.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
                        .clickable { editingGoal = true }.padding(vertical = 6.dp, horizontal = 10.dp))
            }
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(Modifier.weight(1f)) {
                    Row {
                        Text(t("home.weight"), color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.weight(1f))
                        Text("${trimNum(lw)} → ${trimNum(p.goalWeight)} kg", color = T.acc, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.height(5.dp))
                    Bar(wtPct)
                    if (bf != null && bfPct != null) {
                        Spacer(Modifier.height(12.dp))
                        Row {
                            Text(t("home.fat"), color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.weight(1f))
                            Text("${trimNum(bf)}% → ${trimNum(p.goalBF)}%", color = T.red, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.height(5.dp))
                        Bar(maxOf(0.05, 1 - bfPct), gradient = listOf(T.red, T.acc))
                    }
                }
                GoalRing(wtPct, T.acc, 64)
            }
        }
    }

    // Scientific dashboard (visual + data, with info popups)
    ReadinessCard()
    LoadCard()
    LoadTrendCard()
    OverloadCard()
    NutritionCard()

    if (editingGoal) GoalEditorDialog { editingGoal = false }

    // Backup
    Row(
        Modifier.fillMaxWidth()
            .background(T.c1, RoundedCornerShape(T.radiusS))
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
            .padding(vertical = 10.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(t("home.backup").uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
            Text(t("home.backup_auto"), color = T.sub, fontSize = 10.sp)
        }
        GhostButton(t("home.export_data")) { shareExport(context, store) }
    }
}

// MARK: - Sporty week-activity strip (last 7 days colored by workout)
@Composable
fun WeekStrip() {
    val store = LocalStore.current
    val now = LocalDate.now()
    val days = (0..6).reversed().map { i ->
        val d = now.minusDays(i.toLong())
        Triple(L.days[(d.dayOfWeek.value - 1).coerceIn(0, 6)], d.toString(), d.toString() == today())
    }
    val trained = days.count { d -> store.sessions.any { it.date == d.second } }
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("home.week_activity"), T.acc2)
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.Bottom) {
                Text("$trained", color = T.acc, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(4.dp))
                Text("/ 7", color = T.sub, fontSize = 10.sp)
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            days.forEach { (label, ds, isToday) ->
                val sess = store.sessions.filter { it.date == ds }
                val color = sess.firstOrNull()?.let { hexColor(it.planColor) }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(label.uppercase(), color = if (isToday) T.acc else T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(6.dp))
                    Box(
                        Modifier.fillMaxWidth().height(42.dp)
                            .clip(RoundedCornerShape(11.dp))
                            .background(color ?: T.c2)
                            .border(1.dp, if (isToday) T.acc else if (color != null) Color.Transparent else T.brd, RoundedCornerShape(11.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (color != null) {
                            Text(if (sess.size > 1) "${sess.size}" else "", color = T.bg, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        } else {
                            Box(Modifier.size(4.dp).clip(RoundedCornerShape(2.dp)).background(T.brd2))
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun LabeledField(label: String, ph: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(label, color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        Spacer(Modifier.height(6.dp))
        InputField(value, onChange, ph)
    }
}

@Composable
fun DividerRow(content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    Column {
        Row(
            Modifier.fillMaxWidth().padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content
        )
        Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
    }
}

@Composable
private fun CompRow(label: String, a: String, b: String) {
    DividerRow {
        Text(label, color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Text(a, color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(80.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
        Text(b, color = T.sub, fontSize = 11.sp, modifier = Modifier.width(80.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
    }
}
