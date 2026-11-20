package com.egyptweb.quick_keep

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.widget.Toast

/**
 * تحفظ آخر لقطة شاشة (خلال آخر ساعة) في Keepi دون فتح التطبيق.
 * تُشغَّل من اختصار أيقونة التطبيق. تحتاج إذن قراءة الصور مرة واحدة.
 */
class ScreenshotSaveActivity : Activity() {

    private val perm: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED) {
            run()
        } else {
            requestPermissions(arrayOf(perm), 7)
        }
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, perms, results)
        if (results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED) {
            run()
        } else {
            toast("يلزم السماح بقراءة الصور لحفظ لقطة الشاشة")
            finish()
        }
    }

    private fun run() {
        try {
            toast(saveLatest())
        } catch (e: Exception) {
            toast("تعذّر حفظ لقطة الشاشة")
        }
        finish()
    }

    private fun saveLatest(): String {
        val base = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DATE_ADDED)
        val (sel, args) = if (Build.VERSION.SDK_INT >= 29)
            Pair("${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?", arrayOf("%Screenshots%"))
        else
            Pair("${MediaStore.Images.Media.DATA} LIKE ?", arrayOf("%Screenshots%"))

        contentResolver.query(base, projection, sel, args, "${MediaStore.Images.Media.DATE_ADDED} DESC")?.use { c ->
            if (!c.moveToFirst()) return "لا توجد لقطات شاشة"
            val id = c.getLong(0)
            val addedSec = c.getLong(1)
            if (System.currentTimeMillis() / 1000 - addedSec > 3600) {
                return "لا توجد لقطة شاشة حديثة (خلال آخر ساعة)"
            }
            val prefs = getSharedPreferences("keepi_native", MODE_PRIVATE)
            if (prefs.getLong("last_shot_id", -1) == id) return "هذه اللقطة محفوظة مسبقاً"
            val ok = QuickSave.saveImage(this, ContentUris.withAppendedId(base, id))
            if (ok) prefs.edit().putLong("last_shot_id", id).apply()
            return if (ok) "تم حفظ لقطة الشاشة في Keepi" else "تعذّر حفظ لقطة الشاشة"
        }
        return "تعذّر الوصول إلى الصور"
    }

    private fun toast(m: String) = Toast.makeText(this, m, Toast.LENGTH_LONG).show()
}
