package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marco.fittracker.data.*

// MARK: - Onboarding screen (first launch)
@Composable
fun OnboardingScreen(store: Store, onFinish: () -> Unit) {
    val prefs = store.prefs

    var lang by remember { mutableStateOf(prefs.langCode) }
    var sex by remember { mutableStateOf(prefs.sexCode) }
    var birthYear by remember { mutableStateOf(prefs.birthDate?.take(4) ?: "1994") }
    var birthMonth by remember { mutableStateOf(prefs.birthDate?.substring(5, 7) ?: "01") }
    var birthDay by remember { mutableStateOf(prefs.birthDate?.takeLast(2) ?: "01") }
    var heightCm by remember { mutableStateOf(if (prefs.height > 0) trimNum(prefs.height * 100) else if (sex == "m") "180" else "165") }
    var weight by remember { mutableStateOf(if (store.lastWeight > 0) trimNum(store.lastWeight) else if (sex == "m") "80" else "65") }
    var goalWeight by remember { mutableStateOf(if (prefs.goalWeight > 0) trimNum(prefs.goalWeight) else if (sex == "m") "75" else "60") }
    var goalMode by remember { mutableStateOf(prefs.goal.raw) }
    var rate by remember { mutableStateOf(prefs.weeklyRate?.let { trimNum(it) } ?: "") }
    var activity by remember { mutableStateOf(prefs.activityLevel.raw) }
    var trainDays by remember { mutableStateOf(prefs.trainingDays?.toString() ?: "") }
    var restHR by remember { mutableStateOf(prefs.restingHR?.toString() ?: "") }
    var maxHR by remember { mutableStateOf(prefs.maxHR?.toString() ?: "") }

    // When sex changes, swap in sex defaults if user hasn't edited fields yet
    LaunchedEffect(sex) {
        val maleDef = Triple("180", "80", "75")
        val femDef = Triple("165", "65", "60")
        val from = if (sex == "m") femDef else maleDef
        val to = if (sex == "m") maleDef else femDef
        if (heightCm == from.first && weight == from.second && goalWeight == from.third) {
            heightCm = to.first; weight = to.second; goalWeight = to.third
        }
    }

    // Live language sync
    LaunchedEffect(lang) { store.updatePrefs(store.prefs.copy(language = lang)) }

    LazyColumn(
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Header
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 14.dp)) {
                Row {
                    Text("FIT TR", color = T.txt, fontSize = 28.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    Text("A", color = T.acc, fontSize = 28.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                    Text("CKER", color = T.txt, fontSize = 28.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                }
                Text(t("ob.welcome").uppercase(), color = T.acc, fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp)
                Text(t("ob.intro"), color = T.sub, fontSize = 14.sp, lineHeight = 20.sp)
            }
        }

        item {
            Card {
                Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    // Language
                    ObFieldRow(t("ob.language")) {
                        PillSelect(options = listOf("it", "en"), selected = lang,
                            label = { if (it == "it") "Italiano" else "English" }) { lang = it }
                    }
                    // Sex
                    ObFieldRow(t("ob.sex")) {
                        PillSelect(options = listOf("m", "f"), selected = sex,
                            label = { if (it == "m") t("ob.male") else t("ob.female") }) { sex = it }
                    }
                    // Birth date (year/month/day inline fields)
                    ObFieldRow(t("ob.birth")) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.weight(2f)) {
                                OnbField(birthYear, "YYYY", KeyboardType.Number) { birthYear = it }
                            }
                            Box(Modifier.weight(1f)) {
                                OnbField(birthMonth, "MM", KeyboardType.Number) { birthMonth = it.take(2) }
                            }
                            Box(Modifier.weight(1f)) {
                                OnbField(birthDay, "DD", KeyboardType.Number) { birthDay = it.take(2) }
                            }
                        }
                    }
                    // Height / Weight
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f)) {
                            ObFieldRow("${t("ob.height")} (cm)") {
                                OnbField(heightCm, "180", KeyboardType.Decimal) { heightCm = it }
                            }
                        }
                        Column(Modifier.weight(1f)) {
                            ObFieldRow("${t("ob.weight")} (kg)") {
                                OnbField(weight, "80", KeyboardType.Decimal) { weight = it }
                            }
                        }
                    }
                    // Goal mode
                    ObFieldRow(t("ob.goal_mode")) {
                        PillSelect(options = listOf("cut", "maintain", "bulk"), selected = goalMode,
                            label = { when (it) { "cut" -> t("nut.cut"); "maintain" -> t("nut.maintain"); "bulk" -> t("nut.bulk"); else -> it } }) { goalMode = it }
                    }
                    // Goal weight / rate
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f)) {
                            ObFieldRow("${t("ob.goal_weight")} (kg)") {
                                OnbField(goalWeight, "75", KeyboardType.Decimal) { goalWeight = it }
                            }
                        }
                        Column(Modifier.weight(1f)) {
                            ObFieldRow("${t("ob.rate")} (kg/${t("ob.per_wk")})") {
                                OnbField(rate, "-0.5", KeyboardType.Decimal) { rate = it }
                            }
                        }
                    }
                    // Activity level
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Lbl(t("ob.activity"))
                            Spacer(Modifier.width(4.dp))
                            InfoButton("activity", color = T.sub)
                        }
                        PillSelect(
                            options = listOf("sedentary", "light", "moderate", "high", "athlete"),
                            selected = activity,
                            label = { activityTitle(it) }
                        ) { activity = it }
                        Text(activityDesc(activity), color = T.sub, fontSize = 11.sp, lineHeight = 15.sp)
                    }
                    // Training days / resting HR
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f)) {
                            ObFieldRow(t("ob.train_days")) {
                                OnbField(trainDays, "4", KeyboardType.Number) { trainDays = it }
                            }
                        }
                        Column(Modifier.weight(1f)) {
                            ObFieldRow(t("ob.rest_hr")) {
                                OnbField(restHR, "60", KeyboardType.Number) { restHR = it }
                            }
                        }
                    }
                    // Max HR (optional)
                    ObFieldRow(t("ob.max_hr")) {
                        OnbField(maxHR, "—", KeyboardType.Number) { maxHR = it }
                    }
                }
            }
        }

        item {
            val tap = rememberTap()
            BigButton(t("ob.finish")) {
                tap()
                val birthStr = "$birthYear-${birthMonth.padStart(2, '0')}-${birthDay.padStart(2, '0')}"
                val hCm = pf(heightCm)
                val wKg = pf(weight)
                val updated = store.prefs.copy(
                    language = lang,
                    sex = sex,
                    birthDate = birthStr,
                    height = if (hCm > 0) hCm / 100.0 else store.prefs.height,
                    goalWeight = if (pf(goalWeight) > 0) pf(goalWeight) else store.prefs.goalWeight,
                    goalMode = goalMode,
                    weeklyRate = rate.toDoubleOrNull(),
                    activity = activity,
                    trainingDays = trainDays.toIntOrNull(),
                    restingHR = restHR.toIntOrNull(),
                    maxHR = maxHR.toIntOrNull(),
                    startWeight = if (wKg > 0) wKg else store.prefs.startWeight,
                    onboarded = true
                )
                store.updatePrefs(updated)
                if (wKg > 0) store.saveCheckIn(weight = wKg, sleep = null)
                onFinish()
            }
        }

        item { Spacer(Modifier.height(40.dp)) }
    }
}

