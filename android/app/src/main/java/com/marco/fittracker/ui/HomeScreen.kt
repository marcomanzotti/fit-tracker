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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.fmtShort
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum

fun bmiCategory(b: Double): Pair<String, Color> = when {
    b < 18.5 -> "Sottopeso" to T.blue
    b < 25 -> "Normopeso" to T.good
    b < 30 -> "Sovrappeso" to T.acc2
    else -> "Obeso" to T.red
}

@Composable
fun HomeScreen(onTab: (Tab) -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val context = LocalContext.current

    var weightInput by remember { mutableStateOf("") }
    var sleepInput by remember { mutableStateOf("") }

    val lw = store.lastWeight
    val bmi = store.bmi(lw)
    val cat = bmiCategory(bmi)
    val ws = store.sortedDaily.filter { it.weight != null }

    // Check-in
    if (!store.hasCheckedIn()) {
        Card(borderColor = T.acc.copy(alpha = 0.3f)) {
            Lbl("Check-in di oggi", T.acc2)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LabeledField("PESO (KG)", "87,5", weightInput, { weightInput = it }, Modifier.weight(1f))
                LabeledField("SLEEP (0-100)", "78", sleepInput, { sleepInput = it }, Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            FilledButton("Salva check-in") {
                val w = pf(weightInput); val s = pf(sleepInput)
                val hasW = w in 30.0..250.0; val hasS = s > 0 && s <= 100
                if (hasW || hasS) {
                    store.saveCheckIn(if (hasW) w else null, if (hasS) Math.round(s).toInt() else null)
                    weightInput = ""; sleepInput = ""; toast.show("Check-in salvato")
                }
            }
        }
    } else {
        val tw = store.daily.firstOrNull { it.date == today() }
        Card(accent = T.good) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("CHECK-IN COMPLETATO", color = T.good, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
                    Spacer(Modifier.height(3.dp))
                    val sleepStr = tw?.sleep?.let { " · Sleep $it/100" } ?: ""
                    Text("Peso ${trimNum(tw?.weight ?: store.lastWeight)} kg$sleepStr", color = T.sub, fontSize = 11.sp)
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    Text("${store.streak}", color = T.good, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(3.dp))
                    Text(if (store.streak == 1) "giorno" else "gg", color = T.sub, fontSize = 11.sp)
                }
            }
        }
    }

    // Key stats
    Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        RowScopeStatTile("Peso", trimNum(lw), "kg", note = "BMI ${trimNum(bmi)} · ${cat.first}", modifier = Modifier.weight(1f))
        RowScopeStatTile("Streak", "${store.streak}", valueColor = T.acc, note = if (store.streak == 1) "giorno" else "giorni", modifier = Modifier.weight(1f))
        RowScopeStatTile("Sessioni", "${store.sessions.size}", valueColor = T.blue, note = "totali", modifier = Modifier.weight(1f))
    }

    // Goals
    run {
        val p = store.prefs
        val wtPct = ((p.startWeight - lw) / maxOf(0.1, p.startWeight - p.goalWeight)).coerceIn(0.0, 1.0)
        val bf = store.currentBF
        val bfPct = bf?.let { ((it - p.goalBF) / maxOf(0.1, 35 - p.goalBF)).coerceIn(0.0, 1.0) }
        Card {
            Lbl("Obiettivi", T.acc2)
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(Modifier.weight(1f)) {
                    Row {
                        Text("Peso", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.weight(1f))
                        Text("${trimNum(lw)} → ${trimNum(p.goalWeight)} kg", color = T.acc, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.height(5.dp))
                    Bar(wtPct)
                    if (bf != null && bfPct != null) {
                        Spacer(Modifier.height(12.dp))
                        Row {
                            Text("Grasso", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
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

    // Next workout
    store.nextPlan()?.let { p ->
        val pc = hexColor(p.color)
        Card(accent = pc, modifier = Modifier.clickable { onTab(Tab.ALLENA) }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Lbl("Prossimo allenamento")
                    Spacer(Modifier.height(6.dp))
                    Text(p.name.uppercase(), color = pc, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(5.dp))
                    Text("${p.sub} · ${p.exercises.size} esercizi", color = T.sub, fontSize = 11.sp)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = T.sub)
            }
        }
    }

    // Weight chart
    if (ws.size > 1) {
        val data = ws.takeLast(14)
        Card {
            Lbl("Peso · ultimi 14 giorni")
            Spacer(Modifier.height(8.dp))
            LineChart(
                xLabels = data.map { fmtShort(it.date) },
                series = listOf(Series("Peso", T.acc, data.map { it.weight })),
                fill = true, points = true
            )
        }
    }

    // Recent PRs
    val prItems = store.allPRs().entries
        .filter { it.value.weight > 0 }
        .sortedByDescending { it.value.date ?: "" }
        .take(3)
    if (prItems.isNotEmpty()) {
        Card {
            Lbl("Record recenti")
            Spacer(Modifier.height(4.dp))
            prItems.forEach { (name, info) ->
                DividerRow {
                    Text(name, color = T.txt, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                    Text("${trimNum(info.weight)} kg", color = T.acc, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }

    // Week comparison
    run {
        val wk0 = store.weekStats(0)
        val wk1 = store.weekStats(1)
        val totalVol = store.sessions.sumOf { it.volume }
        Card {
            Lbl("Confronto settimane")
            Spacer(Modifier.height(4.dp))
            CompRow("Peso medio", wk0.avgWeight?.let { "${trimNum(it)} kg" } ?: "—", wk1.avgWeight?.let { "${trimNum(it)} prec." } ?: "—")
            CompRow("Allenamenti", "${wk0.sessions}", "${wk1.sessions} prec.")
            CompRow("Volume totale", "${totalVol.toInt()} kg", "lifetime")
        }
    }

    // Backup
    Row(
        Modifier.fillMaxWidth()
            .background(T.c1, RoundedCornerShape(T.radiusS))
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
            .padding(vertical = 10.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text("BACKUP", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
            Text("Salvataggio automatico locale", color = T.sub, fontSize = 10.sp)
        }
        GhostButton("Esporta dati") { shareExport(context, store) }
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
