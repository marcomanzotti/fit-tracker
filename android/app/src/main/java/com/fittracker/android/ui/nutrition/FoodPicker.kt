package com.fittracker.android.ui.nutrition

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.fittracker.android.data.FoodItem
import com.fittracker.android.data.FoodLog
import com.fittracker.android.data.carbs
import com.fittracker.android.data.fat
import com.fittracker.android.data.fullName
import com.fittracker.android.data.kcal
import com.fittracker.android.data.log
import com.fittracker.android.data.protein
import com.fittracker.android.data.unit
import com.fittracker.android.localization.L
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.utils.Helpers.today
import com.fittracker.android.viewmodel.StoreViewModel
import kotlin.math.max

// Kotlin port of ios/FitTracker/Views/FoodPicker.swift. Barcode scanning is
// out of scope for this port (camera/HealthKit-adjacent feature) so the
// "scan" affordance from the Swift source is dropped; everything else
// (search, sort, create/edit food, log an amount) is real and wired to Store.

/** A list of logged foods with a running total and an "add food" button, bound
 * to a mutable [logs] list via [onLogsChange]. Used both for a meal and for
 * the day-level food list. */
@Composable
fun FoodLogSection(
    viewModel: StoreViewModel,
    logs: List<FoodLog>,
    onLogsChange: (List<FoodLog>) -> Unit
) {
    var picking by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        logs.forEach { log ->
            FoodLogRow(log = log, onDelete = { onLogsChange(logs.filterNot { it.id == log.id }) })
        }

        OutlinedButton(onClick = { picking = true }, modifier = Modifier.fillMaxWidth()) {
            Text(L.t("food.add"))
        }

        if (logs.isNotEmpty()) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(L.t("nut.day_total").uppercase(), style = MaterialTheme.typography.labelSmall)
                Text("${logs.sumOf { it.kcal }} kcal", style = MaterialTheme.typography.titleMedium)
            }
        }
    }

    if (picking) {
        FoodAndRecipePickerSheet(
            viewModel = viewModel,
            onPick = { log -> onLogsChange(logs + log) },
            onDismiss = { picking = false }
        )
    }
}

@Composable
fun FoodLogRow(log: FoodLog, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(log.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                val amount = log.portions?.let { "${trimNum(it)} ${L.t("recipe.serving")}" } ?: "${trimNum(log.grams)} g"
                Text(
                    "$amount · P ${trimNum(log.protein)} C ${trimNum(log.carbs)} F ${trimNum(log.fat)}",
                    style = MaterialTheme.typography.bodySmall
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${log.kcal} kcal", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(end = 4.dp))
                IconButton(onClick = onDelete) {
                    Icon(Icons.Filled.Close, contentDescription = L.t("delete"))
                }
            }
        }
    }
}

private fun trimNum(v: Double): String = com.fittracker.android.utils.Helpers.trimNum(v)

/** Full-screen "sheet" (modal dialog) combining the food and recipe pickers
 * behind a tab switcher — mirrors FoodAndRecipePickerSheet in Swift. */
@Composable
fun FoodAndRecipePickerSheet(
    viewModel: StoreViewModel,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var tab by remember { mutableStateOf(0) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize()) {
                TabRow(selectedTabIndex = tab) {
                    Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text(L.t("food.title")) })
                    Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text(L.t("recipe.title")) })
                }
                Box(modifier = Modifier.weight(1f)) {
                    if (tab == 0) {
                        FoodPickerContent(
                            viewModel = viewModel,
                            standaloneMode = false,
                            onPick = { onPick(it); onDismiss() },
                            onDismiss = onDismiss
                        )
                    } else {
                        RecipePickerContent(
                            viewModel = viewModel,
                            onPick = { onPick(it); onDismiss() },
                            onDismiss = onDismiss
                        )
                    }
                }
            }
        }
    }
}

/** Standalone dialog wrapper around [FoodPickerContent] — used when only the
 * food list (no recipes tab) is wanted. */
@Composable
fun FoodPickerSheet(
    viewModel: StoreViewModel,
    standaloneMode: Boolean = true,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            FoodPickerContent(viewModel = viewModel, standaloneMode = standaloneMode, onPick = { onPick(it); onDismiss() }, onDismiss = onDismiss)
        }
    }
}

