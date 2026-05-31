package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marco.fittracker.data.Prefs
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.fmtShort
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.trimNum

@Composable
fun StatsScreen() {
    val store = LocalStore.current
    var statsTab by remember { mutableStateOf("overview") }
    val tabs = listOf("overview" to "Overview", "pr" to "Record", "prog" to "Progressi", "storico" to "Storico")
    val tap = rememberTap()

    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        tabs.forEach { (key, label) ->
            val sel = statsTab == key
            Text(
                label.uppercase(), color = if (sel) T.bg else T.sub, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp,
                modifier = Modifier.clip(CircleShape).background(if (sel) T.acc else T.mut).clickable { tap(); statsTab = key }.padding(vertical = 8.dp, horizontal = 16.dp)
            )
        }
    }

    when (statsTab) {
        "overview" -> Overview()
        "pr" -> Records()
        "prog" -> Progress()
        else -> History()
    }
}

@Composable
private fun Overview() {
    val store = LocalStore.current
    val ws = store.sortedDaily
    val d90 = ws.takeLast(90)
    val withW = d90.filter { it.weight != null }
    val sleepD = d90.filter { it.sleep != null }
    val bf = store.currentBF

    if (withW.size > 1) {
        Card {
            Lbl("Peso · 90 giorni"); Spacer(Modifier.height(8.dp))
            LineChart(withW.map { fmtShort(it.date) }, listOf(Series("Peso", T.acc, withW.map { it.weight })), fill = true)
        }
    }
    if (sleepD.size > 1) {
        Card {
            Lbl("Sleep score"); Spacer(Modifier.height(8.dp))
            LineChart(sleepD.map { fmtShort(it.date) }, listOf(Series("Sleep", T.blue, sleepD.map { it.sleep?.toDouble() })), fill = true, yMin = 0.0, yMax = 100.0)
        }
    }
    if (withW.size > 1) {
        Card {
            Lbl("BMI nel tempo"); Spacer(Modifier.height(8.dp))
            LineChart(withW.map { fmtShort(it.date) }, listOf(Series("BMI", hexColor("b08fff"), withW.map { store.bmi(it.weight ?: 0.0) })), heightDp = 120)
        }
        if (bf != null) {
            Card {
                Lbl("Composizione corporea"); Spacer(Modifier.height(8.dp))
                val series = listOf(
                    Series("Magra", T.blue, withW.map { Math.round((it.weight ?: 0.0) * (1 - bf / 100) * 10) / 10.0 }),
                    Series("Grasso", T.red, withW.map { Math.round((it.weight ?: 0.0) * bf / 100 * 10) / 10.0 })
                )
                LineChart(withW.map { fmtShort(it.date) }, series)
                ChartLegend(series)
            }
        }
    }
    if (withW.size < 2) {
        Card { EmptyBox("Nessun dato", "Registra peso e sleep per 2+ giorni per vedere i grafici.") }
    }
    ProfileCard()
}