// MARK: - Reusable onboarding field row
@Composable
fun ObFieldRow(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        FieldLabel(label)
        content()
    }
}

// MARK: - Single text/number input for onboarding
@Composable
fun OnbField(value: String, placeholder: String, keyboardType: KeyboardType = KeyboardType.Text, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = onChange,
        placeholder = { Text(placeholder, color = T.sub, fontSize = 14.sp) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = T.txt, unfocusedTextColor = T.txt,
            focusedContainerColor = T.c2, unfocusedContainerColor = T.c2,
            focusedBorderColor = T.acc, unfocusedBorderColor = T.brd, cursorColor = T.acc
        ),
        textStyle = LocalTextStyle.current.copy(
            color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
        shape = RoundedCornerShape(T.radiusS),
        modifier = Modifier.fillMaxWidth().height(52.dp)
    )
}

// MARK: - Wrapping pill selector
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun PillSelect(options: List<String>, selected: String, label: (String) -> String, onSelect: (String) -> Unit) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(7.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        options.forEach { opt ->
            val tap = rememberTap()
            val on = opt == selected
            Text(
                label(opt), color = if (on) T.bg else T.txt, fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (on) T.acc else T.c2)
                    .border(1.dp, if (on) Color.Transparent else T.brd, RoundedCornerShape(10.dp))
                    .clickable { tap(); onSelect(opt) }
                    .padding(horizontal = 14.dp, vertical = 9.dp)
            )
        }
    }
}

// MARK: - Localized activity descriptions
fun activityTitle(v: String): String = when (v) {
    "sedentary" -> t("ob.act_sed")
    "light" -> t("ob.act_light")
    "moderate" -> t("ob.act_mod")
    "high" -> t("ob.act_high")
    "athlete" -> t("ob.act_athlete")
    else -> v
}

fun activityDesc(v: String): String = when (v) {
    "sedentary" -> t("ob.act_sed_d")
    "light" -> t("ob.act_light_d")
    "moderate" -> t("ob.act_mod_d")
    "high" -> t("ob.act_high_d")
    "athlete" -> t("ob.act_athlete_d")
    else -> ""
}
