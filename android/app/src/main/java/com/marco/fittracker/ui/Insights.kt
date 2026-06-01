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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.marco.fittracker.data.GoalMode
import com.marco.fittracker.data.ProgKind
import com.marco.fittracker.data.TrendResult
import com.marco.fittracker.data.acwr
import com.marco.fittracker.data.adherence
import com.marco.fittracker.data.dailyLoadSeries
import com.marco.fittracker.data.energyAvailability
import com.marco.fittracker.data.energyTargets
import com.marco.fittracker.data.fmtShort
import com.marco.fittracker.data.hasAnyTrimp
import com.marco.fittracker.data.lastSessionTrimp
import com.marco.fittracker.data.progression
import com.marco.fittracker.data.readiness
import com.marco.fittracker.data.t
import com.marco.fittracker.data.trimNum
import com.marco.fittracker.data.trimp
import com.marco.fittracker.data.weekLoad
import com.marco.fittracker.data.weeklyTrimp
import com.marco.fittracker.data.weightTrend

fun zoneColor(z: String): Color = when (z) {
    "ok", "ready" -> T.good
    "warn", "easy", "slow", "fast", "high", "low" -> T.acc2
    "risk", "rest", "wrong" -> T.red
    else -> T.sub
}

// MARK: - Info button + explanation popup (scientific metrics)
@Composable
fun InfoButton(id: String, color: Color = T.sub) {
    val tap = rememberTap()
    var show by remember { mutableStateOf(false) }
    Icon(
        Icons.Filled.Info, contentDescription = null, tint = color,
        modifier = Modifier.size(15.dp).clickable { tap(); show = true }
    )
    if (show) {
        Dialog(onDismissRequest = { show = false }) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(T.radius))
                    .background(T.c1)
                    .border(1.dp, T.brd, RoundedCornerShape(T.radius))
                    .padding(20.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        t("info.$id.title"), color = T.acc, fontSize = 18.sp,
                        fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)
                    )
                    Icon(Icons.Filled.Close, null, tint = T.sub,
                        modifier = Modifier.size(22.dp).clickable { show = false })
                }
                Spacer(Modifier.height(12.dp))
                Text(t("info.$id.body"), color = T.txt, fontSize = 14.sp, lineHeight = 20.sp)
            }
        }
    }
}

/** Section label with an inline info button. */
@Composable
fun InfoLbl(text: String, info: String, color: Color = T.sub) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Lbl(text, color)
        Spacer(Modifier.width(5.dp))
        InfoButton(info, color)
    }
}

// MARK: - Readiness (HRV) card
@Composable
fun ReadinessCard() {
    val store = LocalStore.current
    val r = store.readiness()
    if (r.score == null && r.samples == 0) return
    Card(accent = zoneColor(r.advice)) {
        InfoLbl(t("load.readiness"), "readiness", T.acc2)
        Spacer(Modifier.height(10.dp))
        val score = r.score
        if (score != null) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text("$score", color = zoneColor(r.advice), fontSize = 34.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(4.dp))
                Text("/100", color = T.sub, fontSize = 12.sp)
                Spacer(Modifier.weight(1f))
                val adv = when (r.advice) { "ready" -> "load.ready"; "easy" -> "load.easy"; "rest" -> "load.rest"; else -> "load.need_data" }
                Text(t(adv).uppercase(), color = zoneColor(r.advice), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(8.dp))
            Bar(score / 100.0, gradient = listOf(zoneColor(r.advice), T.acc))
        } else {
            Text(t("load.need_data"), color = T.sub, fontSize = 12.sp)
        }
    }
}

// MARK: - TRIMP card (cardio training load from avg HR)
@Composable
fun TrimpCard() {
    val store = LocalStore.current
    if (!store.hasAnyTrimp()) return
    val week = store.weeklyTrimp(0)
    val prev = store.weeklyTrimp(1)
    val last = store.lastSessionTrimp()
    Card(accent = T.acc2) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("trimp.title"), T.acc2)
            Spacer(Modifier.width(5.dp))
            InfoButton("trimp", T.acc2)
            Spacer(Modifier.weight(1f))
            last?.let { Text("${t("trimp.last")} ${Math.round(it.first)}", color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold) }
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${Math.round(week)}", color = T.acc2, fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Text(t("trimp.this_week"), color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(12.dp))
        val mx = maxOf(week, prev, 1.0)
        TrimpCmpRow(t("trimp.this_week"), week, mx, T.acc2)
        Spacer(Modifier.height(7.dp))
        TrimpCmpRow(t("trimp.last_week"), prev, mx, T.sub)
        Spacer(Modifier.height(8.dp))
        Text(t("trimp.note"), color = T.sub, fontSize = 9.sp)
    }
}

