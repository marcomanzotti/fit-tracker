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
import com.fittracker.android.data.FoodLog
import com.fittracker.android.data.Recipe
import com.fittracker.android.data.RecipeIngredient
import com.fittracker.android.data.carbs
import com.fittracker.android.data.effC100
import com.fittracker.android.data.effF100
import com.fittracker.android.data.effK100
import com.fittracker.android.data.effP100
import com.fittracker.android.data.fat
import com.fittracker.android.data.kcal
import com.fittracker.android.data.log
import com.fittracker.android.data.protein
import com.fittracker.android.data.rebuildFromIngredients
import com.fittracker.android.localization.L
import com.fittracker.android.utils.Helpers.pf
import com.fittracker.android.utils.Helpers.today
import com.fittracker.android.utils.Helpers.trimNum
import com.fittracker.android.viewmodel.StoreViewModel
import kotlin.math.max

// Kotlin port of ios/FitTracker/Views/RecipePicker.swift. Mirrors FoodPicker.kt's
// structure: a picker (search/sort/list), a quantity sheet that produces a
// FoodLog, and a form to create/edit a recipe either manually or by adding
// saved-food ingredients (reusing FoodPickerSheet for ingredient lookup).

/** Standalone dialog wrapper around [RecipePickerContent]. */
@Composable
fun RecipePickerSheet(
    viewModel: StoreViewModel,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            RecipePickerContent(viewModel = viewModel, onPick = { onPick(it); onDismiss() }, onDismiss = onDismiss)
        }
    }
}

private enum class RecipeSortKey(val labelKey: String) {
    RECENT("food.sort.recent"), ALPHA("food.sort.alpha"), KCAL("food.sort.kcal")
}

private enum class RecipeSheetKind { NONE, FORM, QTY }

@Composable
internal fun RecipePickerContent(
    viewModel: StoreViewModel,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var search by remember { mutableStateOf("") }
    var sortKey by remember { mutableStateOf(RecipeSortKey.RECENT) }
    var sortAsc by remember { mutableStateOf(false) }

    var sheetKind by remember { mutableStateOf(RecipeSheetKind.NONE) }
    var editingRecipe by remember { mutableStateOf<Recipe?>(null) }

    val allRecipes by viewModel.store.recipes.collectAsState()
    val filtered: List<Recipe> = remember(allRecipes, search, sortKey, sortAsc) {
        var list = viewModel.recentRecipes()
        if (search.isNotEmpty()) list = list.filter { it.name.contains(search, ignoreCase = true) }
        list = when (sortKey) {
            RecipeSortKey.RECENT -> if (sortAsc) list.reversed() else list
            RecipeSortKey.ALPHA -> list.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name }).let { if (sortAsc) it else it.reversed() }
            RecipeSortKey.KCAL -> list.sortedBy { it.effK100 }.let { if (sortAsc) it else it.reversed() }
        }
        list
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(L.t("recipe.title"), style = MaterialTheme.typography.headlineSmall)
            IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
        }

        OutlinedButton(
            onClick = { editingRecipe = Recipe(name = ""); sheetKind = RecipeSheetKind.FORM },
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        ) { Text(L.t("recipe.new")) }

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
            RecipeSortKey.entries.forEach { key ->
                val active = sortKey == key
                FilterChip(
                    selected = active,
                    onClick = { if (sortKey == key) sortAsc = !sortAsc else { sortKey = key; sortAsc = false } },
                    label = { Text(L.t(key.labelKey) + if (active) (if (sortAsc) " ↑" else " ↓") else "") }
                )
            }
        }

        if (filtered.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(top = 24.dp), contentAlignment = Alignment.Center) {
                Text(L.t("recipe.none"), style = MaterialTheme.typography.bodySmall)
            }
        } else {
            LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(filtered, key = { it.id }) { r ->
                    RecipeRow(
                        recipe = r,
                        onPick = { editingRecipe = r; sheetKind = RecipeSheetKind.QTY },
                        onEdit = { editingRecipe = r; sheetKind = RecipeSheetKind.FORM }
                    )
                }
            }
        }
    }

    when (sheetKind) {
        RecipeSheetKind.FORM -> {
            editingRecipe?.let { recipe ->
                RecipeFormSheet(
                    viewModel = viewModel,
                    recipe = recipe,
                    onSave = { saved ->
                        val s = viewModel.saveRecipe(saved)
                        editingRecipe = s
                        sheetKind = RecipeSheetKind.QTY
                    },
                    onDelete = { id -> viewModel.deleteRecipe(id); sheetKind = RecipeSheetKind.NONE },
                    onDismiss = { sheetKind = RecipeSheetKind.NONE }
                )
            }
        }
        RecipeSheetKind.QTY -> {
            editingRecipe?.let { recipe ->
                RecipeQuantitySheet(
                    recipe = recipe,
                    onAdd = { log -> onPick(log) },
                    onDismiss = { sheetKind = RecipeSheetKind.NONE }
                )
            }
        }
        RecipeSheetKind.NONE -> {}
    }
}

