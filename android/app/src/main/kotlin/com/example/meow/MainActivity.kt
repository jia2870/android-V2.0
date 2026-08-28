package com.example.meow

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge ignores navigationBarColor on newer Android; color the
        // window itself so the gesture/nav inset never flashes white.
        applySystemBars(Color.parseColor("#12121E"), lightIcons = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myhome/system_ui")
            .setMethodCallHandler { call, result ->
                if (call.method == "setBars") {
                    val color = call.argument<Number>("color")?.toInt() ?: Color.BLACK
                    val lightIcons = call.argument<Boolean>("lightIcons") ?: true
                    applySystemBars(color, lightIcons)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun applySystemBars(color: Int, lightIcons: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }

        window.decorView.setBackgroundColor(color)
        @Suppress("DEPRECATION")
        window.navigationBarColor = color
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility
            flags = if (lightIcons) {
                flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv() and
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            } else {
                flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR or
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }
}