@Composable
private fun TrimpCmpRow(label: String, value: Double, mx: Double, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(label, color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(78.dp))
        Bar(value / mx, gradient = listOf(color, color.copy(alpha = 0.6f)), height = 8, modifier = Modifier.weight(1f))
        Text("${Math.round(value)}", color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.width(38.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
    }
}

// MARK: - Internal-load trend (visual bar chart of daily sRPE/TRIMP)
@Composable
fun LoadTrendCard() {
    val store = LocalStore.current
    val series = store.dailyLoadSeries(14)
    if (series.none { it.load > 0 }) return
    val acwr = store.acwr()
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("load.trend_title"), T.acc2)
            Spacer(Modifier.width(5.dp))
            InfoButton("load", T.acc2)
            Spacer(Modifier.weight(1f))
            acwr.ratio?.let { Text("ACWR ${trimNum(it)}", color = zoneColor(acwr.zone), fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
        }
        Spacer(Modifier.height(12.dp))
        BarChart(
            xLabels = series.map { fmtShort(it.date) },
            values = series.map { it.load },
            color = zoneColor(acwr.zone)
        )
    }
}

// MARK: - Internal-load card (ACWR + monotony/strain)
@Composable
fun LoadCard() {
    val store = LocalStore.current
    val acwr = store.acwr()
    val wk = store.weekLoad(0)
    if (acwr.ratio == null && wk.total <= 0) return
    Card {
        InfoLbl(t("load.title"), "load", T.acc2)
        Spacer(Modifier.height(12.dp))
        acwr.ratio?.let { ratio ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("load.acwr"), color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.width(4.dp))
                InfoButton("acwr")
                Spacer(Modifier.weight(1f))
                Text(trimNum(ratio), color = zoneColor(acwr.zone), fontSize = 20.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(5.dp))
            Bar(minOf(1.0, ratio / 2), gradient = listOf(zoneColor(acwr.zone), zoneColor(acwr.zone)))
            val zk = when (acwr.zone) { "low" -> "load.acwr_low"; "high" -> "load.acwr_high"; else -> "load.acwr_ok" }
            Spacer(Modifier.height(5.dp))
            Text(t(zk), color = zoneColor(acwr.zone), fontSize = 10.sp)
            Spacer(Modifier.height(12.dp))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            RowScopeStatTile(t("load.weekly"), "${wk.total.toInt()}", info = "trimp", modifier = Modifier.weight(1f))
            RowScopeStatTile(t("load.monotony"), wk.monotony?.let { trimNum(Math.round(it * 10.0) / 10.0) } ?: "—",
                valueColor = if ((wk.monotony ?: 0.0) > 2) T.acc2 else T.txt, info = "monotony", modifier = Modifier.weight(1f))
            RowScopeStatTile(t("load.strain"), wk.strain?.let { "${it.toInt()}" } ?: "—",
                valueColor = T.blue, info = "strain", modifier = Modifier.weight(1f))
        }
        if ((wk.monotony ?: 0.0) > 2 || acwr.zone == "high") {
            Spacer(Modifier.height(10.dp))
            Text(t("load.deload"), color = T.red, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

// MARK: - Nutrition card
@Composable
fun NutritionCard() {
    val store = LocalStore.current
    val e = store.energyTargets()
    val trend = store.weightTrend()
    val lea = store.energyAvailability()
    val adh = store.adherence()
    val modeKey = when (e.mode) { GoalMode.CUT -> "nut.cut"; GoalMode.BULK -> "nut.bulk"; else -> "nut.maintain" }
    Card(accent = T.acc) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("nut.title"), T.acc2)
            Spacer(Modifier.width(5.dp))
            InfoButton("tdee", T.acc2)
            Spacer(Modifier.weight(1f))
            if (e.adaptive) {
                Badge(t("nut.adaptive"), T.good, T.good.copy(alpha = 0.14f))
                Spacer(Modifier.width(6.dp))
            }
            Text(t(modeKey).uppercase(), color = T.acc, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${e.target.toInt()}", color = T.txt, fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Text("kcal", color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Text("TDEE ${e.tdee.toInt()} · BMR ${e.bmr.toInt()}", color = T.sub, fontSize = 10.sp)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            RowScopeStatTile(t("nut.protein"), "${e.protein.toInt()}", "g", valueColor = T.blue, info = "macros", modifier = Modifier.weight(1f))
            RowScopeStatTile(t("nut.carbs"), "${e.carbs.toInt()}", "g", valueColor = T.acc2, info = "macros", modifier = Modifier.weight(1f))
            RowScopeStatTile(t("nut.fat"), "${e.fat.toInt()}", "g", valueColor = T.good, info = "macros", modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${t("nut.carb_high")}: ${e.carbHigh.toInt()}g · ${t("nut.carb_low")}: ${e.carbLow.toInt()}g", color = T.sub, fontSize = 10.sp)
            Spacer(Modifier.width(4.dp))
            InfoButton("carbcycle")
        }
        trend.ratePerWeek?.let { rate ->
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("nut.trend"), color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.width(4.dp))
                InfoButton("trend")
                Spacer(Modifier.weight(1f))
                Text("${if (rate > 0) "+" else ""}${trimNum(rate)} ${t("nut.per_week")}", color = zoneColor(trend.status), fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }
            Text(trendText(trend), color = zoneColor(trend.status), fontSize = 10.sp)
        }
        if (lea.risk == "risk" || lea.risk == "warn") {
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t(if (lea.risk == "risk") "nut.lea_risk" else "nut.lea_warn") + (lea.ea?.let { " · EA ${trimNum(it)}" } ?: ""),
                    color = if (lea.risk == "risk") T.red else T.acc2, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.width(4.dp))
                InfoButton("lea", if (lea.risk == "risk") T.red else T.acc2)
            }
        }
        // Adherence (2-3 week consistency driving the adaptive target)
        if (adh.status != "none") {
            Spacer(Modifier.height(10.dp))
            Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("nut.adherence"), color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.width(4.dp))
                InfoButton("adherence")
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                RowScopeStatTile(t("nut.logging"), "${Math.round(adh.loggingPct * 100)}", "%",
                    valueColor = if (adh.status == "low_logging") T.acc2 else T.good, modifier = Modifier.weight(1f))
                RowScopeStatTile(t("nut.steps_avg"), adh.avgSteps?.let { "$it" } ?: "—",
                    valueColor = T.blue, info = "steps", modifier = Modifier.weight(1f))
                RowScopeStatTile(t("nut.vol_sessions"), "${adh.sessions}", modifier = Modifier.weight(1f))
            }
            if (adh.status == "low_logging") {
                Spacer(Modifier.height(8.dp))
                Text(t("nut.low_logging"), color = T.acc2, fontSize = 10.sp)
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(t("nut.who_note"), color = T.sub, fontSize = 9.sp)
    }
}

private fun trendText(tr: TrendResult): String {
    var s = when (tr.status) {
        "ok" -> t("nut.trend_ok"); "fast" -> t("nut.trend_fast")
        "slow" -> t("nut.trend_slow"); "wrong" -> t("nut.trend_wrong"); else -> ""
    }
    if (tr.kcalAdjust != 0) s += " · ${t("nut.adjust_pre")} ${tr.kcalAdjust} kcal"
    return s
}

// MARK: - Progressive-overload suggestions card
@Composable
fun OverloadCard() {
    val store = LocalStore.current
    val plan = store.nextStrengthPlan() ?: return
    val items = plan.exercises.mapNotNull { ex ->
        store.progression(plan.id, ex.name)?.let { ex.name to it }
    }.filter { it.second == ProgKind.ADD_LOAD || it.second == ProgKind.ADD_REPS }
    if (items.isEmpty()) return
    Card(accent = T.acc2) {
        InfoLbl(t("wk.suggested"), "overload", T.acc2)
        Spacer(Modifier.height(4.dp))
        items.take(4).forEach { (name, kind) ->
            DividerRow {
                Text(name, color = T.txt, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                Text(t(kind.key), color = if (kind == ProgKind.ADD_LOAD) T.acc else T.blue, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
