@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.marco.fittracker.ui

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.marco.fittracker.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import java.util.concurrent.Executors

// MARK: - Combined food + recipe picker (tabbed)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodAndRecipePickerSheet(store: Store, onDismiss: () -> Unit, onPick: (FoodLog) -> Unit) {
    var tab by remember { mutableIntStateOf(0) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(0.92f)) {
            // Tab selector
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(t("food.title") to 0, t("recipe.title") to 1).forEach { (label, idx) ->
                    val tap = rememberTap()
                    val sel = tab == idx
                    Text(
                        label.uppercase(), color = if (sel) T.bg else T.sub,
                        fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (sel) T.acc else T.c2)
                            .clickable { tap(); tab = idx }
                            .padding(vertical = 8.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
            when (tab) {
                0 -> FoodPickerContent(store, onDismiss, onPick)
                else -> RecipePickerContent(store, onDismiss, onPick)
            }
        }
    }
}

// MARK: - Food picker content (embedded, no header)
@Composable
fun FoodPickerContent(store: Store, onDismiss: () -> Unit, onPick: (FoodLog) -> Unit) {
    var search by remember { mutableStateOf("") }
    var sortKey by remember { mutableStateOf("recent") }
    var sortAsc by remember { mutableStateOf(false) }
    var editFood by remember { mutableStateOf<FoodItem?>(null) }
    var qtyFood by remember { mutableStateOf<FoodItem?>(null) }
    var showScan by remember { mutableStateOf(false) }
    var looking by remember { mutableStateOf(false) }

    val filtered = remember(store.foods.toList(), search, sortKey, sortAsc) {
        var all = store.recentFoods()
        if (search.isNotEmpty()) all = all.filter { it.name.contains(search, ignoreCase = true) }
        when (sortKey) {
            "alpha" -> all = if (sortAsc) all.sortedBy { it.name.lowercase() }
                             else all.sortedByDescending { it.name.lowercase() }
            "kcal" -> all = if (sortAsc) all.sortedBy { it.k100 } else all.sortedByDescending { it.k100 }
            "ratio" -> all = all.sortedBy { if (it.p100 > 0) it.k100 / it.p100 else Double.MAX_VALUE }
                                .let { if (!sortAsc) it.reversed() else it }
            else -> if (sortAsc) all = all.reversed()
        }
        all
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        // Scan + New buttons
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp), modifier = Modifier.fillMaxWidth()) {
            Box(Modifier.weight(1f)) {
                FilledButton(t("food.scan"), color = T.blue) { showScan = true }
            }
            Box(Modifier.weight(1f)) {
                FilledButton(t("food.new")) { editFood = FoodItem(name = "") }
            }
        }
        Spacer(Modifier.height(8.dp))
        // Search field
        SearchField(search, t("food.search")) { search = it }
        Spacer(Modifier.height(8.dp))
        // Sort bar
        SortPillRow(
            keys = listOf("recent" to t("food.sort.recent"), "alpha" to t("food.sort.alpha"),
                "kcal" to t("food.sort.kcal"), "ratio" to t("food.sort.ratio")),
            selected = sortKey, ascending = sortAsc
        ) { key ->
            if (sortKey == key) sortAsc = !sortAsc else { sortKey = key; sortAsc = false }
        }
        Spacer(Modifier.height(8.dp))
        // List
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 40.dp)
        ) {
            if (filtered.isEmpty()) {
                item {
                    Text(t("food.none"), color = T.sub, fontSize = 12.sp,
                        modifier = Modifier.padding(top = 24.dp).fillMaxWidth())
                }
            }
            items(filtered, key = { it.id }) { f ->
                FoodRow(f,
                    onTap = { qtyFood = f },
                    onEdit = { editFood = f }
                )
            }
        }
    }

    // Quantity sheet
    qtyFood?.let { f ->
        FoodQuantitySheet(f, onDismiss = { qtyFood = null }) { log ->
            onPick(log); onDismiss()
        }
    }

    // Form sheet (create / edit)
    editFood?.let { f ->
        FoodFormSheet(food = f, onDismiss = { editFood = null }) { saved ->
            store.saveFood(saved)
            editFood = null
            qtyFood = saved
        }
    }

    // Barcode scanner
    if (showScan) {
        BarcodeScannerSheet(
            onDismiss = { showScan = false },
            onCode = { code ->
                showScan = false
                val existing = store.food(code)
                if (existing != null) { qtyFood = existing }
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

    if (looking) {
        Box(Modifier.fillMaxWidth().height(100.dp), Alignment.Center) {
            CircularProgressIndicator(color = T.acc)
        }
    }
}

@Composable
fun FoodRow(food: FoodItem, onTap: () -> Unit, onEdit: () -> Unit) {
    val tap = rememberTap()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(11.dp))
            .background(T.c1)
            .border(1.dp, T.brd, RoundedCornerShape(11.dp))
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            Modifier.weight(1f).clickable { tap(); onTap() }
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(food.name, color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                food.brand?.let { brand ->
                    if (brand.isNotEmpty()) {
                        Spacer(Modifier.width(4.dp))
                        Text(brand, color = T.sub, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
            Text(
                "${trimNum(food.k100)} kcal · P ${trimNum(food.p100)} C ${trimNum(food.c100)} F ${trimNum(food.f100)} · /100${food.unit}",
                color = T.sub, fontSize = 10.sp, maxLines = 1
            )
        }
        IconButton(onClick = { tap(); onEdit() }) {
            Text("⚙", color = T.sub, fontSize = 15.sp)
        }
    }
}

// MARK: - Food form sheet (create / edit food)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodFormSheet(food: FoodItem, onDismiss: () -> Unit, onSave: (FoodItem) -> Unit) {
    var name by remember { mutableStateOf(food.name) }
    var brand by remember { mutableStateOf(food.brand ?: "") }
    var k by remember { mutableStateOf(if (food.k100 > 0) trimNum(food.k100) else "") }
    var p by remember { mutableStateOf(if (food.p100 > 0) trimNum(food.p100) else "") }
    var c by remember { mutableStateOf(if (food.c100 > 0) trimNum(food.c100) else "") }
    var f by remember { mutableStateOf(if (food.f100 > 0) trimNum(food.f100) else "") }
    var liquid by remember { mutableStateOf(food.liquid) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(t("food.new_title"), color = T.txt, fontSize = 16.sp,
                        fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    val tap = rememberTap()
                    TextButton(onClick = { tap(); onDismiss() }) { Text(t("close"), color = T.sub) }
                }
            }
            item {
                Card {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        FormField(t("food.name"), name, "Riso / Rice", KeyboardType.Text) {
                            name = titleCased(it)
                        }
                        FormField("${t("food.brand")} (${t("optional")})", brand, "Barilla…", KeyboardType.Text) {
                            brand = it
                        }
                        Lbl("${t("food.per100_label")} (100${if (liquid) "ml" else "g"})", color = T.acc2)
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Column(Modifier.weight(1f)) { FormField("KCAL", k, "350", KeyboardType.Decimal) { k = it } }
                            Column(Modifier.weight(1f)) { FormField("${t("nut.protein")} (g)", p, "7") { p = it } }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Column(Modifier.weight(1f)) { FormField("${t("nut.carbs")} (g)", c, "78") { c = it } }
                            Column(Modifier.weight(1f)) { FormField("${t("nut.fat")} (g)", f, "1") { f = it } }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(t("food.liquid"), color = T.txt, fontSize = 13.sp, modifier = Modifier.weight(1f))
                            Switch(checked = liquid, onCheckedChange = { liquid = it },
                                colors = SwitchDefaults.colors(checkedThumbColor = T.bg, checkedTrackColor = T.acc))
                        }
                    }
                }
            }
            item {
                val tap = rememberTap()
                BigButton(t("food.save_food")) {
                    tap()
                    val nm = name.trim()
                    if (nm.isEmpty()) return@BigButton
                    val saved = food.copy(
                        name = nm,
                        brand = brand.trim().ifEmpty { null },
                        k100 = pf(k), p100 = pf(p), c100 = pf(c), f100 = pf(f),
                        liquid = liquid, lastUsed = today()
                    )
                    onSave(saved)
                }
            }
            item { Spacer(Modifier.height(40.dp)) }
        }
    }
}

