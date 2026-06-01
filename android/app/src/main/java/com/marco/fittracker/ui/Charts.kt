package com.marco.fittracker.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.graphics.Paint
import kotlin.math.max
import kotlin.math.min

// MARK: - Circular goal ring
@Composable
fun GoalRing(value: Double, color: Color = T.acc, sizeDp: Int = 64) {
    val v = value.coerceIn(0.0, 1.0).toFloat()
    Box(Modifier.size(sizeDp.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(sizeDp.dp)) {
            val stroke = 6.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(
                color = T.c3, startAngle = 0f, sweepAngle = 360f, useCenter = false,
                topLeft = Offset(inset, inset), size = arcSize,
                style = Stroke(width = stroke)
            )
            drawArc(
                color = color, startAngle = -90f, sweepAngle = 360f * v, useCenter = false,
                topLeft = Offset(inset, inset), size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${Math.round(v * 100)}%", color = color, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text("DONE", color = T.sub, fontSize = 8.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        }
    }
}

// MARK: - Shared chart math
data class Series(val label: String, val color: Color, val values: List<Double?>)

private fun DrawScope.drawAxisText(text: String, x: Float, y: Float, align: Paint.Align, color: Color) {
    val paint = Paint().apply {
        this.color = color.toArgb()
        textSize = 8.sp.toPx()
        textAlign = align
        isAntiAlias = true
    }
    drawContext.canvas.nativeCanvas.drawText(text, x, y, paint)
}

private fun Color.toArgb(): Int =
    android.graphics.Color.argb((alpha * 255).toInt(), (red * 255).toInt(), (green * 255).toInt(), (blue * 255).toInt())

private fun smoothPath(pts: List<Offset>): Path {
    val path = Path()
    if (pts.isEmpty()) return path
    path.moveTo(pts[0].x, pts[0].y)
    for (i in 1 until pts.size) {
        val p0 = pts[i - 1]; val p1 = pts[i]
        val midX = (p0.x + p1.x) / 2
        path.cubicTo(midX, p0.y, midX, p1.y, p1.x, p1.y)
    }
    return path
}

/** A multi-series line chart with optional area fill on single series. */
@Composable
fun LineChart(
    xLabels: List<String>,
    series: List<Series>,
    heightDp: Int = 155,
    includeZero: Boolean = false,
    yMin: Double? = null,
    yMax: Double? = null,
    fill: Boolean = false,
    points: Boolean = false
) {
    val all = series.flatMap { it.values.filterNotNull() }
    if (all.isEmpty()) { Spacer(Modifier.height(heightDp.dp)); return }
    var lo = yMin ?: all.min()
    var hi = yMax ?: all.max()
    if (includeZero) lo = min(lo, 0.0)
    if (hi == lo) { hi += 1; lo -= 1 }
    val pad = (hi - lo) * 0.12
    lo -= pad; hi += pad

    Canvas(Modifier.fillMaxWidth().height(heightDp.dp)) {
        val leftPad = 26.dp.toPx()
        val bottomPad = 16.dp.toPx()
        val topPad = 6.dp.toPx()
        val w = size.width - leftPad
        val h = size.height - bottomPad - topPad
        val n = xLabels.size

        fun yOf(v: Double) = topPad + (h - ((v - lo) / (hi - lo) * h)).toFloat()
        fun xOf(i: Int) = leftPad + if (n <= 1) w / 2 else (i.toFloat() / (n - 1) * w)

        // grid lines (y: lo, mid, hi)
        listOf(lo, (lo + hi) / 2, hi).forEach { gv ->
            val gy = yOf(gv)
            drawLine(T.mut, Offset(leftPad, gy), Offset(size.width, gy), 1f)
            drawAxisText(fmtNum(gv), leftPad - 4.dp.toPx(), gy + 3.dp.toPx(), Paint.Align.RIGHT, T.sub)
        }

        // x labels (sparse)
        val step = max(1, n / 5)
        for (i in xLabels.indices step step) {
            drawAxisText(xLabels[i], xOf(i), size.height - 3.dp.toPx(), Paint.Align.CENTER, T.sub)
        }

        series.forEach { s ->
            val pts = s.values.mapIndexedNotNull { i, v -> if (v == null) null else Offset(xOf(i), yOf(v)) }
            if (pts.isEmpty()) return@forEach
            val path = smoothPath(pts)
            if (fill && series.size == 1) {
                val area = Path().apply {
                    addPath(path)
                    lineTo(pts.last().x, topPad + h)
                    lineTo(pts.first().x, topPad + h)
                    close()
                }
                drawPath(area, Brush.verticalGradient(listOf(s.color.copy(alpha = 0.25f), Color.Transparent)))
            }
            drawPath(path, s.color, style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round))
            if (points) pts.forEach { drawCircle(s.color, 3.dp.toPx(), it) }
        }
    }
}

@Composable
fun BarChart(xLabels: List<String>, values: List<Double>, color: Color = T.acc.copy(alpha = 0.55f), heightDp: Int = 120) {
    if (values.isEmpty()) { Spacer(Modifier.height(heightDp.dp)); return }
    val hi = max(values.max(), 1.0)
    Canvas(Modifier.fillMaxWidth().height(heightDp.dp)) {
        val leftPad = 26.dp.toPx()
        val bottomPad = 16.dp.toPx()
        val topPad = 6.dp.toPx()
        val w = size.width - leftPad
        val h = size.height - bottomPad - topPad
        val n = values.size
        val slot = w / n
        val bw = slot * 0.6f

        listOf(0.0, hi / 2, hi).forEach { gv ->
            val gy = topPad + (h - (gv / hi * h)).toFloat()
            drawLine(T.mut, Offset(leftPad, gy), Offset(size.width, gy), 1f)
            drawAxisText(fmtNum(gv), leftPad - 4.dp.toPx(), gy + 3.dp.toPx(), Paint.Align.RIGHT, T.sub)
        }
        // Thin the x-axis labels so dense series (e.g. 14 days) don't overlap.
        val step = max(1, (n + 4) / 5)
        values.indices.forEach { i ->
            val x = leftPad + slot * i + (slot - bw) / 2
            val barH = (values[i] / hi * h).toFloat()
            val y = topPad + h - barH
            drawRoundRect(
                color = color,
                topLeft = Offset(x, y),
                size = Size(bw, barH),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(4.dp.toPx())
            )
            if (i % step == 0) drawAxisText(xLabels.getOrElse(i) { "" }, x + bw / 2, size.height - 3.dp.toPx(), Paint.Align.CENTER, T.sub)
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ChartLegend(series: List<Series>) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
        series.forEach { s ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).clip(CircleShape).background(s.color))
                Spacer(Modifier.width(5.dp))
                Text(s.label, color = T.sub, fontSize = 10.sp)
            }
        }
    }
}

private fun fmtNum(v: Double): String =
    if (v == Math.floor(v)) v.toLong().toString() else ((Math.round(v * 10) / 10.0)).toString()
