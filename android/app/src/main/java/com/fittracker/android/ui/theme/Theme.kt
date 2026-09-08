package com.fittracker.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val bg = Color(0xFF0b0b0d)
val c1 = Color(0xFF141417)
val c2 = Color(0xFF1f1f23)
val c3 = Color(0xFF2a2a30)
val brd = Color(0xFF2a2a30)
val brd2 = Color(0xFF3a3a42)
val acc = Color(0xFFFFE000)
val acc2 = Color(0xFFFFB000)
val accDim = Color(0xFFC25200)
val txt = Color(0xFFF4EFE6)
val sub = Color(0xFF8A857D)
val mut = Color(0xFF161619)
val red = Color(0xFFFF5A52)
val blue = Color(0xFF4FB8C4)
val good = Color(0xFF7FC950)
val fat = Color(0xFFFF5DA2)
val appleGreen = Color(0xFF92E82A)
val restFill = Color(0xFFECE7DC)

object AppTheme {
    val colors = AppColors()
    val radius = 18.dp
    val radiusS = 12.dp
    val radiusXS = 9.dp
}

class AppColors {
    val bg = Color(0xFF0b0b0d)
    val c1 = Color(0xFF141417)
    val c2 = Color(0xFF1f1f23)
    val c3 = Color(0xFF2a2a30)
    val brd = Color(0xFF2a2a30)
    val brd2 = Color(0xFF3a3a42)
    val acc = Color(0xFFFFE000)
    val acc2 = Color(0xFFFFB000)
    val accDim = Color(0xFFC25200)
    val txt = Color(0xFFF4EFE6)
    val sub = Color(0xFF8A857D)
    val mut = Color(0xFF161619)
    val red = Color(0xFFFF5A52)
    val blue = Color(0xFF4FB8C4)
    val good = Color(0xFF7FC950)
    val fat = Color(0xFFFF5DA2)
    val appleGreen = Color(0xFF92E82A)
    val restFill = Color(0xFFECE7DC)
}

val AppTypography = androidx.compose.material3.Typography(
    // Map to material typography or use custom ones
)

@Composable
fun FitTrackerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = darkColorScheme(
        background = bg,
        surface = c1,
        primary = acc,
        secondary = acc2,
        onBackground = txt,
        onSurface = txt
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        content = content
    )
}

object Fonts {
    fun head(size: Int, weight: FontWeight = FontWeight.SemiBold) = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = size.sp,
        fontWeight = weight,
        letterSpacing = 1.sp
    )

    fun num(size: Int, weight: FontWeight = FontWeight.Bold) = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = size.sp,
        fontWeight = weight
    )
}