// MARK: - Quantity sheet
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodQuantitySheet(food: FoodItem, onDismiss: () -> Unit, onAdd: (FoodLog) -> Unit) {
    var amount by remember { mutableStateOf("100") }
    val grams = pf(amount).coerceAtLeast(0.0)
    val log = food.log(grams)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(food.name, color = T.txt, fontSize = 17.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f), maxLines = 2)
                val tap = rememberTap()
                TextButton(onClick = { tap(); onDismiss() }) { Text(t("close"), color = T.sub) }
            }
            Card {
                FormField("${t("food.amount")} (${food.unit})", amount, "120", KeyboardType.Decimal) { amount = it }
            }
            Card(accent = T.acc) {
                Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
                    MacroTile("${log.kcal}", "kcal", T.acc)
                    MacroTile(trimNum(log.protein), "P", T.blue)
                    MacroTile(trimNum(log.carbs), "C", T.acc2)
                    MacroTile(trimNum(log.fat), "F", T.good)
                }
            }
            val tap = rememberTap()
            BigButton(t("food.add")) {
                tap()
                if (grams > 0) { onAdd(log); onDismiss() }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

// MARK: - Recipe picker content
@Composable
fun RecipePickerContent(store: Store, onDismiss: () -> Unit, onPick: (FoodLog) -> Unit) {
    var search by remember { mutableStateOf("") }
    var editRecipe by remember { mutableStateOf<Recipe?>(null) }
    var qtyRecipe by remember { mutableStateOf<Recipe?>(null) }

    val filtered = remember(store.recipes.toList(), search) {
        val all = store.recentRecipes()
        if (search.isEmpty()) all else all.filter { it.name.contains(search, ignoreCase = true) }
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp), modifier = Modifier.fillMaxWidth()) {
            Box(Modifier.weight(1f)) {
                FilledButton(t("recipe.new")) { editRecipe = Recipe(name = "") }
            }
        }
        Spacer(Modifier.height(8.dp))
        SearchField(search, t("food.search")) { search = it }
        Spacer(Modifier.height(8.dp))
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 40.dp)
        ) {
            if (filtered.isEmpty()) {
                item {
                    Text(t("recipe.none"), color = T.sub, fontSize = 12.sp,
                        modifier = Modifier.padding(top = 24.dp).fillMaxWidth())
                }
            }
            items(filtered, key = { it.id }) { r ->
                RecipeRow(r, onTap = { qtyRecipe = r }, onEdit = { editRecipe = r })
            }
        }
    }

    qtyRecipe?.let { r ->
        RecipeQuantitySheet(r, onDismiss = { qtyRecipe = null }) { log ->
            onPick(log); onDismiss()
        }
    }

    editRecipe?.let { r ->
        RecipeFormSheet(recipe = r, store = store, onDismiss = { editRecipe = null }) { saved ->
            store.saveRecipe(saved)
            editRecipe = null
            qtyRecipe = saved
        }
    }
}

