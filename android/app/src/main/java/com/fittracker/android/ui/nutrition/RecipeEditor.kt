package com.fittracker.android.ui.nutrition

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RecipeEditor(
    recipe: Recipe,
    onSave: (Recipe) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf(recipe.name) }
    var inputMode by remember { mutableStateOf("manual") }
    var perServing by remember { mutableStateOf(recipe.perServing) }
    var servingsStr by remember { mutableStateOf("1") }
    
    // Manual macros
    var k by remember { mutableStateOf("") }
    var p by remember { mutableStateOf("") }
    var c by remember { mutableStateOf("") }
    var f by remember { mutableStateOf("") }
    
    // Ingredients
    val ingredients = remember { mutableStateListOf<RecipeIngredient>() }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text(if (recipe.name.isEmpty()) "New Recipe" else "Edit Recipe", style = MaterialTheme.typography.headlineSmall)
            IconButton(onClick = onDismiss) { Text("X") }
        }

        LazyColumn(modifier = Modifier.weight(1f).padding(top = 16.dp)) {
            item {
                Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("Recipe Name") },
                        modifier = Modifier.padding(16.dp).fillMaxWidth()
                    )
                }
            }

            item {
                Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Input Mode")
                        Row {
                            RadioButton(selected = inputMode == "manual", onClick = { inputMode = "manual" })
                            Text("Manual")
                            Spacer(Modifier.width(16.dp))
                            RadioButton(selected = inputMode == "ingredients", onClick = { inputMode = "ingredients" })
                            Text("Ingredients")
                        }
                    }
                }
            }

            if (inputMode == "manual") {
                item {
                    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Text("Per Serving")
                                Switch(checked = perServing, onCheckedChange = { perServing = it })
                            }
                            if (perServing) {
                                OutlinedTextField(value = servingsStr, onValueChange = { servingsStr = it }, label = { Text("Servings") })
                            }
                            
                            Text("Macros")
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(value = k, onValueChange = { k = it }, label = { Text("KCAL") }, modifier = Modifier.weight(1f))
                                OutlinedTextField(value = p, onValueChange = { p = it }, label = { Text("Protein") }, modifier = Modifier.weight(1f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(value = c, onValueChange = { c = it }, label = { Text("Carbs") }, modifier = Modifier.weight(1f))
                                OutlinedTextField(value = f, onValueChange = { f = it }, label = { Text("Fat") }, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            } else {
                item {
                    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("Ingredients", style = MaterialTheme.typography.titleMedium)
                            ingredients.forEach { ing ->
                                Text("${ing.name} - ${ing.grams}g")
                            }
                            OutlinedButton(onClick = { /* open food picker */ }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                                Text("+ Add Ingredient")
                            }
                        }
                    }
                }
            }

            item {
                Button(onClick = { /* save logic */ }, modifier = Modifier.fillMaxWidth()) {
                    Text("Save Recipe")
                }
            }
        }
    }
}

// Dummy models
class Recipe(val name: String = "", val perServing: Boolean = false)
class RecipeIngredient(val name: String, val grams: Double)
