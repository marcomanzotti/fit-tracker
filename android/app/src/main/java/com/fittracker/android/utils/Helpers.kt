package com.fittracker.android.utils

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Calendar

object Helpers {
    val isoFormatter: SimpleDateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun today(): String = isoFormatter.format(Date())

    fun pf(s: String): Double {
        return s.replace(",", ".").toDoubleOrNull() ?: 0.0
    }

    fun fmtShort(date: String): String {
        return if (date.length >= 5) date.substring(5) else date
    }

    fun fmtDM(date: String): String {
        val p = date.split("-")
        if (p.size == 3) {
            return "${p[2]}/${p[1]}"
        }
        return date
    }

    fun fmtDuration(seconds: Int): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        if (h > 0) return String.format("%dh %02dm", h, m)
        if (m > 0) return if (s > 0) String.format("%dm %02ds", m, s) else "${m}m"
        return "${s}s"
    }

    fun trimNum(v: Double): String {
        if (v == Math.round(v).toDouble()) {
            return v.toInt().toString()
        }
        return String.format(Locale.US, "%s", v)
    }
}

