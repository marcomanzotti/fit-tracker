package com.marco.fittracker.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marco.fittracker.data.BodyEntry
import com.marco.fittracker.data.fmtShort
import com.marco.fittracker.data.measureFields
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum

@Composable
fun BodyScreen() {
    val store = LocalStore.current
    val toast = LocalToast.current
    val context = LocalContext.current

    var weightInput by remember { mutableStateOf("") }
    var sleepInput by remember { mutableStateOf("") }
    var bfInput by remember { mutableStateOf("") }
    val measInputs = remember { mutableStateMapOf<String, String>() }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            val text = readImport(context, uri)
            toast.show(if (text != null && store.importText(text)) "Dati importati" else "File non valido")
        } else toast.show("Importazione annullata")
    }

    val lw = store.lastWeight
    val bmi = store.bmi(lw)
    val cat = bmiCategory(bmi)
    val bl = store.bodyLatest
    val navy = store.bfNavy(bl?.waist, bl?.neck)
    val bf = bl?.bfManual ?: navy
    val lean = bf?.let { Math.round(lw * (1 - it / 100) * 10) / 10.0 }
    val fat = bf?.let { Math.round(lw * it / 100 * 10) / 10.0 }

    // Check-in
    Card {
        Lbl("Check-in · ${today()}", T.acc2)
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

    // Analysis
    Card {
        Lbl("Analisi corporea", T.acc2)
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            RowScopeStatTile("BMI", trimNum(bmi), valueColor = cat.second, note = cat.first, modifier = Modifier.weight(1f))
            RowScopeStatTile("Grasso", bf?.let { trimNum(it) } ?: "—", if (bf != null) "%" else null, valueColor = T.red, note = if (bf != null) "goal ${trimNum(store.prefs.goalBF)}%" else "—", modifier = Modifier.weight(1f))
            RowScopeStatTile("Magra", lean?.let { trimNum(it) } ?: "—", if (lean != null) "kg" else null, valueColor = T.blue, note = if (fat != null) "${trimNum(fat)}kg grasso" else "—", modifier = Modifier.weight(1f))
        }
        if (bf != null && lean != null && fat != null) {
            Spacer(Modifier.height(12.dp))
            Row {
                Text("Grasso ${trimNum(fat)} kg", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Text("Magra ${trimNum(lean)} kg", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(6.dp))
            Bar(minOf(1.0, bf / 100), gradient = listOf(T.red, T.acc2), height = 9)
        }
        Spacer(Modifier.height(12.dp))
        Text("GRASSO % · MANUALE O NAVY (COLLO + VITA)", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) {
                InputField(bfInput, { bfInput = it }, if (navy != null) "Navy: ${trimNum(navy)}%" else "18,5")
            }
            Box(Modifier.width(90.dp)) {
                FilledButton("Salva") {
                    val v = pf(bfInput)
                    if (v in 1.0..60.0) { store.saveBodyFat(v); bfInput = ""; toast.show("Grasso % salvato") }
                }
            }
        }
        if (navy != null) {
            Spacer(Modifier.height(8.dp))
            Text("Navy: ${trimNum(navy)}% · collo ${bl?.neck?.let { trimNum(it) } ?: "?"} · vita ${bl?.waist?.let { trimNum(it) } ?: "?"} cm", color = T.sub, fontSize = 10.sp)
        }
    }

    // Measurements
    Card {
        Lbl("Misurazioni settimanali", T.acc2)
        Spacer(Modifier.height(10.dp))
        measureFields.chunked(2).forEach { rowFields ->
            Row(Modifier.fillMaxWidth().padding(bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                rowFields.forEach { m ->
                    Box(Modifier.weight(1f)) { MeasureTile(m.key, m.label, bl, measInputs) }
                }
                if (rowFields.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        FilledButton("Salva misurazioni") {
            val vals = HashMap<String, Double>()
            for (m in measureFields) { val v = pf(measInputs[m.key] ?: ""); if (v > 0) vals[m.key] = v }
            if (vals.isNotEmpty()) { store.saveMeasurements(vals); measInputs.clear(); toast.show("Misurazioni salvate") }
        }
    }

    // Charts
    val bw = store.body.sortedBy { it.date }
    if (bw.size > 1) {
        Card {
            Lbl("Tutte le misurazioni")
            Spacer(Modifier.height(8.dp))
            val series = measureFields.map { m -> Series(m.label, hexColor(m.color), bw.map { it.value(m.key) }) }
            LineChart(xLabels = bw.map { fmtShort(it.date) }, series = series, heightDp = 205)
            ChartLegend(series)
        }
        measureFields.filter { f -> bw.count { it.value(f.key) != null } >= 2 }.forEach { m ->
            Card {
                Lbl(m.label, hexColor(m.color))
                Spacer(Modifier.height(8.dp))
                LineChart(
                    xLabels = bw.filter { it.value(m.key) != null }.map { fmtShort(it.date) },
                    series = listOf(Series(m.label, hexColor(m.color), bw.filter { it.value(m.key) != null }.map { it.value(m.key) })),
                    heightDp = 120, fill = true
                )
            }
        }
    }

    // Backup
    Card {
        Lbl("Backup dati")
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GhostButton("Esporta JSON") { shareExport(context, store) }
            GhostButton("Importa JSON") { importLauncher.launch("application/json") }
        }
    }
}

@Composable
private fun MeasureTile(key: String, label: String, bl: BodyEntry?, measInputs: androidx.compose.runtime.snapshots.SnapshotStateMap<String, String>) {
    val store = LocalStore.current
    val cur = bl?.value(key)
    val prev = store.bodyPrev?.value(key)
    val diff = if (cur != null && prev != null) Math.round((cur - prev) * 10) / 10.0 else null
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c2)
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS)).padding(vertical = 13.dp, horizontal = 12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
            Spacer(Modifier.weight(1f))
            if (cur != null) Text("cm", color = T.sub, fontSize = 10.sp)
        }
        Spacer(Modifier.height(8.dp))
        BasicTextField(
            value = measInputs[key] ?: "", onValueChange = { measInputs[key] = it },
            textStyle = TextStyle(color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.Medium), cursorBrush = SolidColor(T.acc),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(T.c1).border(1.dp, T.brd, RoundedCornerShape(8.dp)).padding(vertical = 9.dp, horizontal = 11.dp),
            decorationBox = { inner -> if ((measInputs[key] ?: "").isEmpty()) Text(cur?.let { trimNum(it) } ?: "–", color = T.sub, fontSize = 15.sp); inner() }
        )
        if (cur != null) {
            Spacer(Modifier.height(7.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(trimNum(cur), color = T.txt, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(5.dp))
                Text("cm", color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
            if (diff != null) {
                Spacer(Modifier.height(4.dp))
                val txt = if (diff == 0.0) "stabile" else "${if (diff > 0) "+" else ""}${trimNum(diff)} cm"
                Text(txt, color = if (diff == 0.0) T.sub else if (diff < 0) T.good else T.acc2, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        } else {
            Spacer(Modifier.height(8.dp))
            Text("Nessun dato", color = T.sub, fontSize = 11.sp)
        }
    }
}
