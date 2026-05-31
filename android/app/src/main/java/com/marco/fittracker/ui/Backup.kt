package com.marco.fittracker.ui

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.marco.fittracker.data.Store
import java.io.File

/** Writes the export to a cache file and fires a share sheet. */
fun shareExport(context: Context, store: Store) {
    val file = File(context.cacheDir, store.exportFileName())
    file.writeText(store.exportText())
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "application/json"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Esporta dati"))
}

fun readImport(context: Context, uri: android.net.Uri): String? =
    runCatching { context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } }.getOrNull()
