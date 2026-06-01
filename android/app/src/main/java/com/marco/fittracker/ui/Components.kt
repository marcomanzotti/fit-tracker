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
        if (info != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Lbl(label)
                Spacer(Modifier.width(4.dp))
                InfoButton(info)
            }
        } else Lbl(label)
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
