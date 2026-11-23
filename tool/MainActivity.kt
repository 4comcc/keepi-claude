package com.egyptweb.quick_keep

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

/** يضيف قناة بسيطة للتحكم بالنقطة العائمة من واجهة Flutter. */
class MainActivity : FlutterActivity() {
    companion object {
        @Volatile var visible: MainActivity? = null
    }

    private var pendingPerm: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 91) {
            pendingPerm?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingPerm = null
        }
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
                    "shotPerm" -> result.success(ShotHelper.hasPerm(this))
                    "requestShotPerm" -> {
                        if (ShotHelper.hasPerm(this)) {
                            result.success(true)
                        } else {
                            pendingPerm = result
                            requestPermissions(arrayOf(ShotHelper.permission), 91)
                        }
                    }
                    "latestShot" -> result.success(ShotHelper.latest(this, 300))
                    "saveShot" -> {
                        val id = (call.arguments as Number).toLong()
                        result.success(ShotHelper.save(this, id))
                    }
                    "dismissShot" -> {
                        ShotHelper.dismiss(this, (call.arguments as Number).toLong())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
