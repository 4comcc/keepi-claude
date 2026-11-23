package com.egyptweb.quick_keep

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore

/** يبحث عن أحدث لقطة شاشة جديدة لم تُحفظ ولم تُتجاهل. */
object ShotHelper {
    val permission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    fun hasPerm(ctx: Context) =
        ctx.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private val base: Uri get() = MediaStore.Images.Media.EXTERNAL_CONTENT_URI

    fun uri(id: Long): Uri = ContentUris.withAppendedId(base, id)

    /** يعيد id أحدث لقطة خلال [maxAgeSec] ثانية، أو null. */
    fun latest(ctx: Context, maxAgeSec: Long): Long? {
        if (!hasPerm(ctx)) return null
        return try {
            val dataCol = MediaStore.Images.Media.DATA
            val sel = "(" + (if (Build.VERSION.SDK_INT >= 29)
                "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ? OR " else "") +
                "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ? OR $dataCol LIKE ?)"
            val args = if (Build.VERSION.SDK_INT >= 29)
                arrayOf("%creenshot%", "%creenshot%", "%creenshot%")
            else arrayOf("%creenshot%", "%creenshot%")
            ctx.contentResolver.query(
                base,
                arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DATE_ADDED),
                sel, args, "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )?.use { c ->
                if (!c.moveToFirst()) return null
                val id = c.getLong(0)
                val age = System.currentTimeMillis() / 1000 - c.getLong(1)
                val p = ctx.getSharedPreferences("keepi_native", Context.MODE_PRIVATE)
                if (age > maxAgeSec) return null
                if (p.getLong("last_shot_id", -1) == id) return null
                if (p.getLong("dismissed_shot_id", -1) == id) return null
                id
            }
        } catch (e: Exception) {
            null
        }
    }

    fun save(ctx: Context, id: Long): Boolean {
        val ok = QuickSave.saveImage(ctx, uri(id))
        if (ok) ctx.getSharedPreferences("keepi_native", Context.MODE_PRIVATE)
            .edit().putLong("last_shot_id", id).apply()
        return ok
    }

    fun dismiss(ctx: Context, id: Long) {
        ctx.getSharedPreferences("keepi_native", Context.MODE_PRIVATE)
            .edit().putLong("dismissed_shot_id", id).apply()
    }
}
