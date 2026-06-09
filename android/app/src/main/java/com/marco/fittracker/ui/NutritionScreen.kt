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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marco.fittracker.data.*
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

// MARK: - Nutrition tab (full page)
@Composable
fun NutritionScreen(store: Store) {
    var editingToday by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(T.bg),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item { TargetCard(store) }
        item { TodayNutritionCard(store) { editingToday = true } }
        item { NutritionCalendarCard(store) }
        item { NutritionChartsSection(store) }
        item { FoodDatabaseCard(store) }
        item { Spacer(Modifier.height(80.dp)) }
    }

    if (editingToday) {
        NutritionDayEditorSheet(store, date = today()) { editingToday = false }
    }
}

// MARK: - Calorie target card (TDEE + BMR + macro tiles)
@Composable
private fun TargetCard(store: Store) {
    val e = store.energyTargets()
    val modeLabel = when (store.prefs.goal) {
        GoalMode.CUT -> t("nut.cut"); GoalMode.BULK -> t("nut.bulk"); else -> t("nut.maintain")
    }
    Card(accent = T.acc2) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("nut.target"), color = T.acc2, modifier = Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically) {
                InfoButton("tdee")
                Spacer(Modifier.width(6.dp))
                Text(
                    modeLabel.uppercase(), color = T.acc, fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${e.target.toInt()}", color = T.txt, fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Text("kcal", color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(bottom = 4.dp))
            Spacer(Modifier.weight(1f))
            Text("TDEE ${e.tdee.toInt()} · BMR ${e.bmr.toInt()}", color = T.sub, fontSize = 10.sp,
                modifier = Modifier.padding(bottom = 4.dp))
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Box(Modifier.weight(1f)) {
                RowScopeStatTile(t("nut.protein"), "${e.protein.toInt()}", "g", T.blue, info = "macros")
            }
            Box(Modifier.weight(1f)) {
                RowScopeStatTile(t("nut.carbs"), "${e.carbs.toInt()}", "g", T.acc2, info = "macros")
            }
            Box(Modifier.weight(1f)) {
                RowScopeStatTile(t("nut.fat"), "${e.fat.toInt()}", "g", T.good, info = "macros")
            }
        }
    }
}

