package com.egyptweb.quick_keep

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** يضيف قناة بسيطة للتحكم بالنقطة العائمة من واجهة Flutter. */
class MainActivity : FlutterActivity() {
    companion object {
        @Volatile var visible: MainActivity? = null
    }

    override fun onResume() {
        super.onResume()
        visible = this
    }

    override fun onPause() {
        if (visible === this) visible = null
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "keepi/bubble")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDraw" -> result.success(
                        Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)
                    )
                    "requestPermission" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "start" -> {
                        try {
                            val i = Intent(this, FloatingBubbleService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i)
                            else startService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            stopService(Intent(this, FloatingBubbleService::class.java))
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
