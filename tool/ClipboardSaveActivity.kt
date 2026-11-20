package com.egyptweb.quick_keep

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.widget.Toast

/**
 * تقرأ الحافظة وتحفظها فوراً دون إظهار واجهة. تُشغَّل من زر الإعدادات السريعة
 * أو من اختصار أيقونة التطبيق. قراءة الحافظة مسموحة لأن النشاط في الواجهة وله تركيز.
 */
class ClipboardSaveActivity : Activity() {
    private var done = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus || done) return
        done = true
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val isText = cm.primaryClipDescription?.hasMimeType("text/*") == true
            val clip = cm.primaryClip
            val text = if (isText && clip != null && clip.itemCount > 0)
                clip.getItemAt(0).coerceToText(this)?.toString()?.trim() else null
            val msg = when {
                text.isNullOrEmpty() -> "الحافظة فارغة أو ليست نصاً"
                QuickSave.save(this, text) -> "تم حفظ الحافظة في Keepi"
                else -> "محفوظ مسبقاً في Keepi"
            }
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(this, "تعذّر الحفظ", Toast.LENGTH_SHORT).show()
        }
        finish()
    }
}
