package com.fittracker.android.ui.home

import androidx.compose.foundation.layout.*
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.fittracker.android.data.Store
import com.fittracker.android.ui.components.Card
import com.fittracker.android.ui.components.FilledButton
import com.fittracker.android.ui.components.Lbl
import com.fittracker.android.ui.components.StatTile
import com.fittracker.android.ui.theme.AppTheme
import com.fittracker.android.utils.Helpers.pf

/**
 * Home tab — check-in, quick stats and "next workout". A thinner port of
 * RootView.swift's Home section; wired to the real [Store] so the numbers are
 * live rather than placeholders.
 */
@Composable
fun HomeScreen(store: Store) {
    val sessions by store.sessions.collectAsState()
    val plans by store.plans.collectAsState()
    var weightInput by remember { mutableStateOf("") }

    val weight = store.lastWeight
    val bmi = store.bmi(weight)
    val streak = store.streak
    val next = store.nextUp()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(11.dp)
    ) {
        // Check-in card
        Card(bg = AppTheme.colors.c1) {
            Lbl("Check-in", color = AppTheme.colors.acc2)
            Spacer(modifier = Modifier.height(10.dp))
            OutlinedTextField(
                value = weightInput,
                onValueChange = { weightInput = it },
                label = { Text("Weight (kg)") },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(10.dp))
            FilledButton("Save Check-in") {
                val w = pf(weightInput).takeIf { it > 0 }
                store.saveCheckIn(weight = w, sleep = null)
                weightInput = ""
            }
        }

        // Stats Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            StatTile(
                label = "Weight",
                value = if (weight > 0) weight.toString() else "-",
                unit = "KG",
                note = "BMI $bmi",
                modifier = Modifier.weight(1f)
            )
            StatTile(
                label = "Streak",
                value = streak.toString(),
                valueColor = AppTheme.colors.acc,
                note = "Days",
                modifier = Modifier.weight(1f)
            )
            StatTile(
                label = "Sessions",
                value = sessions.size.toString(),
                valueColor = AppTheme.colors.blue,
                note = "Total",
                modifier = Modifier.weight(1f)
            )
        }

        Card {
            Lbl("Next workout", color = AppTheme.colors.acc2)
            Spacer(modifier = Modifier.height(8.dp))
            Text(next?.name ?: if (plans.isEmpty()) "No plans yet" else "Rest day")
        }
    }
}
