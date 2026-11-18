package com.egyptweb.quick_keep

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * تظهر في قائمة تحديد النص (Keepi)، تحفظ النص مباشرة
 * في نفس تخزين التطبيق دون فتح واجهته، ثم تغلق نفسها.
 */
class SaveTextActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = (intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            ?: intent?.getCharSequenceExtra(Intent.EXTRA_TEXT))?.toString()?.trim()
        if (text.isNullOrEmpty()) {
            finish()
            return
        }
        try {
            val added = save(text)
            Toast.makeText(
                this,
                if (added) "تم الحفظ في Keepi" else "محفوظ مسبقاً في Keepi",
                Toast.LENGTH_SHORT
            ).show()
        } catch (e: Exception) {
            Toast.makeText(this, "تعذّر الحفظ", Toast.LENGTH_SHORT).show()
        }
        finish()
    }

    private fun save(text: String): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
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
}