private enum class FoodSortKey(val labelKey: String) {
    RECENT("food.sort.recent"), ALPHA("food.sort.alpha"), KCAL("food.sort.kcal"), RATIO("food.sort.ratio")
}

private enum class FoodSheetKind { NONE, FORM, QTY }

@Composable
private fun FoodPickerContent(
    viewModel: StoreViewModel,
    standaloneMode: Boolean,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var search by remember { mutableStateOf("") }
    var sortKey by remember { mutableStateOf(FoodSortKey.RECENT) }
    var sortAsc by remember { mutableStateOf(false) }
    var loadedSort by remember { mutableStateOf(false) }

    var sheetKind by remember { mutableStateOf(FoodSheetKind.NONE) }
    var editingFood by remember { mutableStateOf<FoodItem?>(null) }

    val prefs by viewModel.prefs.collectAsState()
    if (!loadedSort) {
        loadedSort = true
        prefs.foodSort?.let { raw -> FoodSortKey.entries.firstOrNull { it.name.lowercase() == raw } ?.let { sortKey = it } }
        sortAsc = prefs.foodSortAsc ?: false
    }

    val allFoods by viewModel.store.foods.collectAsState()
    val filtered: List<FoodItem> = remember(allFoods, search, sortKey, sortAsc) {
        var list = viewModel.recentFoods()
        if (search.isNotEmpty()) list = list.filter { it.name.contains(search, ignoreCase = true) }
        list = when (sortKey) {
            FoodSortKey.RECENT -> if (sortAsc) list.reversed() else list
            FoodSortKey.ALPHA -> list.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name }).let { if (sortAsc) it else it.reversed() }
            FoodSortKey.KCAL -> list.sortedBy { it.k100 }.let { if (sortAsc) it else it.reversed() }
            FoodSortKey.RATIO -> {
                val ratio = { f: FoodItem -> if (f.p100 > 0) f.k100 / f.p100 else Double.POSITIVE_INFINITY }
                list.sortedBy(ratio).let { if (sortAsc) it else it.reversed() }
            }
        }
        list
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        if (standaloneMode) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(L.t("food.title"), style = MaterialTheme.typography.headlineSmall)
                IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
            }
        }

        OutlinedButton(
            onClick = { editingFood = FoodItem(name = ""); sheetKind = FoodSheetKind.FORM },
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        ) { Text(L.t("food.new")) }

        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text(L.t("food.search")) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            FoodSortKey.entries.forEach { key ->
                val active = sortKey == key
                FilterChip(
                    selected = active,
                    onClick = {
                        if (sortKey == key) sortAsc = !sortAsc else { sortKey = key; sortAsc = false }
                        viewModel.store.updatePrefs { it.copy(foodSort = sortKey.name.lowercase(), foodSortAsc = sortAsc) }
                    },
                    label = { Text(L.t(key.labelKey) + if (active) (if (sortAsc) " ↑" else " ↓") else "") }
                )
            }
        }

        if (filtered.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(top = 24.dp), contentAlignment = Alignment.Center) {
                Text(L.t("food.none"), style = MaterialTheme.typography.bodySmall)
            }
        } else {
            LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(filtered, key = { it.id }) { f ->
                    FoodRow(
                        food = f,
                        onPick = { editingFood = f; sheetKind = FoodSheetKind.QTY },
                        onEdit = { editingFood = f; sheetKind = FoodSheetKind.FORM }
                    )
                }
            }
        }
    }

    when (sheetKind) {
        FoodSheetKind.FORM -> {
            editingFood?.let { food ->
                FoodFormSheet(
                    food = food,
                    onSave = { saved ->
                        val s = viewModel.saveFood(saved)
                        editingFood = s
                        sheetKind = FoodSheetKind.QTY
                    },
                    onDelete = { id -> viewModel.deleteFood(id); sheetKind = FoodSheetKind.NONE },
                    onDismiss = { sheetKind = FoodSheetKind.NONE }
                )
            }
        }
        FoodSheetKind.QTY -> {
            editingFood?.let { food ->
                FoodQuantitySheet(
                    food = food,
                    onAdd = { log -> onPick(log) },
                    onDismiss = { sheetKind = FoodSheetKind.NONE }
                )
            }
        }
        FoodSheetKind.NONE -> {}
    }
}