// MARK: - Today's intake card
@Composable
private fun TodayNutritionCard(store: Store, onLog: () -> Unit) {
    val e = store.energyTargets()
    val entry = store.dailyEntry(today())
    val kcal = entry?.totalKcal ?: 0
    val logged = (entry?.hasNutrition == true) && kcal > 0
    val pct = if (e.target > 0) kcal / e.target else 0.0
    val barColors = if (pct > 1.12) listOf(T.red, T.red) else listOf(T.acc, T.acc2)

    Card {
        Lbl("${t("nutp.today")} · ${today()}", color = T.acc2)
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("$kcal", color = if (logged) T.acc else T.sub, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(6.dp))
            Text("/ ${e.target.toInt()} kcal", color = T.sub, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(bottom = 4.dp))
            Spacer(Modifier.weight(1f))
            if (logged && entry != null) {
                Text(
                    "P ${entry.totalProtein.toInt()} · C ${entry.totalCarbs.toInt()} · F ${entry.totalFat.toInt()} g",
                    color = T.sub, fontSize = 10.sp, modifier = Modifier.padding(bottom = 4.dp)
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Bar(pct.coerceAtMost(1.0), barColors)
        Spacer(Modifier.height(14.dp))
        FilledButton(if (logged) t("nutp.edit_today") else t("nutp.log_today")) { onLog() }
    }
}

// MARK: - Nutrition calendar (month view, tap to edit)
@Composable
fun NutritionCalendarCard(store: Store) {
    var monthOffset by remember { mutableIntStateOf(0) }
    var editDate by remember { mutableStateOf<String?>(null) }

    val baseMonth = YearMonth.now().plusMonths(monthOffset.toLong())
    val firstOfMonth = baseMonth.atDay(1)
    val daysInMonth = baseMonth.lengthOfMonth()
    // Monday-first offset: Monday=0 … Sunday=6
    val firstWeekday = ((firstOfMonth.dayOfWeek.value - 1) + 7) % 7
    val target = store.energyTargets().target
    val monthLabel = remember(baseMonth) {
        val m = baseMonth.monthValue - 1
        val months = if (L.lang == "en")
            listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        else
            listOf("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")
        "${months[m]} ${baseMonth.year}".uppercase()
    }

    Card {
        // Month navigation header
        Row(verticalAlignment = Alignment.CenterVertically) {
            val tap = rememberTap()
            IconButton(onClick = { tap(); monthOffset-- }) {
                Text("<", color = T.sub, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
            Text(monthLabel, color = T.txt, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.sp, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            IconButton(onClick = { tap(); if (monthOffset < 0) monthOffset++ }) {
                Text(">", color = if (monthOffset < 0) T.sub else T.mut, fontSize = 14.sp,
                    fontWeight = FontWeight.Bold)
            }
        }

        // Weekday headers (Mon-first)
        val headers = L.weekHeaders
        Row(Modifier.fillMaxWidth().padding(bottom = 6.dp)) {
            headers.forEach { h ->
                Text(h, color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            }
        }

        // Day grid
        val cells = firstWeekday + daysInMonth
        val rows = Math.ceil(cells / 7.0).toInt()
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            for (row in 0 until rows) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (col in 0..6) {
                        val idx = row * 7 + col
                        val day = idx - firstWeekday + 1
                        if (day in 1..daysInMonth) {
                            val ds = firstOfMonth.plusDays((day - 1).toLong()).toString()
                            val entry = store.dailyEntry(ds)
                            val kcal = entry?.totalKcal ?: 0
                            val loggedDay = (entry?.hasNutrition == true) && kcal > 0
                            val isTodayDay = ds == today()
                            val future = ds > today()
                            val dayColor = if (loggedDay) nutDayColor(kcal, target) else null
                            val tap = rememberTap()
                            Box(
                                Modifier
                                    .weight(1f)
                                    .height(40.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(dayColor ?: Color.Transparent)
                                    .then(
                                        if (isTodayDay && dayColor == null)
                                            Modifier.border(1.dp, T.acc, RoundedCornerShape(8.dp))
                                        else Modifier
                                    )
                                    .clickable(enabled = !future) { tap(); editDate = ds },
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(
                                        "$day",
                                        color = if (dayColor != null) T.bg else if (isTodayDay) T.acc else T.txt,
                                        fontSize = 12.sp,
                                        fontWeight = if (isTodayDay) FontWeight.Bold else FontWeight.Normal
                                    )
                                    if (loggedDay) {
                                        Text("$kcal", color = T.bg, fontSize = 7.sp,
                                            fontWeight = FontWeight.Bold, maxLines = 1)
                                    }
                                }
                            }
                        } else {
                            Box(Modifier.weight(1f).height(40.dp))
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(t("nut.cal_hint_tap"), color = T.sub, fontSize = 11.sp, modifier = Modifier.fillMaxWidth())
    }

    editDate?.let { ds ->
        NutritionDayEditorSheet(store, ds) { editDate = null }
    }
}

private fun nutDayColor(kcal: Int, target: Double): Color {
    if (target <= 0) return hexColor("4fb8c4")
    val r = kcal / target
    return when {
        r < 0.85 -> hexColor("ffb000")   // amber = under
        r > 1.12 -> hexColor("ff5a52")   // red = over
        else -> hexColor("7fc950")       // green = on target
    }
}

// MARK: - Nutrition day editor (sheet)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NutritionDayEditorSheet(store: Store, date: String, onDismiss: () -> Unit) {
    var mode by remember { mutableStateOf("per_meal") }
    // Quick total
    var qK by remember { mutableStateOf("") }
    var qP by remember { mutableStateOf("") }
    var qC by remember { mutableStateOf("") }
    var qF by remember { mutableStateOf("") }
    // Per-meal: slot -> field -> value
    var mealData by remember { mutableStateOf<Map<String, Map<String, String>>>(emptyMap()) }
    var mealFoods by remember { mutableStateOf<Map<String, List<FoodLog>>>(emptyMap()) }
    var dayFoods by remember { mutableStateOf<List<FoodLog>>(emptyList()) }
    var loaded by remember { mutableStateOf(false) }
    var showFoodPicker by remember { mutableStateOf<String?>(null) } // null=day, slot=meal

    // Load existing data once
    LaunchedEffect(date) {
        if (!loaded) {
            val e = store.dailyEntry(date)
            when {
                e?.foods?.isNotEmpty() == true -> {
                    mode = "foods"; dayFoods = e.foods!!
                }
                e?.meals?.isNotEmpty() == true -> {
                    mode = "per_meal"
                    val m = mutableMapOf<String, Map<String, String>>()
                    val mf = mutableMapOf<String, List<FoodLog>>()
                    e.meals!!.forEach { (k, v) ->
                        if ((v.foods ?: emptyList()).isNotEmpty()) mf[k] = v.foods!!
                        m[k] = mapOf("k" to if (v.kcal > 0) "${v.kcal}" else "",
                            "p" to if (v.protein > 0) trimNum(v.protein) else "",
                            "c" to if (v.carbs > 0) trimNum(v.carbs) else "",
                            "f" to if (v.fat > 0) trimNum(v.fat) else "")
                    }
                    mealData = m; mealFoods = mf
                }
                (e?.kcal ?: 0) > 0 -> {
                    mode = "quick"
                    qK = "${e?.kcal ?: ""}"; qP = trimNum(e?.protein ?: 0.0)
                    qC = trimNum(e?.carbs ?: 0.0); qF = trimNum(e?.fat ?: 0.0)
                }
                else -> mode = if (date == today()) "per_meal" else "quick"
            }
            loaded = true
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        LazyColumn(
            Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(t("nut.edit_day").uppercase(), color = T.txt, fontSize = 16.sp,
                            fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                        Text(prettyDate(date), color = T.sub, fontSize = 11.sp)
                    }
                    val tap = rememberTap()
                    TextButton(onClick = { tap(); onDismiss() }) {
                        Text(t("close"), color = T.sub)
                    }
                }
            }

            item {
                Card {
                    Lbl(t("nut.entry_mode"), color = T.sub)
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("quick" to t("nut.quick"), "per_meal" to t("nut.per_meal"), "foods" to t("nut.foods")).forEach { (k, label) ->
                            val tap = rememberTap()
                            val sel = mode == k
                            Text(
                                label, color = if (sel) T.bg else T.txt, fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(if (sel) T.acc else T.mut)
                                    .clickable { tap(); mode = k }
                                    .padding(horizontal = 16.dp, vertical = 8.dp)
                            )
                        }
                    }
                }
            }

            when (mode) {
                "quick" -> item {
                    Card {
                        Lbl(t("nut.day_total"), color = T.acc2)
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Column(Modifier.weight(1f)) {
                                MacroFieldLabel("KCAL")
                                NutField(qK, KeyboardType.Number) { qK = it }
                            }
                            Column(Modifier.weight(1f)) {
                                MacroFieldLabel("${t("nut.protein")} (g)")
                                NutField(qP) { qP = it }
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Column(Modifier.weight(1f)) {
                                MacroFieldLabel("${t("nut.carbs")} (g)")
                                NutField(qC) { qC = it }
                            }
                            Column(Modifier.weight(1f)) {
                                MacroFieldLabel("${t("nut.fat")} (g)")
                                NutField(qF) { qF = it }
                            }
                        }
                    }
                }

                "per_meal" -> {
                    items(MealSlot.all.size) { idx ->
                        val slot = MealSlot.all[idx]
                        val slotFoods = mealFoods[slot.raw] ?: emptyList()
                        val slotData = mealData[slot.raw] ?: emptyMap()
                        Card {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp))
                                    .background(hexColor(slot.color)))
                                Spacer(Modifier.width(8.dp))
                                Text(t(slot.labelKey), color = T.txt, fontSize = 14.sp,
                                    fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                            }
                            Spacer(Modifier.height(10.dp))
                            if (slotFoods.isNotEmpty()) {
                                FoodLogRows(slotFoods, accent = hexColor(slot.color),
                                    onRemove = { fi ->
                                        val newFoods = slotFoods.filter { it.id != fi }
                                        mealFoods = mealFoods.toMutableMap().also { it[slot.raw] = newFoods }
                                    })
                            } else {
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Column(Modifier.weight(1f)) {
                                        MacroFieldLabel("KCAL")
                                        NutField(slotData["k"] ?: "", KeyboardType.Number) { v ->
                                            mealData = mealData.toMutableMap().also {
                                                it[slot.raw] = (slotData.toMutableMap()).also { m -> m["k"] = v }
                                            }
                                        }
                                    }
                                    Column(Modifier.weight(1f)) {
                                        MacroFieldLabel("${t("nut.protein")} (g)")
                                        NutField(slotData["p"] ?: "") { v ->
                                            mealData = mealData.toMutableMap().also {
                                                it[slot.raw] = slotData.toMutableMap().also { m -> m["p"] = v }
                                            }
                                        }
                                    }
                                }
                                Spacer(Modifier.height(8.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Column(Modifier.weight(1f)) {
                                        MacroFieldLabel("${t("nut.carbs")} (g)")
                                        NutField(slotData["c"] ?: "") { v ->
                                            mealData = mealData.toMutableMap().also {
                                                it[slot.raw] = slotData.toMutableMap().also { m -> m["c"] = v }
                                            }
                                        }
                                    }
                                    Column(Modifier.weight(1f)) {
                                        MacroFieldLabel("${t("nut.fat")} (g)")
                                        NutField(slotData["f"] ?: "") { v ->
                                            mealData = mealData.toMutableMap().also {
                                                it[slot.raw] = slotData.toMutableMap().also { m -> m["f"] = v }
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            val tap = rememberTap()
                            TextButton(onClick = { tap(); showFoodPicker = slot.raw }) {
                                Text("+ ${t("food.add")}", color = hexColor(slot.color),
                                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                    item {
                        val mealTotalKcal = MealSlot.all.sumOf { s ->
                            val fl = mealFoods[s.raw] ?: emptyList()
                            if (fl.isNotEmpty()) fl.sumOf { it.kcal }
                            else (mealData[s.raw]?.get("k")?.toIntOrNull() ?: 0)
                        }
                        Card(accent = T.acc) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Lbl(t("nut.day_total"), color = T.acc2, modifier = Modifier.weight(1f))
                                Text("$mealTotalKcal", color = T.acc, fontSize = 26.sp,
                                    fontWeight = FontWeight.Bold)
                                Spacer(Modifier.width(4.dp))
                                Text("kcal", color = T.sub, fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }

                else -> item { // foods
                    Card {
                        Lbl(t("food.day_foods"), color = T.acc2)
                        Spacer(Modifier.height(10.dp))
                        if (dayFoods.isNotEmpty()) {
                            FoodLogRows(dayFoods, onRemove = { fi ->
                                dayFoods = dayFoods.filter { it.id != fi }
                            })
                            Spacer(Modifier.height(8.dp))
                        }
                        val tap = rememberTap()
                        TextButton(onClick = { tap(); showFoodPicker = "" }) {
                            Text("+ ${t("food.add")}", color = T.acc, fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }

            item {
                val tap = rememberTap()
                BigButton(t("save")) {
                    tap()
                    when (mode) {
                        "quick" -> {
                            store.saveNutritionTotal(date, qK.toIntOrNull(),
                                pf(qP).takeIf { it > 0 }, pf(qC).takeIf { it > 0 }, pf(qF).takeIf { it > 0 })
                            store.saveDayFoods(date, emptyList())
                        }
                        "foods" -> store.saveDayFoods(date, dayFoods)
                        else -> {
                            val meals = mutableMapOf<String, MealEntry>()
                            MealSlot.all.forEach { s ->
                                val fl = mealFoods[s.raw] ?: emptyList()
                                val d = mealData[s.raw] ?: emptyMap()
                                val m = if (fl.isNotEmpty()) MealEntry(foods = fl)
                                else MealEntry(
                                    kcal = d["k"]?.toIntOrNull() ?: 0,
                                    protein = pf(d["p"] ?: ""),
                                    carbs = pf(d["c"] ?: ""),
                                    fat = pf(d["f"] ?: "")
                                )
                                if (!m.isEmpty) meals[s.raw] = m
                            }
                            store.saveNutritionMeals(date, meals)
                            store.saveDayFoods(date, emptyList())
                        }
                    }
                    onDismiss()
                }
            }
            item {
                val tap = rememberTap()
                TextButton(
                    onClick = {
                        tap()
                        store.saveNutritionTotal(date, null, null, null, null)
                        store.saveDayFoods(date, emptyList())
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(t("delete"), color = T.red, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    // Food picker bottom sheet
    showFoodPicker?.let { slotRaw ->
        FoodAndRecipePickerSheet(store, onDismiss = { showFoodPicker = null }) { log ->
            if (slotRaw.isEmpty()) {
                dayFoods = dayFoods + log
            } else {
                val cur = mealFoods[slotRaw] ?: emptyList()
                mealFoods = mealFoods.toMutableMap().also { it[slotRaw] = cur + log }
            }
            showFoodPicker = null
        }
    }
}

// MARK: - Macro label + field helpers
@Composable
private fun MacroFieldLabel(text: String) {
    Text(text.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
        letterSpacing = 1.sp, modifier = Modifier.padding(bottom = 7.dp))
}

@Composable
private fun NutField(value: String, keyboardType: KeyboardType = KeyboardType.Decimal, onChange: (String) -> Unit) {
    androidx.compose.foundation.text.BasicTextField(
        value = value,
        onValueChange = onChange,
        textStyle = androidx.compose.ui.text.TextStyle(color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        singleLine = true,
        cursorBrush = androidx.compose.ui.graphics.SolidColor(T.acc),
        decorationBox = { inner ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(T.radiusS))
                    .background(T.c2)
                    .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
                    .padding(horizontal = 12.dp, vertical = 11.dp)
            ) { inner() }
        }
    )
}

// MARK: - FoodLog rows (compact list used inside day/meal editors)
@Composable
fun FoodLogRows(logs: List<FoodLog>, accent: Color = T.acc, onRemove: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        logs.forEach { log ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(T.radiusS))
                    .background(T.c2)
                    .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text(log.name, color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${log.kcal} kcal · ${trimNum(log.grams)}g · P${trimNum(log.protein)} C${trimNum(log.carbs)} F${trimNum(log.fat)}",
                        color = T.sub, fontSize = 10.sp)
                }
                val tap = rememberTap()
                TextButton(onClick = { tap(); onRemove(log.id) }) {
                    Text("×", color = T.red, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// MARK: - Nutrition charts (kcal + macros, 90 days)
@Composable
fun NutritionChartsSection(store: Store) {
    val series = store.nutritionSeries(90)
    val targets = store.energyTargets()

    if (series.size < 2) {
        Card {
            Lbl(t("nut.charts"), color = T.acc2)
            Spacer(Modifier.height(12.dp))
            Text(t("nut.charts_hint"), color = T.sub, fontSize = 12.sp)
        }
        return
    }

    val kcalPts = series.map { it.date to it.kcal.toDouble() }
    val protPts = series.map { it.date to it.protein }
    val carbPts = series.map { it.date to it.carbs }
    val fatPts  = series.map { it.date to it.fat }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        NutMacroChartCard(t("nut.kcal"), kcalPts, T.acc, targets.target)
        NutMacroChartCard("${t("nut.protein")} (g)", protPts, T.blue, targets.protein)
        NutMacroChartCard("${t("nut.carbs")} (g)", carbPts, T.acc2, targets.carbs)
        NutMacroChartCard("${t("nut.fat")} (g)", fatPts, T.good, targets.fat)
    }
}

@Composable
private fun NutMacroChartCard(
    title: String,
    pts: List<Pair<String, Double>>,
    color: Color,
    target: Double
) {
    Card {
        Lbl(title, color = T.sub)
        Spacer(Modifier.height(8.dp))
        val xLabels = pts.takeLast(20).map { fmtShort(it.first) }
        val yVals = pts.takeLast(20).map { it.second }
        LineChart(
            xLabels = xLabels,
            series = listOf(Series(title, color, yVals)),
            heightDp = 140,
            yMin = if (target > 0) minOf(target * 0.7, yVals.minOrNull() ?: target) else null,
            fill = true
        )
        if (target > 0) {
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.width(16.dp).height(1.dp).background(T.sub.copy(alpha = 0.5f)))
                Spacer(Modifier.width(6.dp))
                Text("${t("nut.target")}: ${target.toInt()}", color = T.sub, fontSize = 10.sp)
            }
        }
    }
}

// MARK: - Food database card (saved foods)
@Composable
fun FoodDatabaseCard(store: Store) {
    var showScan by remember { mutableStateOf(false) }
    var editFood by remember { mutableStateOf<FoodItem?>(null) }
    var looking by remember { mutableStateOf(false) }

    val foods = store.recentFoods()

    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Lbl(t("nutp.my_foods"), color = T.acc2, modifier = Modifier.weight(1f))
            Text("${foods.size}", color = T.sub, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Box(Modifier.weight(1f)) {
                FilledButton(t("food.scan"), color = T.blue) { showScan = true }
            }
            Box(Modifier.weight(1f)) {
                FilledButton(t("food.new")) { editFood = FoodItem(name = "") }
            }
        }
        if (foods.isEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text(t("nutp.no_foods"), color = T.sub, fontSize = 11.sp)
        } else {
            Spacer(Modifier.height(10.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                foods.take(12).forEach { f ->
                    val tap = rememberTap()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(11.dp))
                            .background(T.c2)
                            .border(1.dp, T.brd, RoundedCornerShape(11.dp))
                            .clickable { tap(); editFood = f }
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(f.name, color = T.txt, fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold, maxLines = 1,
                                overflow = TextOverflow.Ellipsis)
                            Text("${trimNum(f.k100)} kcal · P ${trimNum(f.p100)} C ${trimNum(f.c100)} F ${trimNum(f.f100)} · /100${f.unit}",
                                color = T.sub, fontSize = 10.sp, maxLines = 1)
                        }
                        Text("›", color = T.sub, fontSize = 16.sp)
                    }
                }
            }
        }
    }

    // Barcode scan sheet
    if (showScan) {
        BarcodeScannerSheet(
            onDismiss = { showScan = false },
            onCode = { code ->
                showScan = false
                val existing = store.food(code)
                if (existing != null) { editFood = existing }
                else {
                    looking = true
                    lookupOpenFoodFacts(code) { item ->
                        looking = false
                        editFood = item ?: FoodItem(name = "", barcode = code)
                    }
                }
            }
        )
    }

    // Food form sheet
    editFood?.let { f ->
        FoodFormSheet(food = f, onDismiss = { editFood = null }) { saved ->
            store.saveFood(saved)
            editFood = null
        }
    }

    // Loading overlay for barcode lookup
    if (looking) {
        Box(
            Modifier.fillMaxWidth().height(120.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(color = T.acc)
                Spacer(Modifier.height(8.dp))
                Text(t("food.looking"), color = T.txt, fontSize = 12.sp)
            }
        }
    }
}

// MARK: - Date formatting
private fun prettyDate(dateStr: String): String = runCatching {
    val d = LocalDate.parse(dateStr)
    val locale = if (L.lang == "en") Locale.ENGLISH else Locale.ITALIAN
    val fmt = DateTimeFormatter.ofPattern("EEEE d MMMM", locale)
    d.format(fmt).replaceFirstChar { it.uppercaseChar() }
}.getOrDefault(dateStr)
