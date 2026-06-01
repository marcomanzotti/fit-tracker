package com.marco.fittracker.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

fun hexColor(hex: String): Color {
    val h = hex.trim().removePrefix("#")
    return when (h.length) {
        3 -> {
            val r = h.substring(0, 1).repeat(2).toInt(16)
            val g = h.substring(1, 2).repeat(2).toInt(16)
            val b = h.substring(2, 3).repeat(2).toInt(16)
            Color(r, g, b)
        }
        8 -> {
            val a = h.substring(0, 2).toInt(16)
            val r = h.substring(2, 4).toInt(16)
            val g = h.substring(4, 6).toInt(16)
            val b = h.substring(6, 8).toInt(16)
            Color(r, g, b, a)
        }
        else -> {
            val r = h.substring(0, 2).toInt(16)
            val g = h.substring(2, 4).toInt(16)
            val b = h.substring(4, 6).toInt(16)
            Color(r, g, b)
        }
    }
}

object T {
    val bg = hexColor("0b0b0d")
    val c1 = hexColor("141417")
    val c2 = hexColor("1f1f23")
    val c3 = hexColor("2a2a30")
    val brd = hexColor("2a2a30")
    val brd2 = hexColor("3a3a42")
    val acc = hexColor("ffe000")   // Lamborghini-bright yellow (was orange ff6a00)
    val acc2 = hexColor("ffb000")
    val accDim = hexColor("c25200")
    val txt = hexColor("f4efe6")
    val sub = hexColor("8a857d")
    val mut = hexColor("161619")
    val red = hexColor("ff5a52")
    val blue = hexColor("4fb8c4")
    val good = hexColor("7fc950")

    val planColors = listOf("ffe000", "ffb000", "ff5a52", "4fb8c4", "7fc950", "b08fff")
    val cardioColors = listOf("4fb8c4", "ff5a52", "7fc950", "b08fff", "ffb000", "53a8ff")

    // Shared "rest day" identity: almost-white chip with a dark moon icon,
    // used identically on the weekly plan, the week strip and the calendar.
    val restFill = hexColor("ece7dc")

    val radius = 18.dp
    val radiusS = 12.dp
    val radiusXS = 9.dp
}