@Composable
private fun Records() {
    val store = LocalStore.current
    val prs = store.allPRs()
    val names = store.allExerciseNames()
    Card {
        Lbl("I tuoi massimali"); Spacer(Modifier.height(4.dp))
        if (names.isEmpty()) Text("Crea un giorno con esercizi per tracciare i record.", color = T.sub, fontSize = 12.sp, modifier = Modifier.padding(vertical = 8.dp))
        names.forEach { (_, name) ->
            val pr = prs[name]
            DividerRow {
                Column(Modifier.weight(1f)) {
                    Text(name, color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    pr?.date?.let { Text(it, color = T.sub, fontSize = 10.sp) }
                }
                Text(if ((pr?.weight ?: 0.0) > 0) "${trimNum(pr!!.weight)} kg" else "—", color = T.acc, fontSize = 25.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun Progress() {
    val store = LocalStore.current
    var selEx by remember { mutableStateOf("") }
    var expanded by remember { mutableStateOf(false) }
    val tap = rememberTap()

    Card {
        Lbl("Seleziona esercizio"); Spacer(Modifier.height(8.dp))
        Box {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c2).border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
                    .clickable { tap(); expanded = true }.padding(vertical = 12.dp, horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(if (selEx.isEmpty()) "— Scegli —" else selEx, color = if (selEx.isEmpty()) T.sub else T.txt, fontSize = 14.sp, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.KeyboardArrowDown, null, tint = T.sub)
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, modifier = Modifier.background(T.c2)) {
                store.plans.forEach { p ->
                    p.exercises.forEach { ex ->
                        DropdownMenuItem(text = { Text("${p.name} · ${ex.name}", color = T.txt, fontSize = 13.sp) }, onClick = { selEx = ex.name; expanded = false })
                    }
                }
            }
        }
    }

    if (selEx.isNotEmpty()) {
        val data = store.exerciseHistory(selEx)
        if (data.isEmpty()) {
            Card { EmptyBox("Nessun dato", "Registra una sessione con questo esercizio.") }
        } else {
            Card {
                Lbl("Peso massimo per sessione"); Spacer(Modifier.height(8.dp))
                LineChart(data.map { it.date }, listOf(Series("Max", T.acc, data.map { it.maxW })), points = true)
            }
            Card {
                Lbl("Volume totale per sessione"); Spacer(Modifier.height(8.dp))
                BarChart(data.map { it.date }, data.map { it.vol })
            }
            if (data.size >= 2) {
                val f = data.first(); val l = data.last()
                Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    RowScopeStatTile("Prima", trimNum(f.maxW), "kg", valueColor = T.sub, modifier = Modifier.weight(1f))
                    RowScopeStatTile("Ultima", trimNum(l.maxW), "kg", modifier = Modifier.weight(1f))
                    RowScopeStatTile("Delta", "${if (l.maxW - f.maxW >= 0) "+" else ""}${trimNum(l.maxW - f.maxW)}", "kg", valueColor = T.acc, modifier = Modifier.weight(1f))
                }
            }
        }
    } else {
        Card { EmptyBox("Progressi", "Seleziona un esercizio per vedere la progressione.") }
    }
}

@Composable
private fun History() {
    val store = LocalStore.current
    var openId by remember { mutableStateOf<String?>(null) }
    val sorted = store.sessions.sortedByDescending { it.date }
    if (sorted.isEmpty()) {
        Card { EmptyBox("Storico vuoto", "Nessun allenamento registrato.") }
    } else {
        sorted.forEach { s -> HistoryCard(s, openId == s.id) { openId = if (openId == s.id) null else s.id } }
    }
}

@Composable
private fun HistoryCard(s: WorkoutSession, isOpen: Boolean, onToggle: () -> Unit) {
    val store = LocalStore.current
    val tap = rememberTap()
    Card {
        Row(Modifier.fillMaxWidth().clickable { tap(); onToggle() }, verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(s.planName.uppercase(), color = hexColor(s.planColor), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(3.dp))
                Text("${s.date} · ${s.totalSets} serie · ~${store.estimateCalories(s)} kcal", color = T.sub, fontSize = 10.sp)
            }
            Column(horizontalAlignment = Alignment.End) {
                Badge("${s.volume.toInt()} kg")
                Spacer(Modifier.height(5.dp))
                Icon(if (isOpen) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown, null, tint = T.sub)
            }
        }
        if (isOpen) {
            Spacer(Modifier.height(12.dp))
            Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
            Spacer(Modifier.height(12.dp))
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                s.exercises.forEach { ex ->
                    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(ex.name, color = T.txt, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        ChipsFlow(ex.sets.mapIndexed { idx, st -> "S${idx + 1}: ${if (st.weight.isEmpty()) "?" else st.weight}×${if (st.reps.isEmpty()) "?" else st.reps}" }, color = T.sub, bg = T.mut)
                        if (ex.notes.isNotEmpty()) Text(ex.notes, color = T.sub, fontSize = 11.sp)
                        Text("Vol ${ex.volume.toInt()} · Max ${trimNum(ex.maxWeight)} kg", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

// MARK: - Editable profile / goals
@Composable
private fun ProfileCard() {
    val store = LocalStore.current
    val toast = LocalToast.current
    var goalW by remember { mutableStateOf(trimNum(store.prefs.goalWeight)) }
    var goalBF by remember { mutableStateOf(trimNum(store.prefs.goalBF)) }
    var startW by remember { mutableStateOf(trimNum(store.prefs.startWeight)) }
    var height by remember { mutableStateOf(trimNum(store.prefs.height)) }
    var timer by remember { mutableStateOf("${store.prefs.timer}") }

    Card {
        Lbl("Obiettivi & profilo", T.acc2); Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LabeledField("PESO OBIETTIVO", "80", goalW, { goalW = it }, Modifier.weight(1f))
            LabeledField("GRASSO OBIETTIVO %", "15", goalBF, { goalBF = it }, Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LabeledField("PESO INIZIALE", "88", startW, { startW = it }, Modifier.weight(1f))
            LabeledField("ALTEZZA (M)", "1.85", height, { height = it }, Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        LabeledField("RECUPERO TIMER (S)", "60", timer, { timer = it })
        Spacer(Modifier.height(12.dp))
        FilledButton("Salva profilo") {
            var p = store.prefs
            if (pf(goalW) > 0) p = p.copy(goalWeight = pf(goalW))
            if (pf(goalBF) > 0) p = p.copy(goalBF = pf(goalBF))
            if (pf(startW) > 0) p = p.copy(startWeight = pf(startW))
            if (pf(height) > 0.5) p = p.copy(height = pf(height))
            if (pf(timer) > 0) p = p.copy(timer = pf(timer).toInt())
            store.updatePrefs(p); toast.show("Profilo salvato")
        }
    }
}
