package com.example.river

import androidx.webkit.WebViewCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "river/webview_support",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWebViewVersion" -> result.success(getWebViewVersion())
                else -> result.notImplemented()
            }
        }
    }

    private fun getWebViewVersion(): String? {
        return try {
            WebViewCompat.getCurrentWebViewPackage(this)?.versionName
        } catch (_: Throwable) {
            null
        }
    }
}