@Composable
fun RecipeRow(recipe: Recipe, onTap: () -> Unit, onEdit: () -> Unit) {
    val tap = rememberTap()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(11.dp))
            .background(T.c1)
            .border(1.dp, T.brd, RoundedCornerShape(11.dp))
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f).clickable { tap(); onTap() }) {
            Text(recipe.name, color = T.txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            val unit = if (recipe.perServing) t("recipe.serving") else "/100g"
            Text("${trimNum(recipe.effK100)} kcal · P ${trimNum(recipe.effP100)} C ${trimNum(recipe.effC100)} F ${trimNum(recipe.effF100)} · $unit",
                color = T.sub, fontSize = 10.sp)
        }
        IconButton(onClick = { tap(); onEdit() }) { Text("⚙", color = T.sub, fontSize = 15.sp) }
    }
}

// MARK: - Recipe quantity sheet
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipeQuantitySheet(recipe: Recipe, onDismiss: () -> Unit, onAdd: (FoodLog) -> Unit) {
    var amount by remember { mutableStateOf(if (recipe.perServing) "1" else "100") }
    val v = pf(amount).coerceAtLeast(0.0)
    val log = recipe.log(v)
    val unit = if (recipe.perServing) t("recipe.serving") else "g"

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(recipe.name, color = T.txt, fontSize = 17.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f), maxLines = 2)
                val tap = rememberTap()
                TextButton(onClick = { tap(); onDismiss() }) { Text(t("close"), color = T.sub) }
            }
            Card {
                FormField("${t("food.amount")} ($unit)", amount, if (recipe.perServing) "1" else "100",
                    KeyboardType.Decimal) { amount = it }
            }
            Card(accent = T.acc) {
                Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
                    MacroTile("${log.kcal}", "kcal", T.acc)
                    MacroTile(trimNum(log.protein), "P", T.blue)
                    MacroTile(trimNum(log.carbs), "C", T.acc2)
                    MacroTile(trimNum(log.fat), "F", T.good)
                }
            }
            val tap = rememberTap()
            BigButton(t("food.add")) { tap(); if (v > 0) { onAdd(log); onDismiss() } }
            Spacer(Modifier.height(40.dp))
        }
    }
}

