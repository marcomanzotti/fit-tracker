package com.marco.fittracker.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.view.HapticFeedbackConstants
import androidx.lifecycle.viewmodel.compose.viewModel
import com.marco.fittracker.data.Store
import com.marco.fittracker.data.headerDate
import com.marco.fittracker.data.trimNum
import kotlinx.coroutines.delay

// MARK: - Shared "environment" objects
val LocalStore = compositionLocalOf<Store> { error("Store not provided") }
val LocalTimer = compositionLocalOf<TimerState> { error("Timer not provided") }
val LocalToast = compositionLocalOf<ToastState> { error("Toast not provided") }

class TimerState {
    var remaining by mutableIntStateOf(0)
    var total by mutableIntStateOf(60)
    var active by mutableStateOf(false)
    var done by mutableStateOf(false)
    var runId by mutableIntStateOf(0)

    fun start(sec: Int) { total = sec; remaining = sec; active = true; done = false; runId++ }
    fun reset() = start(total)
    fun stop() { active = false; done = false }

    val label: String get() = "%d:%02d".format(remaining / 60, remaining % 60)
    val progress: Double get() = if (total > 0) remaining.toDouble() / total else 0.0
}

class ToastState {
    var message by mutableStateOf<String?>(null)
    var seq by mutableIntStateOf(0)
    fun show(m: String) { message = m; seq++ }
}

enum class Tab(val label: String, val sub: String) {
    HOME("Home", "Dashboard"),
    ALLENA("Allena", "Log allenamento"),
    CORPO("Corpo", "Misurazioni & Check-in"),
    STATS("Stats", "Statistiche")
}

@Composable
fun RootScreen() {
    val store: Store = viewModel()
    val timer = remember { TimerState() }
    val toast = remember { ToastState() }
    val view = LocalView.current

    // Countdown loop
    LaunchedEffect(timer.runId, timer.active) {
        if (timer.active) {
            while (timer.remaining > 0) { delay(1000); timer.remaining -= 1 }
            if (timer.active) { timer.done = true; view.performHapticFeedback(HapticFeedbackConstants.CONFIRM) }
        }
    }
    // Toast auto-dismiss
    LaunchedEffect(toast.seq) {
        if (toast.message != null) { delay(1800); toast.message = null }
    }

    CompositionLocalProvider(LocalStore provides store, LocalTimer provides timer, LocalToast provides toast) {
        var tab by remember { mutableStateOf(Tab.HOME) }
        val statusPad = WindowInsets.statusBars.asPaddingValues()
        val navPad = WindowInsets.navigationBars.asPaddingValues()

        Box(Modifier.fillMaxSize().background(T.bg)) {
            Column(Modifier.fillMaxSize()) {
                HeaderBar(tab, Modifier.padding(top = statusPad.calculateTopPadding()))
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp)
                        .padding(top = 14.dp, bottom = 150.dp),
                    verticalArrangement = Arrangement.spacedBy(11.dp)
                ) {
                    when (tab) {
                        Tab.HOME -> HomeScreen { tab = it }
                        Tab.ALLENA -> WorkoutScreen()
                        Tab.CORPO -> BodyScreen()
                        Tab.STATS -> StatsScreen()
                    }
                }
            }

            Column(
                Modifier.align(Alignment.BottomCenter),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (timer.active) TimerStrip()
                NavBar(tab, navPad) { tab = it }
            }

            // Toast
            AnimatedVisibility(
                visible = toast.message != null,
                enter = slideInVertically { -it } + fadeIn(),
                exit = slideOutVertically { -it } + fadeOut(),
                modifier = Modifier.align(Alignment.TopCenter).padding(top = statusPad.calculateTopPadding() + 6.dp)
            ) {
                ToastView(toast.message ?: "")
            }
        }
    }
}

@Composable
private fun ToastView(text: String) {
    Text(
        text.uppercase(),
        color = T.acc2, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(T.c2)
            .padding(vertical = 11.dp, horizontal = 18.dp)
    )
}

@Composable
private fun HeaderBar(tab: Tab, modifier: Modifier = Modifier) {
    val store = LocalStore.current
    val d = headerDate()
    Column(modifier.fillMaxWidth().background(T.bg)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Row {
                    Text("FIT TR", color = T.txt, fontSize = 23.sp, fontWeight = FontWeight.Bold)
                    Text("A", color = T.acc, fontSize = 23.sp, fontWeight = FontWeight.Bold)
                    Text("CKER", color = T.txt, fontSize = 23.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(4.dp))
                Text(tab.sub.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(d.first, color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text(d.second.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
                Text("${trimNum(store.lastWeight)} kg", color = T.acc, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
    }
}

@Composable
private fun NavBar(tab: Tab, navPad: PaddingValues, onSelect: (Tab) -> Unit) {
    val tap = rememberTap()
    Column(Modifier.fillMaxWidth().background(T.c1)) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(T.brd))
        Row(
            Modifier.fillMaxWidth().padding(vertical = 11.dp).padding(bottom = navPad.calculateBottomPadding())
        ) {
            Tab.entries.forEach { t ->
                Column(
                    Modifier.weight(1f).height(50.dp).clickable { tap(); onSelect(t) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Box(Modifier.size(5.dp).clip(CircleShape).background(if (t == tab) T.acc else Color.Transparent))
                    Spacer(Modifier.height(6.dp))
                    Text(
                        t.label.uppercase(),
                        color = if (t == tab) T.acc else T.sub,
                        fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun TimerStrip() {
    val timer = LocalTimer.current
    val tap = rememberTap()
    Row(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(T.c2)
            .padding(vertical = 12.dp, horizontal = 17.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(15.dp)
    ) {
        Column {
            Text("RECUPERO", color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp)
            if (timer.done) Text("VAI", color = T.acc, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            else Text(timer.label, color = T.acc, fontSize = 32.sp, fontWeight = FontWeight.Bold)
        }
        Bar(value = timer.progress, height = 5, modifier = Modifier.weight(1f))
        Icon(Icons.Filled.Refresh, "reset", tint = T.sub, modifier = Modifier.size(28.dp).clickable { tap(); timer.reset() })
        Icon(Icons.Filled.Close, "stop", tint = T.sub, modifier = Modifier.size(28.dp).clickable { tap(); timer.stop() })
    }
}
