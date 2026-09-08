package com.fittracker.android.ui.nutrition

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun FoodLogSection(
    logs: MutableList<FoodLog>,
    onAddFood: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        logs.forEach { log ->
            FoodLogRow(
                log = log,
                onDelete = { logs.remove(log) }
            )
        }
        
        OutlinedButton(onClick = onAddFood, modifier = Modifier.fillMaxWidth()) {
            Text("+ Add Food")
        }
        
        if (logs.isNotEmpty()) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("TOTAL")
                Text("${logs.sumOf { it.kcal }} kcal")
            }
        }
    }
}

@Composable
fun FoodLogRow(log: FoodLog, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text(log.name, style = MaterialTheme.typography.titleMedium)
                Text("${log.grams}g - P${log.protein} C${log.carbs} F${log.fat}", style = MaterialTheme.typography.bodySmall)
            }
            Row {
                Text("${log.kcal} kcal", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(end = 8.dp))
                IconButton(onClick = onDelete, modifier = Modifier.size(24.dp)) {
                    Text("X") // Use Icon
                }
            }
        }
    }
}

@Composable
fun FoodPickerSheet(
    standaloneMode: Boolean = true,
    onPick: (FoodLog) -> Unit,
    onDismiss: () -> Unit
) {
    var search by remember { mutableStateOf("") }
    
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        if (standaloneMode) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Foods", style = MaterialTheme.typography.headlineSmall)
                IconButton(onClick = onDismiss) { Text("X") }
            }
        }
        
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 8.dp)) {
            Button(onClick = { /* open scanner */ }, modifier = Modifier.weight(1f)) {
                Text("Scan")
            }
            OutlinedButton(onClick = { /* open form */ }, modifier = Modifier.weight(1f)) {
                Text("New")
            }
        }
        
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text("Search foods...") },
            modifier = Modifier.fillMaxWidth()
        )
        
        LazyColumn(modifier = Modifier.weight(1f).padding(top = 8.dp)) {
            // Food rows
            item { Text("Food items list...") }
        }
    }
}

@Composable
fun FoodFormSheet(
    food: FoodItem,
    onSave: (FoodItem) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf(food.name) }
    var brand by remember { mutableStateOf(food.brand ?: "") }
    var k by remember { mutableStateOf("") }
    var p by remember { mutableStateOf("") }
    var c by remember { mutableStateOf("") }
    var f by remember { mutableStateOf("") }
    var liquid by remember { mutableStateOf(food.liquid) }
    
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text(if (food.name.isEmpty()) "New Food" else "Edit Food", style = MaterialTheme.typography.headlineSmall)
            IconButton(onClick = onDismiss) { Text("X") }
        }
        
        Card(modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = brand, onValueChange = { brand = it }, label = { Text("Brand") }, modifier = Modifier.fillMaxWidth())
                
                Text("PER 100g", modifier = Modifier.padding(top = 8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = k, onValueChange = { k = it }, label = { Text("KCAL") }, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = p, onValueChange = { p = it }, label = { Text("Protein") }, modifier = Modifier.weight(1f))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = c, onValueChange = { c = it }, label = { Text("Carbs") }, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = f, onValueChange = { f = it }, label = { Text("Fat") }, modifier = Modifier.weight(1f))
                }
                
                Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                    Text("Liquid (ml)")
                    Switch(checked = liquid, onCheckedChange = { liquid = it })
                }
            }
        }
        
        Button(onClick = { /* save logic */ }, modifier = Modifier.fillMaxWidth()) {
            Text("Save Food")
        }
    }
}

// Dummy models
class FoodLog(val id: String = "", val name: String = "", val kcal: Int = 0, val grams: Double = 0.0, val protein: Double = 0.0, val carbs: Double = 0.0, val fat: Double = 0.0)
class FoodItem(val name: String = "", val brand: String? = null, val liquid: Boolean = false)
