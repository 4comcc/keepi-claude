package com.egyptweb.quick_keep

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.Toast

/** تظهر في قائمة تحديد النص / المشاركة، وتحفظ مباشرة دون فتح التطبيق (نصوص وصور). */
class SaveTextActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val msg = if (intent?.type?.startsWith("image/") == true) saveSharedImage() else saveText()
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(this, "تعذّر الحفظ", Toast.LENGTH_SHORT).show()
        }
        finish()
    }

    private fun saveText(): String {
        val text = (intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            ?: intent?.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?: intent?.dataString)?.toString()?.trim()
        if (text.isNullOrEmpty()) return "لا يوجد نص"
        return if (QuickSave.save(this, text)) "تم الحفظ في Keepi" else "محفوظ مسبقاً في Keepi"
    }

    private fun saveSharedImage(): String {
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else
            @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
        if (uri == null) return "لا توجد صورة"
        return if (QuickSave.saveImage(this, uri)) "تم حفظ الصورة في Keepi" else "تعذّر حفظ الصورة"
    }
}