@Composable
private fun FoodRow(food: FoodItem, onPick: () -> Unit, onEdit: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(vertical = 9.dp, horizontal = 12.dp).fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f).clickable { onPick() }
            ) {
                Row {
                    Text(food.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                    if (!food.brand.isNullOrEmpty()) {
                        Spacer(Modifier.width(4.dp))
                        Text(food.brand!!, style = MaterialTheme.typography.bodySmall, maxLines = 1)
                    }
                }
                Text(
                    "${trimNum(food.k100)} kcal · P ${trimNum(food.p100)} C ${trimNum(food.c100)} F ${trimNum(food.f100)} · /100${food.unit}",
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1
                )
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Filled.Tune, contentDescription = L.t("edit"))
            }
        }
    }
}

// MARK: - Create / edit a saved food (per-100 macros)
@Composable
fun FoodFormSheet(
    food: FoodItem,
    onSave: (FoodItem) -> Unit,
    onDelete: (String) -> Unit = {},
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf(food.name) }
    var brand by remember { mutableStateOf(food.brand ?: "") }
    var k by remember { mutableStateOf(if (food.k100 > 0) trimNum(food.k100) else "") }
    var p by remember { mutableStateOf(if (food.p100 > 0) trimNum(food.p100) else "") }
    var c by remember { mutableStateOf(if (food.c100 > 0) trimNum(food.c100) else "") }
    var f by remember { mutableStateOf(if (food.f100 > 0) trimNum(food.f100) else "") }
    var liquid by remember { mutableStateOf(food.liquid) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(if (food.name.isEmpty()) L.t("food.new_title") else L.t("edit"), style = MaterialTheme.typography.headlineSmall)
                    IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
                }

                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text(L.t("food.name")) }, modifier = Modifier.fillMaxWidth())
                        OutlinedTextField(value = brand, onValueChange = { brand = it }, label = { Text("${L.t("food.brand")} (${L.t("optional")})") }, modifier = Modifier.fillMaxWidth())

                        Text("${L.t("food.per100_label")} (100${if (liquid) "ml" else "g"})".uppercase(), style = MaterialTheme.typography.labelSmall)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(value = k, onValueChange = { k = it }, label = { Text("KCAL") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = p, onValueChange = { p = it }, label = { Text("${L.t("nut.protein")} (g)") }, modifier = Modifier.weight(1f))
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(value = c, onValueChange = { c = it }, label = { Text("${L.t("nut.carbs")} (g)") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = f, onValueChange = { f = it }, label = { Text("${L.t("nut.fat")} (g)") }, modifier = Modifier.weight(1f))
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(L.t("food.liquid"), modifier = Modifier.weight(1f))
                            Switch(checked = liquid, onCheckedChange = { liquid = it })
                        }
                    }
                }

                Button(
                    onClick = {
                        val nm = name.trim()
                        if (nm.isEmpty()) return@Button
                        val br = brand.trim()
                        val saved = food.copy(
                            name = nm,
                            brand = br.ifEmpty { null },
                            k100 = pf(k), p100 = pf(p), c100 = pf(c), f100 = pf(f),
                            liquid = liquid,
                            lastUsed = today()
                        )
                        onSave(saved)
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(L.t("food.save_food")) }

                if (food.name.isNotEmpty()) {
                    TextButton(
                        onClick = { onDelete(food.id) },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) { Text(L.t("delete"), color = MaterialTheme.colorScheme.error) }
                }
            }
        }
    }
}

// MARK: - Enter the amount eaten of a chosen food -> FoodLog
@Composable
fun FoodQuantitySheet(
    food: FoodItem,
    onAdd: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var amount by remember { mutableStateOf("100") }
    val grams = max(0.0, pf(amount))
    val log = food.log(grams)

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(food.name, style = MaterialTheme.typography.headlineSmall, maxLines = 2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
                }

                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        OutlinedTextField(
                            value = amount,
                            onValueChange = { amount = it },
                            label = { Text("${L.t("food.amount")} (${food.unit})") },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                        MacroStat("${log.kcal}", "kcal")
                        MacroStat(trimNum(log.protein), "P")
                        MacroStat(trimNum(log.carbs), "C")
                        MacroStat(trimNum(log.fat), "F")
                    }
                }

                Button(
                    onClick = { if (grams > 0) onAdd(log) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(L.t("food.add")) }
            }
        }
    }
}

@Composable
fun MacroStat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.headlineSmall)
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}
