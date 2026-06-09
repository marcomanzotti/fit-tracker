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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.t
import com.marco.fittracker.data.trimNum

// Clean starting numbers per sex (height in meters, weights in kg).
private data class SexDefaults(val height: String, val weight: String, val goal: String)
private val maleDefaults = SexDefaults("1.8", "80", "75")
private val femaleDefaults = SexDefaults("1.65", "65", "60")

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun PillRow(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
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
private fun SettingField(label: String, value: String, onChange: (String) -> Unit, ph: String, kb: KeyboardType = KeyboardType.Number) {
    Column(Modifier.fillMaxWidth()) {
        Lbl(label)
        Spacer(Modifier.height(7.dp))
        InputField(value, onChange, ph, kb)
    }
}

@Composable
fun SettingsDialog(onClose: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val p = store.prefs

    var lang by remember { mutableStateOf(p.langCode) }
    var sex by remember { mutableStateOf(p.sexCode) }
    var birth by remember { mutableStateOf(p.birthDate ?: "") }
    var height by remember { mutableStateOf(trimNum(p.height)) }
    var startW by remember { mutableStateOf(trimNum(p.startWeight)) }
    var goalW by remember { mutableStateOf(trimNum(p.goalWeight)) }
    var goalBF by remember { mutableStateOf(trimNum(p.goalBF)) }
    var goalMode by remember { mutableStateOf(p.goal.raw) }
    var activity by remember { mutableStateOf(p.activityLevel.raw) }
    var trainDays by remember { mutableStateOf(p.trainingDays?.toString() ?: "") }
    var restHR by remember { mutableStateOf(p.restingHR?.toString() ?: "") }
    var maxHR by remember { mutableStateOf(p.maxHR?.toString() ?: "") }
    var sleepOn by remember { mutableStateOf(p.sleepEnabled) }
    var timer by remember { mutableStateOf(p.timer.toString()) }
    var unitSys by remember { mutableStateOf(if (p.imperial) "imperial" else "metric") }
    var hkOn by remember { mutableStateOf(p.healthConnectEnabled) }
    var importWk by remember { mutableStateOf(p.importWorkoutsEnabled) }
    var healthCats by remember { mutableStateOf(p.healthCategories) }

    // When the user flips sex and hasn't typed their own numbers yet (the fields
    // still hold the other sex's clean defaults), swap in this sex's defaults.
    LaunchedEffect(sex) {
        val from = if (sex == "m") femaleDefaults else maleDefaults
        val to = if (sex == "m") maleDefaults else femaleDefaults
        if (height == from.height && startW == from.weight && goalW == from.goal) {
            height = to.height; startW = to.weight; goalW = to.goal
        }
    }

    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier.fillMaxWidth().heightIn(max = 640.dp).clip(RoundedCornerShape(T.radius))
                .background(T.bg).border(1.dp, T.brd, RoundedCornerShape(T.radius))
                .padding(18.dp).verticalScroll(rememberScrollState())
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("set.title").uppercase(), color = T.txt, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.Close, null, tint = T.sub, modifier = Modifier.size(24.dp).clickable { onClose() })
            }
            Spacer(Modifier.height(16.dp))

            Lbl(t("set.language")); Spacer(Modifier.height(8.dp))
            PillRow(listOf("it" to "Italiano", "en" to "English"), lang) { lang = it }
            Spacer(Modifier.height(14.dp))

            Lbl(t("ob.sex")); Spacer(Modifier.height(8.dp))
            PillRow(listOf("m" to t("ob.male"), "f" to t("ob.female")), sex) { sex = it }
            Spacer(Modifier.height(14.dp))

            SettingField(t("ob.birth"), birth, { birth = it }, "1995-06-15", KeyboardType.Text)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { SettingField(t("pc.height"), height, { height = it }, "1.85", KeyboardType.Decimal) }
                Box(Modifier.weight(1f)) { SettingField(t("pc.start_weight"), startW, { startW = it }, "88", KeyboardType.Decimal) }
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { SettingField(t("pc.goal_weight"), goalW, { goalW = it }, "80", KeyboardType.Decimal) }
                Box(Modifier.weight(1f)) { SettingField(t("pc.goal_bf"), goalBF, { goalBF = it }, "15", KeyboardType.Decimal) }
            }
            Spacer(Modifier.height(14.dp))

            Lbl(t("ob.goal_mode")); Spacer(Modifier.height(8.dp))
            PillRow(listOf("cut" to t("nut.cut"), "maintain" to t("nut.maintain"), "bulk" to t("nut.bulk")), goalMode) { goalMode = it }
            Spacer(Modifier.height(14.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Lbl(t("ob.activity")); Spacer(Modifier.width(5.dp)); InfoButton("activity")
            }
            Spacer(Modifier.height(8.dp))
            PillRow(listOf("sedentary" to t("ob.act_sed"), "light" to t("ob.act_light"), "moderate" to t("ob.act_mod"), "high" to t("ob.act_high"), "athlete" to t("ob.act_athlete")), activity) { activity = it }
            Spacer(Modifier.height(6.dp))
            Text(activityDesc(activity), color = T.sub, fontSize = 11.sp)
            Spacer(Modifier.height(14.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { SettingField(t("ob.train_days"), trainDays, { trainDays = it }, "4") }
                Box(Modifier.weight(1f)) { SettingField(t("ob.rest_hr"), restHR, { restHR = it }, "58") }
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { SettingField(t("ob.max_hr"), maxHR, { maxHR = it }, "190") }
                Box(Modifier.weight(1f)) { SettingField(t("set.timer"), timer, { timer = it }, "60") }
            }
            Spacer(Modifier.height(14.dp))

            // Sleep tracking toggle
            SettingsToggle(t("set.sleep_track"), sleepOn) { sleepOn = it }
            Spacer(Modifier.height(12.dp))

            // Units (metric / imperial)
            Lbl(t("set.units")); Spacer(Modifier.height(8.dp))
            PillRow(listOf("metric" to t("set.metric"), "imperial" to t("set.imperial")), unitSys) { unitSys = it }
            Spacer(Modifier.height(14.dp))

            // Health Connect
            SettingsToggle(t("hk.connect"), hkOn) { hkOn = it }
            if (hkOn) {
                Spacer(Modifier.height(10.dp))
                Text(t("hk.hint"), color = T.sub, fontSize = 11.sp, lineHeight = 15.sp)
                Spacer(Modifier.height(10.dp))
                SettingsToggle(t("set.import_workouts"), importWk) { importWk = it }
                Spacer(Modifier.height(10.dp))
                Lbl(t("set.health_cats")); Spacer(Modifier.height(8.dp))
                com.marco.fittracker.data.HealthCategory.entries.forEach { cat ->
                    val on = cat.raw in healthCats
                    SettingsToggle(com.marco.fittracker.data.t(cat.labelKey), on) { checked ->
                        healthCats = if (checked) healthCats + cat.raw else healthCats - cat.raw
                    }
                    Spacer(Modifier.height(6.dp))
                }
            }
            Spacer(Modifier.height(18.dp))

            BigButton(t("save")) {
                val np = store.prefs.copy(
                    language = lang,
                    onboarded = true,
                    sex = sex,
                    birthDate = birth.ifBlank { null },
                    height = pf(height).takeIf { it > 0.5 } ?: store.prefs.height,
                    startWeight = pf(startW).takeIf { it > 0 } ?: store.prefs.startWeight,
                    goalWeight = pf(goalW).takeIf { it > 0 } ?: store.prefs.goalWeight,
                    goalBF = pf(goalBF).takeIf { it > 0 } ?: store.prefs.goalBF,
                    goalMode = goalMode,
                    activity = activity,
                    trainingDays = trainDays.toIntOrNull(),
                    restingHR = restHR.toIntOrNull(),
                    maxHR = maxHR.toIntOrNull(),
                    sleepTracking = sleepOn,
                    timer = timer.toIntOrNull() ?: store.prefs.timer,
                    units = if (unitSys == "imperial") "imperial" else null,
                    healthConnect = hkOn,
                    importWorkouts = importWk,
                    healthImport = healthCats.toList()
                )
                store.updatePrefs(np)
                store.syncLang()
                toast.show(t("save"))
                onClose()
            }
        }
    }
}

// MARK: - Settings toggle row
@Composable
fun SettingsToggle(label: String, value: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(T.radiusS)).background(T.c2).border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
            .clickable { onChange(!value) }.padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Box(Modifier.size(44.dp, 26.dp).clip(RoundedCornerShape(13.dp)).background(if (value) T.acc else T.c3),
            contentAlignment = if (value) Alignment.CenterEnd else Alignment.CenterStart) {
            Box(Modifier.padding(3.dp).size(20.dp).clip(RoundedCornerShape(10.dp)).background(T.bg))
        }
    }
}
