package com.egyptweb.quick_keep

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

/** تظهر في قائمة تحديد النص / المشاركة، وتحفظ مباشرة دون فتح التطبيق. */
class SaveTextActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = (intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            ?: intent?.getCharSequenceExtra(Intent.EXTRA_TEXT))?.toString()?.trim()
        if (!text.isNullOrEmpty()) {
            try {
                val added = QuickSave.save(this, text)
                Toast.makeText(
                    this,
                    if (added) "تم الحفظ في Keepi" else "محفوظ مسبقاً في Keepi",
                    Toast.LENGTH_SHORT
                ).show()
            } catch (e: Exception) {
                Toast.makeText(this, "تعذّر الحفظ", Toast.LENGTH_SHORT).show()
            }
        }
        finish()
    }
}
