package com.fittracker.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.fittracker.android.data.Store
import com.fittracker.android.localization.L
import com.fittracker.android.ui.body.BodyScreen
import com.fittracker.android.ui.home.HomeScreen
import com.fittracker.android.ui.nutrition.NutritionScreen
import com.fittracker.android.ui.stats.StatsScreen
import com.fittracker.android.ui.theme.FitTrackerTheme
import com.fittracker.android.ui.train.WorkoutScreen
import com.fittracker.android.viewmodel.ActiveCardioViewModel
import com.fittracker.android.viewmodel.ActiveWorkoutViewModel
import com.fittracker.android.viewmodel.BodyViewModel
import com.fittracker.android.viewmodel.StatsViewModel
import com.fittracker.android.viewmodel.StoreViewModel
import com.fittracker.android.viewmodel.ToastCenter

/** The five main sections of the app (mirrors RootView.swift's tab bar). */
private enum class Tab(val route: String, val labelKey: String) {
    HOME("home", "nav.home"),
    TRAIN("train", "nav.train"),
    BODY("body", "nav.body"),
    NUTRITION("nutrition", "nav.nutrition"),
    STATS("stats", "nav.stats")
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            FitTrackerTheme {
                // Single Store instance for the whole app, created once and shared
                // down to every tab — mirrors the iOS app's single @StateObject Store
                // injected as an environmentObject from FitTrackerApp.swift.
                val store = remember { Store(applicationContext) }
                val storeViewModel = remember { StoreViewModel(store) }
                val activeWorkout = remember { ActiveWorkoutViewModel(store) }
                val activeCardio = remember { ActiveCardioViewModel(store) }
                val bodyViewModel = remember { BodyViewModel(store) }
                val statsViewModel = remember { StatsViewModel(store) }
                val toast = remember { ToastCenter() }

                val navController = rememberNavController()

                Scaffold(
                    bottomBar = {
                        val backStackEntry by navController.currentBackStackEntryAsState()
                        val currentRoute = backStackEntry?.destination?.route
                        NavigationBar {
                            Tab.entries.forEach { tab ->
                                NavigationBarItem(
                                    selected = currentRoute == tab.route,
                                    onClick = {
                                        navController.navigate(tab.route) {
                                            popUpTo(navController.graph.findStartDestination().id) {
                                                saveState = true
                                            }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    },
                                    icon = { Icon(tabIcon(tab), contentDescription = L.t(tab.labelKey)) },
                                    label = { Text(L.t(tab.labelKey)) }
                                )
                            }
                        }
                    }
                ) { padding ->
                    NavHost(
                        navController = navController,
                        startDestination = Tab.HOME.route,
                        modifier = Modifier.padding(padding)
                    ) {
                        composable(Tab.HOME.route) { HomeScreen(store) }
                        composable(Tab.TRAIN.route) {
                            WorkoutScreen(
                                viewModel = storeViewModel,
                                activeWorkout = activeWorkout,
                                activeCardio = activeCardio,
                                toast = toast
                            )
                        }
                        composable(Tab.BODY.route) { BodyScreen(bodyViewModel, toast) }
                        composable(Tab.NUTRITION.route) { NutritionScreen(storeViewModel) }
                        composable(Tab.STATS.route) { StatsScreen(statsViewModel) }
                    }
                }
            }
        }
    }
}

private fun tabIcon(tab: Tab) = when (tab) {
    Tab.HOME -> Icons.Filled.Home
    Tab.TRAIN -> Icons.Filled.FitnessCenter
    Tab.BODY -> Icons.Filled.Straighten
    Tab.NUTRITION -> Icons.Filled.Restaurant
    Tab.STATS -> Icons.Filled.BarChart
}
