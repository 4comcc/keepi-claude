package com.egyptweb.quick_keep

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.widget.Toast
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs

/**
 * نقطة عائمة فوق التطبيقات: ضغطة = حفظ الحافظة، ضغطة مطوّلة = فتح Keepi، سحب = تحريك.
 */
class FloatingBubbleService : Service() {
    private var wm: WindowManager? = null
    private var bubble: View? = null
    private var lp: WindowManager.LayoutParams? = null
    private var bg: GradientDrawable? = null
    private var icon: ImageView? = null
    private val main = Handler(Looper.getMainLooper())
    private var observer: ContentObserver? = null
    private var alertOff = Runnable { setAlert(false) }

    private fun shotOn(): Boolean = getSharedPreferences(
        "FlutterSharedPreferences", Context.MODE_PRIVATE
    ).getBoolean("flutter.shot_on", false)

    private fun setAlert(on: Boolean) {
        val b = bg ?: return
        main.removeCallbacks(alertOff)
        if (on) {
            b.setColor(Color.parseColor("#FFB703"))
            icon?.setColorFilter(Color.parseColor("#3B2A00"))
            main.postDelayed(alertOff, 120_000)
        } else {
            b.setColor(Color.parseColor("#1E6F5C"))
            icon?.clearColorFilter()
        }
    }

    private fun watchShots() {
        if (observer != null) return
        val o = object : ContentObserver(main) {
            override fun onChange(selfChange: Boolean) {
                if (shotOn() && MainActivity.visible == null &&
                    ShotHelper.latest(this@FloatingBubbleService, 60) != null) setAlert(true)
            }
        }
        try {
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, o
            )
            observer = o
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }
        startAsForeground()
        if (bubble == null) addBubble()
        return START_STICKY
    }

    private fun startAsForeground() {
        val id = 7711
        val chan = "keepi_bubble"
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(chan, "Keepi", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val stop = PendingIntent.getService(
            this, 1,
            Intent(this, FloatingBubbleService::class.java).setAction("STOP"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, chan)
        else Notification.Builder(this)
        val n = b.setSmallIcon(R.drawable.ic_keepi_tile)
            .setContentTitle("Keepi")
            .setContentText("النقطة العائمة تعمل")
            .setOngoing(true)
            .addAction(0, "إيقاف", stop)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(id, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(id, n)
        }
    }

    private fun addBubble() {
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        wm = manager
        val size = dp(40)

        val root = FrameLayout(this)
        val bgd = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#1E6F5C"))
            setStroke(dp(2), Color.parseColor("#FFB703"))
        }
        root.background = bgd
        bg = bgd
        root.alpha = 0.92f
        root.elevation = dp(6).toFloat()
        val icon = ImageView(this)
        this.icon = icon
        icon.setImageResource(R.drawable.ic_keepi_tile)
        val pad = dp(10)
        icon.setPadding(pad, pad, pad, pad)
        root.addView(icon, FrameLayout.LayoutParams(size, size))

        val type = if (Build.VERSION.SDK_INT >= 26)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(
            size, size, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        val prefs = getSharedPreferences("keepi_native", Context.MODE_PRIVATE)
        params.x = prefs.getInt("bx", 0)
        params.y = prefs.getInt("by", dp(240))
        lp = params

        val slop = dp(8)
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var downAt = 0L
        var moved = false
        root.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    downAt = System.currentTimeMillis()
                    moved = false
                    v.animate().scaleX(0.9f).scaleY(0.9f).setDuration(80).start()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        params.x = (startX + dx).toInt()
                        params.y = (startY + dy).toInt()
                        try { manager.updateViewLayout(v, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(80).start()
                    if (moved) {
                        val w = resources.displayMetrics.widthPixels
                        params.x = if (params.x + size / 2 < w / 2) 0 else w - size
                        val h = resources.displayMetrics.heightPixels
                        params.y = params.y.coerceIn(0, h - size)
                        try { manager.updateViewLayout(v, params) } catch (_: Exception) {}
                        prefs.edit().putInt("bx", params.x).putInt("by", params.y).apply()
                    } else if (e.action == MotionEvent.ACTION_UP) {
                        val long = System.currentTimeMillis() - downAt > 500
                        if (long) openApp() else saveClipboard()
                    }
                    true
                }
                else -> false
            }
        }

        try {
            manager.addView(root, params)
            bubble = root
            watchShots()
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private fun saveClipboard() {
        // Keepi مفتوح أمامك: الضغطة تعيدك إلى التطبيق السابق
        val a = MainActivity.visible
        if (a != null) {
            a.moveTaskToBack(true)
            return
        }
        if (shotOn()) {
            val id = ShotHelper.latest(this, 300)
            if (id != null) {
                val ok = ShotHelper.save(this, id)
                setAlert(false)
                Toast.makeText(
                    this,
                    if (ok) "تم حفظ لقطة الشاشة في Keepi" else "تعذّر حفظ لقطة الشاشة",
                    Toast.LENGTH_SHORT
                ).show()
                return
            }
        }
        startActivity(
            Intent(this, ClipboardSaveActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun openApp() {
        val i = packageManager.getLaunchIntentForPackage(packageName) ?: return
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
    }

    override fun onDestroy() {
        observer?.let { contentResolver.unregisterContentObserver(it) }
        observer = null
        main.removeCallbacks(alertOff)
        try { bubble?.let { wm?.removeView(it) } } catch (_: Exception) {}
        bubble = null
        super.onDestroy()
    }
}
