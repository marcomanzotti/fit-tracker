package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.ui.text.input.KeyboardType
import com.marco.fittracker.data.WorkoutSession
import com.marco.fittracker.data.paceStr
import com.marco.fittracker.data.pf
import com.marco.fittracker.data.t
import com.marco.fittracker.data.trimNum

// MARK: - Haptics
@Composable
fun rememberTap(): () -> Unit {
    val view = LocalView.current
    return { view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY) }
}

// MARK: - Card container
@Composable
fun Card(
    modifier: Modifier = Modifier,
    accent: Color? = null,
    bg: Color = T.c1,
    borderColor: Color = T.brd,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(T.radius))
            .background(bg)
            .then(
                if (accent != null) Modifier.drawBehind {
                    drawRect(color = accent, size = Size(3.dp.toPx(), size.height))
                } else Modifier
            )
            .border(1.dp, borderColor, RoundedCornerShape(T.radius))
            .padding(vertical = 15.dp, horizontal = 16.dp),
        content = content
    )
}

// MARK: - Section / card label
@Composable
fun Lbl(text: String, color: Color = T.sub, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        color = color,
        fontSize = 10.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 2.sp,
        modifier = modifier
    )
}

// MARK: - Small stat tile
@Composable
fun RowScopeStatTile(
    label: String,
    value: String,
    unit: String? = null,
    valueColor: Color = T.txt,
    note: String? = null,
    info: String? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier
            .clip(RoundedCornerShape(T.radiusS))
            .background(T.c2)
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
            .padding(vertical = 13.dp, horizontal = 12.dp)
    ) {
        // Keep multi-word / long labels ("Weekly load", "Monotony") on a single
        // line instead of breaking a letter ("y") onto the next row: no wrap +
        // tighter letter spacing so the whole word fits the narrow tile.
        if (info != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(label.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.5.sp, maxLines = 1, softWrap = false, modifier = Modifier.weight(1f, fill = false))
                Spacer(Modifier.width(4.dp))
                InfoButton(info)
            }
        } else Text(label.uppercase(), color = T.sub, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.5.sp, maxLines = 1, softWrap = false)
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, color = valueColor, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            if (unit != null) {
                Spacer(Modifier.width(2.dp))
                Text(unit, color = T.sub, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        if (note != null) {
            Spacer(Modifier.height(4.dp))
            Text(note, color = T.sub, fontSize = 10.sp)
        }
    }
}

// MARK: - Progress bar
@Composable
fun Bar(value: Double, gradient: List<Color> = listOf(T.acc, T.acc2), height: Int = 7, modifier: Modifier = Modifier) {
    val v = value.coerceIn(0.0, 1.0).toFloat()
    Box(
        modifier
            .fillMaxWidth()
            .height(height.dp)
            .clip(CircleShape)
            .background(T.mut)
    ) {
        Box(
            Modifier
                .fillMaxWidth(v)
                .height(height.dp)
                .clip(CircleShape)
                .background(Brush.horizontalGradient(gradient))
        )
    }
}

// MARK: - Tag / Badge
@Composable
fun Tag(text: String, color: Color = T.sub, bg: Color = T.mut) {
    Text(
        text, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(CircleShape).background(bg).padding(vertical = 4.dp, horizontal = 9.dp)
    )
}

@Composable
fun Badge(text: String, color: Color = T.acc2, bg: Color = T.acc.copy(alpha = 0.14f)) {
    Text(
        text.uppercase(), color = color, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.8.sp,
        modifier = Modifier.clip(RoundedCornerShape(7.dp)).background(bg).padding(vertical = 4.dp, horizontal = 10.dp)
    )
}