@Composable
private fun RecipeRow(recipe: Recipe, onPick: () -> Unit, onEdit: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(vertical = 9.dp, horizontal = 12.dp).fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f).clickable(onClick = onPick)) {
                Text(recipe.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                val sub = if (recipe.perServing)
                    "${trimNum(recipe.effK100)} kcal/${L.t("recipe.serving")} · P ${trimNum(recipe.effP100)} C ${trimNum(recipe.effC100)} F ${trimNum(recipe.effF100)}"
                else
                    "${trimNum(recipe.effK100)} kcal · P ${trimNum(recipe.effP100)} C ${trimNum(recipe.effC100)} F ${trimNum(recipe.effF100)} · /100g"
                Text(sub, style = MaterialTheme.typography.bodySmall, maxLines = 1)
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Filled.Tune, contentDescription = L.t("edit"))
            }
        }
    }
}

// MARK: - Recipe quantity / portion picker -> produces a FoodLog
@Composable
fun RecipeQuantitySheet(
    recipe: Recipe,
    onAdd: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var amount by remember { mutableStateOf("") }
    val entered = max(0.0, pf(amount))
    val log = recipe.log(entered)
    val unit = if (recipe.perServing) L.t("recipe.serving") else "g"

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(recipe.name, style = MaterialTheme.typography.headlineSmall, maxLines = 2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
                }

                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        OutlinedTextField(
                            value = amount,
                            onValueChange = { amount = it },
                            label = { Text("${L.t("food.amount")} ($unit)") },
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
                    onClick = { if (entered > 0) onAdd(log) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(L.t("food.add")) }
            }
        }
    }
}

