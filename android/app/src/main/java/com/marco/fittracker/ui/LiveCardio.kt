package com.marco.fittracker.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.marco.fittracker.data.CardioType
import com.marco.fittracker.data.Sport
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.t
import com.marco.fittracker.data.today
import com.marco.fittracker.data.trimNum
import kotlinx.coroutines.delay

// MARK: - Live cardio session (real running tracker, mirrors LiveWorkout)
// Starting a cardio activity opens this full live screen: a running clock,
// GPS-tracked distance + live pace/speed for outdoor sports (run/walk/cycle),
// pause/resume, and finish/discard. Ending builds a real WorkoutSession with
// everything tracked — cardio is a first-class session, not a manual form.
@Composable
fun LiveCardio(type: CardioType, onBack: () -> Unit, onSaved: () -> Unit) {
    val store = LocalStore.current
    val toast = LocalToast.current
    val activeCardio = LocalActiveCardio.current
    val tap = rememberTap()
    val view = LocalView.current
    val context = LocalContext.current
    val pc = hexColor(type.color)

    val usesGPS = type.sportType in listOf(Sport.RUNNING, Sport.WALKING, Sport.CYCLING)
    var confirmDiscard by remember { mutableStateOf(false) }
    var hasLocationPerm by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        )
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        hasLocationPerm = granted
    }

    DisposableEffect(Unit) { view.keepScreenOn = true; onDispose { view.keepScreenOn = false } }

    // Ask for location once on open for outdoor sports.
    LaunchedEffect(Unit) {
        if (usesGPS && !hasLocationPerm) permLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    // GPS distance/speed accumulation via the framework LocationManager (no Play
    // Services dependency). Runs only while granted + not paused.
    DisposableEffect(usesGPS, hasLocationPerm) {
        if (!usesGPS || !hasLocationPerm) return@DisposableEffect onDispose { }
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        var last: Location? = null
        val listener = object : LocationListener {
            override fun onLocationChanged(loc: Location) {
                if (activeCardio.paused) { last = null; return }
                if (loc.accuracy > 30f) return
                activeCardio.speedMs = loc.speed.coerceAtLeast(0f).toDouble()
                last?.let { prev ->
                    val step = loc.distanceTo(prev)
                    if (step >= 2f) {
                        activeCardio.gpsDistanceKm = (activeCardio.gpsDistanceKm ?: 0.0) + step / 1000.0
                    }
                }
                last = loc
            }
            @Deprecated("legacy") override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
        }
        try {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 5f, listener)
        } catch (_: SecurityException) {}
        onDispose { lm.removeUpdates(listener) }
    }

    // Paused-aware clock: count active seconds only.
    LaunchedEffect(activeCardio.typeId) {
        while (activeCardio.isActive) {
            delay(1000)
            if (!activeCardio.paused) activeCardio.elapsedSec += 1
        }
    }

    val elapsed = activeCardio.elapsedSec
    val distanceKm = activeCardio.gpsDistanceKm

    fun build(): WorkoutSession = WorkoutSession(
        date = today(), planId = "cardio-${type.id}", planName = type.name, planColor = type.color,
        exercises = emptyList(), sport = type.sport,
        durationSec = if (elapsed > 0) elapsed else null,
        distanceKm = distanceKm
    )
    val estCal = if (elapsed > 0) store.estimateCalories(build()) else null

    // Back row — MINIMIZES (keeps running); never discards.
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        GhostButton("↓ ${t("wk.minimize")}") { onBack() }
        Column(Modifier.weight(1f)) {
            Text(type.name.uppercase(), color = pc, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("${type.sportType.label()} · ${today()}", color = T.sub, fontSize = 10.sp)
        }
    }

    // Big running clock.
    Card(accent = pc) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(t("wk.duration").uppercase(), color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp)
            Spacer(Modifier.height(4.dp))
            Text(fmtClock(elapsed), color = T.txt, fontSize = 44.sp, fontWeight = FontWeight.Bold)
            if (activeCardio.paused) {
                Text(t("wk.paused").uppercase(), color = T.acc2, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
            }
        }
    }

    // Live metrics: distance, pace/speed, calories.
    Card {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LiveTile(t("wk.distance"), distanceKm?.let { trimNum(round2(it)) } ?: "—", "km", pc, Modifier.weight(1f))
            LiveTile(t("wk.speed_pace"), paceValue(build()), build().paceUnit, T.acc2, Modifier.weight(1f))
            LiveTile(t("wk.est_calories"), estCal?.toString() ?: "—", "kcal", T.acc, Modifier.weight(1f))
        }
        if (usesGPS && !hasLocationPerm) {
            Spacer(Modifier.height(10.dp))
            Text(t("wk.gps_hint"), color = T.sub, fontSize = 10.sp)
        }
    }

    // Controls: pause/resume + finish.
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            Modifier.weight(1f).height(52.dp).clip(RoundedCornerShape(T.radiusS)).background(T.acc2)
                .clickable { tap(); activeCardio.paused = !activeCardio.paused },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center
        ) {
            Icon(if (activeCardio.paused) Icons.Filled.PlayArrow else Icons.Filled.Pause, null, tint = T.bg, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text((if (activeCardio.paused) t("wk.resume") else t("wk.pause")).uppercase(),
                color = T.bg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
        Row(
            Modifier.weight(1f).height(52.dp).clip(RoundedCornerShape(T.radiusS)).background(pc)
                .clickable {
                    tap()
                    if (elapsed <= 0) { onSaved(); return@clickable }
                    val s = build().copy(caloriesManual = estCal?.takeIf { it > 0 })
                    store.addSession(s)
                    view.performHapticFeedback(android.view.HapticFeedbackConstants.CONFIRM)
                    toast.show(t("wk.session_saved"))
                    onSaved()
                },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center
        ) {
            Icon(Icons.Filled.Check, null, tint = T.bg, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(t("wk.finish").uppercase(), color = T.bg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
    }

    // Discard (destructive).
    Spacer(Modifier.height(4.dp))
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Text(t("wk.discard_session"), color = T.red, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
            modifier = Modifier.clickable { tap(); confirmDiscard = true })
    }
    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text(t("wk.discard_session"), color = T.txt) },
            text = { Text(t("wk.discard_q"), color = T.sub) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDiscard = false
                    view.performHapticFeedback(android.view.HapticFeedbackConstants.REJECT)
                    onSaved()
                }) { Text(t("wk.discard_session"), color = T.red) }
            },
            dismissButton = { TextButton(onClick = { confirmDiscard = false }) { Text(t("cancel"), color = T.sub) } },
            containerColor = T.c1
        )
    }
}

@Composable
private fun LiveTile(label: String, value: String, unit: String, color: Color, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(T.radiusS)).background(T.c2).padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(label.uppercase(), color = T.sub, fontSize = 8.sp, fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.sp, maxLines = 1, textAlign = TextAlign.Center)
        Spacer(Modifier.height(5.dp))
        Text(value, color = color, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(unit, color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
    }
}

private fun fmtClock(sec: Int): String {
    val h = sec / 3600; val m = (sec % 3600) / 60; val s = sec % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

private fun round2(v: Double): Double = Math.round(v * 100) / 100.0

private fun paceValue(s: WorkoutSession): String {
    val p = s.effectivePace ?: return "—"
    if (!p.isFinite() || p <= 0) return "—"
    if (s.paceIsSpeed) return trimNum(round1(p))
    val m = p.toInt(); val sec = ((p - m) * 60).toInt()
    return "%d:%02d".format(m, sec)
}
private fun round1(v: Double): Double = Math.round(v * 10) / 10.0