// MARK: - Buttons
@Composable
fun FilledButton(title: String, color: Color = T.acc, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val tap = rememberTap()
    Box(
        modifier
            .fillMaxWidth()
            .height(46.dp)
            .clip(RoundedCornerShape(T.radiusS))
            .background(color)
            .clickable { tap(); onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(title, color = T.bg, fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun BigButton(title: String, color: Color = T.acc, onClick: () -> Unit) {
    val tap = rememberTap()
    Box(
        Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(15.dp))
            .background(color)
            .clickable { tap(); onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(title.uppercase(), color = T.bg, fontSize = 16.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
    }
}

@Composable
fun GhostButton(title: String, color: Color = T.sub, onClick: () -> Unit) {
    val tap = rememberTap()
    Box(
        Modifier
            .heightIn(min = 38.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(T.c2)
            .border(1.dp, T.brd, RoundedCornerShape(9.dp))
            .clickable { tap(); onClick() }
            .padding(vertical = 8.dp, horizontal = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(title, color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}

// MARK: - Inputs
@Composable
fun InputField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Decimal,
    modifier: Modifier = Modifier
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        textStyle = TextStyle(color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Medium),
        cursorBrush = SolidColor(T.acc),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        singleLine = keyboardType != KeyboardType.Text || true,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(T.radiusS))
            .background(T.c2)
            .border(1.dp, T.brd, RoundedCornerShape(T.radiusS))
            .padding(vertical = 13.dp, horizontal = 15.dp),
        decorationBox = { inner ->
            if (value.isEmpty()) Text(placeholder, color = T.sub, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            inner()
        }
    )
}

@Composable
fun SmallNumField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "–",
    highlight: Boolean = false
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        textStyle = TextStyle(color = T.txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center),
        cursorBrush = SolidColor(T.acc),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        singleLine = true,
        modifier = Modifier
            .width(66.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(if (highlight) T.acc.copy(alpha = 0.07f) else T.c2)
            .border(1.dp, if (highlight) T.acc else T.brd, RoundedCornerShape(9.dp))
            .padding(vertical = 10.dp),
        decorationBox = { inner ->
            Box(contentAlignment = Alignment.Center) {
                if (value.isEmpty()) Text(placeholder, color = T.sub, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                inner()
            }
        }
    )
}

// MARK: - Uniform field label (fixed height so adjacent input boxes align even
// when only one of them carries an info button).
@Composable
fun FieldLabel(text: String, info: String? = null) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.height(18.dp)) {
        Text(text.uppercase(), color = T.sub, fontSize = 9.sp, fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.sp, maxLines = 1, softWrap = false)
        if (info != null) { Spacer(Modifier.width(3.dp)); InfoButton(info) }
    }
}

// MARK: - Duration field (H / M / S) bound to a total-seconds value.
@Composable
fun HMSField(label: String, seconds: Int?, info: String? = null, onChange: (Int?) -> Unit) {
    var h by remember { mutableStateOf(seconds?.takeIf { it >= 3600 }?.let { (it / 3600).toString() } ?: "") }
    var m by remember { mutableStateOf(if (seconds != null) ((seconds % 3600) / 60).toString() else "") }
    var s by remember { mutableStateOf(seconds?.takeIf { it % 60 != 0 }?.let { (it % 60).toString() } ?: "") }
    fun emit() {
        val total = (h.toIntOrNull() ?: 0) * 3600 + (m.toIntOrNull() ?: 0) * 60 + (s.toIntOrNull() ?: 0)
        onChange(if (total > 0) total else null)
    }
    Column(Modifier.fillMaxWidth()) {
        FieldLabel(label, info)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) { HMSBox(h, "dur.h", "0") { h = it; emit() } }
            Box(Modifier.weight(1f)) { HMSBox(m, "dur.m", "30") { m = it; emit() } }
            Box(Modifier.weight(1f)) { HMSBox(s, "dur.s", "00") { s = it; emit() } }
        }
    }
}

@Composable
private fun HMSBox(value: String, unitKey: String, ph: String, onChange: (String) -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        BasicTextField(
            value = value, onValueChange = onChange,
            textStyle = TextStyle(color = T.txt, fontSize = 16.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.Center),
            cursorBrush = SolidColor(T.acc),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(T.radiusS)).background(T.c2)
                .border(1.dp, T.brd, RoundedCornerShape(T.radiusS)).padding(vertical = 13.dp),
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.Center) {
                    if (value.isEmpty()) Text(ph, color = T.sub, fontSize = 16.sp, fontWeight = FontWeight.Medium)
                    inner()
                }
            }
        )
        Spacer(Modifier.height(4.dp))
        Text(t(unitKey), color = T.sub, fontSize = 8.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
    }
}

// MARK: - Pace / speed field (per-sport unit; auto from distance + duration,
// editable to override). The box always holds a plain decimal; the caption shows
// the readable form (m:ss for min-based paces).
@Composable
fun PaceField(session: WorkoutSession, manual: Double?, onChange: (Double?) -> Unit) {
    val auto = session.autoPace
    fun dec(v: Double): String = trimNum(Math.round(v * 10) / 10.0)
    fun readable(v: Double): String =
        if (session.paceIsSpeed) "${dec(v)} ${session.paceUnit}" else "${paceStr(v)} ${session.paceUnit}"
    var text by remember { mutableStateOf(manual?.let { dec(it) } ?: "") }
    Column(Modifier.fillMaxWidth()) {
        FieldLabel("${t(if (session.paceIsSpeed) "wk.speed" else "wk.pace")} (${session.paceUnit})", "pace")
        Spacer(Modifier.height(6.dp))
        InputField(text, {
            text = it
            val v = pf(it)
            onChange(if (it.isEmpty() || v <= 0) null else v)
        }, auto?.let { dec(it) } ?: "—", KeyboardType.Decimal)
        val shown = if (pf(text) > 0) pf(text) else auto
        if (shown != null) {
            Spacer(Modifier.height(4.dp))
            Text("${if (text.isEmpty()) t("wk.pace_auto") else t("wk.pace")} · ${readable(shown)}",
                color = T.sub, fontSize = 9.sp)
        }
    }
}

// MARK: - Empty state
@Composable
fun EmptyBox(title: String, text: String) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 36.dp, horizontal = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(title.uppercase(), color = T.sub, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        Text(text, color = T.sub, fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 18.sp)
    }
}

// MARK: - Color swatch picker (wraps the full sport palette)
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ColorSwatches(selected: String, onSelect: (String) -> Unit) {
    val tap = rememberTap()
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        T.sportColors.forEach { c ->
            Box(
                Modifier.size(30.dp).clip(CircleShape).background(hexColor(c))
                    .border(if (selected == c) 2.dp else 0.dp, T.txt, CircleShape)
                    .clickable { tap(); onSelect(c) }
            )
        }
    }
}

// MARK: - Wrapping chips row
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ChipsFlow(items: List<String>, color: Color = T.blue, bg: Color = T.blue.copy(alpha = 0.1f)) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
        items.forEach { item ->
            Text(
                item, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(bg).padding(vertical = 3.dp, horizontal = 8.dp)
            )
        }
    }
}
