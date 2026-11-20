package com.egyptweb.quick_keep

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** يكتب مباشرة في نفس تخزين تطبيق Flutter (shared_preferences). يرجع true إن أُضيف عنصر جديد. */
object QuickSave {
    fun save(context: Context, text: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.items_v1", null)
        val old = if (raw.isNullOrEmpty()) JSONArray() else JSONArray(raw)

        for (i in 0 until old.length()) {
            if (old.getJSONObject(i).optString("content") == text) return false
        }

        val isLink = Regex("^https?://\\S+$").matches(text)
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")

        val item = JSONObject()
            .put("id", (System.currentTimeMillis() * 1000).toString())
            .put("type", if (isLink) "link" else "text")
            .put("content", text)
            .put("createdAt", fmt.format(Date()))
            .put("pinned", false)

        val out = JSONArray()
        out.put(item)
        for (i in 0 until old.length()) out.put(old.get(i))
        prefs.edit().putString("flutter.items_v1", out.toString()).commit()
        return true
    }

    /** ينسخ صورة (من Uri) إلى مجلد صور التطبيق ويضيفها كعنصر. */
    fun saveImage(context: Context, uri: Uri): Boolean {
        val mime = context.contentResolver.getType(uri)
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "png"
        val dir = File(context.getDir("flutter", Context.MODE_PRIVATE), "images")
        dir.mkdirs()
        val name = "${System.currentTimeMillis() * 1000}.$ext"
        val input = context.contentResolver.openInputStream(uri) ?: return false
        input.use { ins -> File(dir, name).outputStream().use { out -> ins.copyTo(out) } }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.items_v1", null)
        val old = if (raw.isNullOrEmpty()) JSONArray() else JSONArray(raw)
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        val item = JSONObject()
            .put("id", (System.currentTimeMillis() * 1000).toString())
            .put("type", "image")
            .put("content", name)
            .put("createdAt", fmt.format(Date()))
            .put("pinned", false)
        val out = JSONArray()
        out.put(item)
        for (i in 0 until old.length()) out.put(old.get(i))
        prefs.edit().putString("flutter.items_v1", out.toString()).commit()
        return true
    }
}