// MARK: - Recipe form (create / edit)
// Two creation modes: manual per-100g/total+servings entry, or from ingredients
// (saved FoodItems with amounts; macros computed via rebuildFromIngredients()).
@Composable
fun RecipeFormSheet(
    viewModel: StoreViewModel,
    recipe: Recipe,
    onSave: (Recipe) -> Unit,
    onDelete: (String) -> Unit = {},
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf(recipe.name) }
    var inputMode by remember { mutableStateOf(if (recipe.ingredients.isNotEmpty()) "ingredients" else "manual") }
    var perServing by remember { mutableStateOf(recipe.perServing) }
    var servingsStr by remember { mutableStateOf(if (recipe.servings > 0) trimNum(recipe.servings) else "1") }

    var k by remember { mutableStateOf(if (recipe.ingredients.isEmpty() && recipe.k100 > 0) trimNum(recipe.k100) else "") }
    var p by remember { mutableStateOf(if (recipe.ingredients.isEmpty() && recipe.p100 > 0) trimNum(recipe.p100) else "") }
    var c by remember { mutableStateOf(if (recipe.ingredients.isEmpty() && recipe.c100 > 0) trimNum(recipe.c100) else "") }
    var f by remember { mutableStateOf(if (recipe.ingredients.isEmpty() && recipe.f100 > 0) trimNum(recipe.f100) else "") }

    var ingredients by remember { mutableStateOf(recipe.ingredients) }
    var pickingIngredient by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(if (recipe.name.isEmpty()) L.t("recipe.new") else L.t("recipe.edit"), style = MaterialTheme.typography.headlineSmall)
                    IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, contentDescription = L.t("close")) }
                }

                LazyColumn(modifier = Modifier.weight(1f).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    item {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                OutlinedTextField(
                                    value = name,
                                    onValueChange = { name = it },
                                    label = { Text(L.t("food.name")) },
                                    placeholder = { Text(L.t("recipe.name_placeholder")) },
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }
                    }

                    item {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text(L.t("recipe.input_mode"), style = MaterialTheme.typography.labelMedium)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    RadioButton(selected = inputMode == "manual", onClick = { inputMode = "manual" })
                                    Text(L.t("recipe.manual"), modifier = Modifier.padding(end = 16.dp))
                                    RadioButton(selected = inputMode == "ingredients", onClick = { inputMode = "ingredients" })
                                    Text(L.t("recipe.from_ingredients"))
                                }
                            }
                        }
                    }

                    if (inputMode == "manual") {
                        item {
                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(L.t("recipe.per_serving_toggle"), style = MaterialTheme.typography.bodyMedium)
                                            Text(L.t("recipe.per_serving_hint"), style = MaterialTheme.typography.bodySmall)
                                        }
                                        Switch(checked = perServing, onCheckedChange = { perServing = it })
                                    }
                                    if (perServing) {
                                        OutlinedTextField(value = servingsStr, onValueChange = { servingsStr = it }, label = { Text(L.t("recipe.servings")) })
                                        Text(L.t("recipe.total_macros_label").uppercase(), style = MaterialTheme.typography.labelSmall)
                                    } else {
                                        Text("PER 100g", style = MaterialTheme.typography.labelSmall)
                                    }

                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        OutlinedTextField(value = k, onValueChange = { k = it }, label = { Text("KCAL") }, modifier = Modifier.weight(1f))
                                        OutlinedTextField(value = p, onValueChange = { p = it }, label = { Text("${L.t("nut.protein")} (g)") }, modifier = Modifier.weight(1f))
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        OutlinedTextField(value = c, onValueChange = { c = it }, label = { Text("${L.t("nut.carbs")} (g)") }, modifier = Modifier.weight(1f))
                                        OutlinedTextField(value = f, onValueChange = { f = it }, label = { Text("${L.t("nut.fat")} (g)") }, modifier = Modifier.weight(1f))
                                    }
                                }
                            }
                        }
                    } else {
                        item {
                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(L.t("recipe.ingredients"), style = MaterialTheme.typography.titleSmall)
                                    ingredients.forEach { ing ->
                                        IngredientRow(ing, onDelete = { ingredients = ingredients.filterNot { it.id == ing.id } })
                                    }
                                    if (ingredients.isNotEmpty()) {
                                        val totK = ingredients.sumOf { it.kcal }
                                        val totP = ingredients.sumOf { it.protein }
                                        val totC = ingredients.sumOf { it.carbs }
                                        val totF = ingredients.sumOf { it.fat }
                                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                            Text(L.t("nut.day_total").uppercase(), style = MaterialTheme.typography.labelSmall)
                                            Text("$totK kcal · P${trimNum(totP)} C${trimNum(totC)} F${trimNum(totF)}", style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                    OutlinedButton(onClick = { pickingIngredient = true }, modifier = Modifier.fillMaxWidth()) {
                                        Text("+ ${L.t("recipe.add_ingredient")}")
                                    }
                                }
                            }

                            Spacer(Modifier.height(12.dp))

                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(L.t("recipe.per_serving_toggle"), style = MaterialTheme.typography.bodyMedium)
                                            Text(L.t("recipe.per_serving_hint"), style = MaterialTheme.typography.bodySmall)
                                        }
                                        Switch(checked = perServing, onCheckedChange = { perServing = it })
                                    }
                                    if (perServing) {
                                        Spacer(Modifier.height(8.dp))
                                        OutlinedTextField(value = servingsStr, onValueChange = { servingsStr = it }, label = { Text(L.t("recipe.servings")) })
                                    }
                                }
                            }
                        }
                    }

                    item {
                        Button(
                            onClick = {
                                val nm = name.trim()
                                if (nm.isEmpty()) return@Button
                                var r = recipe.copy(
                                    name = nm,
                                    perServing = perServing,
                                    servings = max(1.0, pf(servingsStr)),
                                    lastUsed = today()
                                )
                                r = if (inputMode == "ingredients") {
                                    r.copy(ingredients = ingredients).rebuildFromIngredients()
                                } else {
                                    r.copy(ingredients = emptyList(), k100 = pf(k), p100 = pf(p), c100 = pf(c), f100 = pf(f))
                                }
                                onSave(r)
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(L.t("food.save_food")) }
                    }

                    if (recipe.name.isNotEmpty()) {
                        item {
                            TextButton(
                                onClick = { onDelete(recipe.id) },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(L.t("delete"), color = MaterialTheme.colorScheme.error) }
                        }
                    }
                }
            }
        }
    }

    if (pickingIngredient) {
        FoodPickerSheet(
            viewModel = viewModel,
            onPick = { log ->
                ingredients = ingredients + RecipeIngredient(
                    foodId = log.foodId, name = log.name, grams = log.grams,
                    k100 = log.k100, p100 = log.p100, c100 = log.c100, f100 = log.f100
                )
            },
            onDismiss = { pickingIngredient = false }
        )
    }
}

@Composable
private fun IngredientRow(ing: RecipeIngredient, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(vertical = 7.dp, horizontal = 10.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(ing.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                Text("${trimNum(ing.grams)} g · ${ing.kcal} kcal", style = MaterialTheme.typography.bodySmall)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Close, contentDescription = L.t("delete"))
            }
        }
    }
}