// MARK: - Recipe form sheet
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipeFormSheet(recipe: Recipe, store: Store, onDismiss: () -> Unit, onSave: (Recipe) -> Unit) {
    var name by remember { mutableStateOf(recipe.name) }
    var inputMode by remember { mutableStateOf(if (recipe.ingredients.isNotEmpty()) "ingredients" else "manual") }
    var perServing by remember { mutableStateOf(recipe.perServing) }
    var servings by remember { mutableStateOf(if (recipe.servings > 0) trimNum(recipe.servings) else "1") }
    var k by remember { mutableStateOf(if (recipe.k100 > 0) trimNum(recipe.k100) else "") }
    var p by remember { mutableStateOf(if (recipe.p100 > 0) trimNum(recipe.p100) else "") }
    var c by remember { mutableStateOf(if (recipe.c100 > 0) trimNum(recipe.c100) else "") }
    var f by remember { mutableStateOf(if (recipe.f100 > 0) trimNum(recipe.f100) else "") }
    var ingredients by remember { mutableStateOf(recipe.ingredients) }
    var showIngredientPicker by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(if (recipe.name.isEmpty()) t("recipe.new") else t("recipe.edit"),
                        color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f))
                    val tap = rememberTap()
                    TextButton(onClick = { tap(); onDismiss() }) { Text(t("close"), color = T.sub) }
                }
            }
            item {
                Card {
                    FormField(t("food.name"), name, t("recipe.name_placeholder"), KeyboardType.Text) {
                        name = it
                    }
                }
            }
            item {
                Card {
                    Lbl(t("recipe.input_mode"), color = T.sub)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("manual" to t("recipe.manual"), "ingredients" to t("recipe.from_ingredients")).forEach { (key, label) ->
                            val tap = rememberTap()
                            val sel = inputMode == key
                            Text(label, color = if (sel) T.bg else T.txt, fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(if (sel) T.acc else T.mut)
                                    .clickable { tap(); inputMode = key }
                                    .padding(horizontal = 16.dp, vertical = 8.dp))
                        }
                    }
                }
            }
            if (inputMode == "manual") {
                item {
                    Card {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(t("recipe.per_serving_toggle"), color = T.txt, fontSize = 13.sp,
                                    modifier = Modifier.weight(1f))
                                Switch(checked = perServing, onCheckedChange = { perServing = it },
                                    colors = SwitchDefaults.colors(checkedThumbColor = T.bg, checkedTrackColor = T.acc))
                            }
                            if (perServing) {
                                Text(t("recipe.per_serving_hint"), color = T.sub, fontSize = 11.sp)
                                FormField(t("recipe.servings"), servings, "4", KeyboardType.Decimal) { servings = it }
                                Lbl(t("recipe.total_macros_label"), color = T.acc2)
                            } else {
                                Lbl("${t("food.per100_label")} (100g)", color = T.acc2)
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Column(Modifier.weight(1f)) { FormField("KCAL", k, "400") { k = it } }
                                Column(Modifier.weight(1f)) { FormField("${t("nut.protein")} (g)", p, "30") { p = it } }
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Column(Modifier.weight(1f)) { FormField("${t("nut.carbs")} (g)", c, "50") { c = it } }
                                Column(Modifier.weight(1f)) { FormField("${t("nut.fat")} (g)", f, "10") { f = it } }
                            }
                        }
                    }
                }
            } else {
                item {
                    Card {
                        Lbl(t("recipe.ingredients"), color = T.acc2)
                        Spacer(Modifier.height(8.dp))
                        if (ingredients.isNotEmpty()) {
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                ingredients.forEach { ing ->
                                    Row(
                                        Modifier.fillMaxWidth()
                                            .clip(RoundedCornerShape(T.radiusS))
                                            .background(T.c2)
                                            .padding(horizontal = 12.dp, vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(Modifier.weight(1f)) {
                                            Text(ing.name, color = T.txt, fontSize = 13.sp,
                                                fontWeight = FontWeight.SemiBold, maxLines = 1)
                                            Text("${trimNum(ing.grams)}g · ${ing.kcal} kcal",
                                                color = T.sub, fontSize = 10.sp)
                                        }
                                        val tap = rememberTap()
                                        TextButton(onClick = { tap(); ingredients = ingredients.filter { it.id != ing.id } }) {
                                            Text("×", color = T.red, fontSize = 16.sp)
                                        }
                                    }
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                        }
                        val tap = rememberTap()
                        TextButton(onClick = { tap(); showIngredientPicker = true }) {
                            Text("+ ${t("recipe.add_ingredient")}", color = T.acc,
                                fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
            item {
                val tap = rememberTap()
                BigButton(t("save")) {
                    tap()
                    val nm = name.trim(); if (nm.isEmpty()) return@BigButton
                    var r = recipe.copy(name = nm, perServing = perServing,
                        servings = pf(servings).coerceAtLeast(1.0), lastUsed = today())
                    r = if (inputMode == "ingredients") {
                        r.copy(ingredients = ingredients).rebuildFromIngredients()
                    } else {
                        r.copy(k100 = pf(k), p100 = pf(p), c100 = pf(c), f100 = pf(f), ingredients = emptyList())
                    }
                    onSave(r)
                }
            }
            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    // Ingredient picker (food picker → convert to RecipeIngredient)
    if (showIngredientPicker) {
        FoodAndRecipePickerSheet(store, onDismiss = { showIngredientPicker = false }) { log ->
            val ing = RecipeIngredient(
                foodId = log.foodId, name = log.name, grams = log.grams,
                k100 = log.k100, p100 = log.p100, c100 = log.c100, f100 = log.f100
            )
            ingredients = ingredients + ing
            showIngredientPicker = false
        }
    }
}

// MARK: - Barcode scanner (CameraX + ML Kit)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BarcodeScannerSheet(onDismiss: () -> Unit, onCode: (String) -> Unit) {
    var hasCameraPermission by remember { mutableStateOf(false) }
    var scanned by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> hasCameraPermission = granted }

    LaunchedEffect(Unit) {
        val perm = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
        hasCameraPermission = perm == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (!hasCameraPermission) permissionLauncher.launch(Manifest.permission.CAMERA)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = T.bg,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            Modifier.fillMaxWidth().height(400.dp).padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("food.scan"), color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f))
                val tap = rememberTap()
                TextButton(onClick = { tap(); onDismiss() }) { Text(t("close"), color = T.sub) }
            }
            if (!hasCameraPermission) {
                Text(t("food.scan_unavailable"), color = T.sub, fontSize = 13.sp)
            } else {
                Text(t("food.scan_hint"), color = T.sub, fontSize = 12.sp)
                CameraPreviewWithBarcode(
                    modifier = Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(T.radius)),
                    onCode = { code ->
                        if (!scanned) {
                            scanned = true
                            onCode(code)
                        }
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalGetImage::class)
@Composable
private fun CameraPreviewWithBarcode(modifier: Modifier = Modifier, onCode: (String) -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }

    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val analyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                val scanner = BarcodeScanning.getClient()
                analyzer.setAnalyzer(executor) { imageProxy ->
                    val mediaImage = imageProxy.image
                    if (mediaImage != null) {
                        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                        scanner.process(image)
                            .addOnSuccessListener { barcodes ->
                                barcodes.firstOrNull { it.format == Barcode.FORMAT_EAN_13 ||
                                    it.format == Barcode.FORMAT_EAN_8 ||
                                    it.format == Barcode.FORMAT_UPC_A }
                                    ?.rawValue?.let { onCode(it) }
                            }
                            .addOnCompleteListener { imageProxy.close() }
                    } else imageProxy.close()
                }
                runCatching {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analyzer)
                }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        },
        modifier = modifier
    )
}

