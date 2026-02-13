package com.example.river

import android.content.ComponentName
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.webkit.CookieManager
import androidx.webkit.WebViewCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.TreeSet

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "river/webview_cookies",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(getCookies(url))
                }

                "setCookies" -> {
                    val url = call.argument<String>("url")
                    val cookieHeader = call.argument<String>("cookieHeader")
                    if (url.isNullOrBlank() || cookieHeader.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    setCookies(url, cookieHeader) { ok ->
                        result.success(ok)
                    }
                }

                "clearAllCookies" -> {
                    clearAllCookies { ok ->
                        result.success(ok)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "river/app_icon",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "switchIcon" -> {
                    val preset = call.argument<String>("preset")
                    if (preset.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(switchAppIcon(preset))
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "river/system_fonts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemFonts" -> result.success(getSystemFonts())
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

    private fun getCookies(url: String): String? {
        return try {
            CookieManager.getInstance().getCookie(url)
        } catch (_: Throwable) {
            null
        }
    }

    private fun setCookies(
        url: String,
        cookieHeader: String,
        done: (Boolean) -> Unit,
    ) {
        try {
            val manager = CookieManager.getInstance()
            manager.setAcceptCookie(true)

            val cookiePairs = cookieHeader
                .split(";")
                .map { it.trim() }
                .filter { it.contains("=") }

            for (pair in cookiePairs) {
                val index = pair.indexOf('=')
                if (index <= 0) {
                    continue
                }
                val name = pair.substring(0, index).trim()
                val value = pair.substring(index + 1).trim()
                if (name.isEmpty()) {
                    continue
                }
                val attributes = when {
                    name.startsWith("__Host-") -> "Path=/; Secure"
                    else -> "Domain=river-side.cc; Path=/; Secure"
                }
                manager.setCookie(url, "$name=$value; $attributes")
            }

            manager.flush()
            done(true)
        } catch (_: Throwable) {
            done(false)
        }
    }

    private fun clearAllCookies(done: (Boolean) -> Unit) {
        try {
            val manager = CookieManager.getInstance()
            manager.removeAllCookies { cleared ->
                manager.flush()
                done(cleared)
            }
        } catch (_: Throwable) {
            done(false)
        }
    }

    private fun switchAppIcon(preset: String): Boolean {
        val targetAlias = when (preset) {
            "classic" -> ".MainActivityAliasClassic"
            "riverBlue" -> ".MainActivityAliasRiver"
            "minimal" -> ".MainActivityAliasHp"
            else -> return false
        }

        return try {
            val aliases = listOf(
                ".MainActivityAliasClassic",
                ".MainActivityAliasRiver",
                ".MainActivityAliasHp",
            )
            val packageManager = packageManager

            for (alias in aliases) {
                val state = if (alias == targetAlias) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                val component = ComponentName(packageName, "$packageName$alias")
                packageManager.setComponentEnabledSetting(
                    component,
                    state,
                    PackageManager.DONT_KILL_APP,
                )
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun getSystemFonts(): List<String> {
        val files = mutableListOf<File>()
        val fontDirs = listOf(
            "/system/fonts",
            "/product/fonts",
            "/vendor/fonts",
        )

        for (dirPath in fontDirs) {
            try {
                val dir = File(dirPath)
                if (!dir.exists() || !dir.isDirectory) {
                    continue
                }
                files += dir.listFiles()?.toList().orEmpty()
            } catch (_: Throwable) {
                // Ignore invalid dir
            }
        }

        val names = TreeSet<String>(compareBy { it.lowercase(Locale.getDefault()) })
        val styleSuffix = Regex(
            "(?i)[-_ ]?(thin|extralight|ultralight|light|regular|book|medium|semibold|demibold|bold|extrabold|black|italic|oblique|condensed|narrow|display|text|caption|ui|variable|vf)$",
        )

        for (file in files) {
            if (!file.isFile) {
                continue
            }
            val lower = file.name.lowercase(Locale.getDefault())
            if (!(lower.endsWith(".ttf") || lower.endsWith(".otf") || lower.endsWith(".ttc"))) {
                continue
            }
            var base = file.name.substringBeforeLast('.')
            base = base.replace('_', ' ').replace('-', ' ').trim()
            if (base.isEmpty()) {
                continue
            }
            val normalized = styleSuffix.replace(base, "").trim().replace(Regex("\\s+"), " ")
            if (normalized.isNotEmpty()) {
                names += normalized
            }
        }

        names += "sans-serif"
        names += "sans-serif-thin"
        names += "sans-serif-light"
        names += "sans-serif-medium"
        names += "sans-serif-black"
        names += "sans-serif-rounded"
        names += "sans-serif-condensed"
        names += "sans-serif-condensed-medium"
        names += "sans-serif-smallcaps"
        names += "serif"
        names += "monospace"

        return names.toList()
    }
}
