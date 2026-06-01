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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.marco.fittracker.data.Sport
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.t
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// Shared rest-day icon (mirrors the iOS moon/zzz glyph).
val restIcon: ImageVector = Icons.Filled.Bedtime

fun sportIcon(s: Sport): ImageVector = when (s) {
    Sport.STRENGTH -> Icons.Filled.FitnessCenter
    Sport.RUNNING -> Icons.Filled.DirectionsRun
    Sport.SWIMMING -> Icons.Filled.Pool
    Sport.CYCLING -> Icons.Filled.DirectionsBike
    Sport.WALKING -> Icons.Filled.DirectionsWalk
    Sport.OTHER -> Icons.Filled.Bolt
}

// MARK: - Day action picker
// Tapping an empty day on the "this week" strip opens this to log, after the
// fact, what was done that day: a strength day, a cardio activity, or rest.
// Picking a workout pre-fills it from the last time and opens the editor.
@Composable
fun DayPickerDialog(date: String, openEditor: (WorkoutSession) -> Unit, onClose: () -> Unit) {
    val store = LocalStore.current
    val tap = rememberTap()
    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier.fillMaxWidth().heightIn(max = 640.dp).clip(RoundedCornerShape(T.radius))
                .background(T.bg).border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .padding(18.dp).verticalScroll(rememberScrollState())
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(t("day.title").uppercase(), color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(prettyDate(date), color = T.sub, fontSize = 11.sp)
                }
                Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
            }
            Spacer(Modifier.height(12.dp))
            Text(t("day.hint"), color = T.sub, fontSize = 12.sp, lineHeight = 17.sp)
            Spacer(Modifier.height(14.dp))

            // Rest toggle
            val isRest = store.isRestDay(date)
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c1)
                    .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
                    .clickable { tap(); store.toggleRestDay(date); onClose() }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(38.dp).clip(RoundedCornerShape(10.dp)).background(T.restFill), contentAlignment = Alignment.Center) {
                    Icon(restIcon, null, tint = T.bg, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(12.dp))
                Text(if (isRest) t("day.clear_rest") else t("day.mark_rest"), color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Icon(if (isRest) Icons.Filled.CheckCircle else Icons.AutoMirrored.Filled.KeyboardArrowRight, null,
                    tint = if (isRest) T.good else T.sub, modifier = Modifier.size(20.dp))
            }

            if (store.plans.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Lbl(t("wk.select_day"))
                Spacer(Modifier.height(8.dp))
                store.plans.forEach { p ->
                    PickRow(p.name, p.sub, p.color, Icons.Filled.FitnessCenter) {
                        val s = store.quickInsertSession(p, date); onClose(); openEditor(s)
                    }
                }
            }
            if (store.cardioTypes.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Lbl(t("wk.cardio_types"))
                Spacer(Modifier.height(8.dp))
                store.cardioTypes.forEach { c ->
                    PickRow(c.name, c.sportType.label(), c.color, sportIcon(c.sportType)) {
                        val s = store.quickInsertCardio(c, date); onClose(); openEditor(s)
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
private fun PickRow(name: String, sub: String, color: String, icon: ImageVector, onClick: () -> Unit) {
    val tap = rememberTap()
    val pc = hexColor(color)
    Row(
        Modifier.fillMaxWidth().clickable { tap(); onClick() }.padding(vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(38.dp).clip(RoundedCornerShape(10.dp)).background(pc.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = pc, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(name, color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            if (sub.isNotEmpty()) Text(sub, color = T.sub, fontSize = 11.sp, maxLines = 1)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = T.sub, modifier = Modifier.size(18.dp))
    }
}

private fun prettyDate(date: String): String = runCatching {
    val d = LocalDate.parse(date)
    val loc = if (com.marco.fittracker.data.L.lang == "en") Locale.ENGLISH else Locale.ITALIAN
    d.format(DateTimeFormatter.ofPattern("EEEE d MMMM", loc)).replaceFirstChar { it.uppercase() }
}.getOrDefault(date)