// MARK: - OpenFoodFacts API lookup
fun lookupOpenFoodFacts(barcode: String, callback: (FoodItem?) -> Unit) {
    kotlinx.coroutines.GlobalScope.launch(Dispatchers.IO) {
        val item = runCatching {
            val url = "https://world.openfoodfacts.org/api/v0/product/$barcode.json"
            val json = JSONObject(URL(url).readText())
            if (json.optInt("status") != 1) return@runCatching null
            val product = json.optJSONObject("product") ?: return@runCatching null
            val nutrients = product.optJSONObject("nutriments")
            val name = product.optString("product_name").ifEmpty { product.optString("product_name_it") }
            val brand = product.optString("brands").ifEmpty { null }
            if (name.isEmpty()) return@runCatching null
            FoodItem(
                name = name, brand = brand, barcode = barcode,
                k100 = nutrients?.optDouble("energy-kcal_100g", 0.0) ?: 0.0,
                p100 = nutrients?.optDouble("proteins_100g", 0.0) ?: 0.0,
                c100 = nutrients?.optDouble("carbohydrates_100g", 0.0) ?: 0.0,
                f100 = nutrients?.optDouble("fat_100g", 0.0) ?: 0.0,
                liquid = false
            )
        }.getOrNull()
        withContext(Dispatchers.Main) { callback(item) }
    }
}
