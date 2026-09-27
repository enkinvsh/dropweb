package app.dropweb

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.appcompat.app.AppCompatDelegate
import app.dropweb.plugins.AppPlugin
import app.dropweb.plugins.ServicePlugin
import app.dropweb.plugins.TilePlugin
import app.dropweb.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    // Cold start route delivered via Intent extra. Consumed once by Dart via
    // `getInitialRoute`. Hot/warm start routes are pushed through
    // [navigationSink] in [onNewIntent].
    private var initialRoute: String? = null
    private var navigationSink: EventChannel.EventSink? = null
    // This instance's adb-remote sink (see companion debugSink).
    private var ownDebugSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        applyAppTheme()

        // Post-reboot Android restores our Task from persistent state and passes
        // a savedInstanceState pointing at the killed process's FlutterEngine.
        // FlutterActivity.onCreate then blocks trying to restore engine state
        // that doesn't exist — splash hangs forever. We don't use Flutter's
        // restoration API, so always start fresh.
        super.onCreate(null)

        // Capture deep-link route from notification (or other sender) before
        // Flutter engine is ready. Dart picks it up via the
        // `app.dropweb/navigation` MethodChannel on init.
        initialRoute = intent?.getStringExtra(EXTRA_ROUTE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val modeId = getPreferredHighRefreshModeId()
            if (modeId != 0) {
                val attrs = window.attributes
                attrs.preferredDisplayModeId = modeId
                window.attributes = attrs
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Contextual battery-optimization prompt. Runs every resume but is
        // internally gated so it fires at most once, and only after real VPN
        // use (see maybeRequestBatteryExemption). An Activity context is
        // guaranteed here and the app is in the foreground.
        maybeRequestBatteryExemption()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Subsequent launches (activity already in stack — SINGLE_TOP delivers
        // the new intent here). Forward the route to Dart via EventChannel.
        // Fall back to caching as `initialRoute` if Dart hasn't subscribed yet
        // (race during process warm-up).
        setIntent(intent)
        val route = intent.getStringExtra(EXTRA_ROUTE) ?: return
        val sink = navigationSink
        if (sink != null) {
            sink.success(route)
        } else {
            initialRoute = route
        }
    }

    // Prefer the highest refresh rate WITHOUT ever changing the panel resolution.
    //
    // History: the FlClash-inherited version picked the max-refresh mode across
    // ALL display modes, ignoring resolution. Per AOSP DisplayModeDirector
    // (Vote.java), an app's preferredDisplayModeId vote also votes for that
    // mode's SIZE (PRIORITY_APP_REQUEST_SIZE=7), which OUTRANKS the user's
    // resolution setting (PRIORITY_USER_SETTING_DISPLAY_PREFERRED_SIZE=4). On
    // multi-resolution panels (Pixel 7 Pro: 1080x2340 + 1440x3120) that forced
    // a global resolution switch while our window was focused; flipping back on
    // a direct app->home transition made Pixel Launcher re-grid mid-inflation
    // and wipe the bottom row of home-screen icons.
    //
    // We now only consider modes whose physical resolution EXACTLY matches the
    // active mode, and we abstain (0 = no vote) when the active mode already
    // has the best refresh rate — no vote means no APP_REQUEST_SIZE pin at all.
    // User-set peak refresh (Smooth Display off) outranks this vote in
    // DisplayModeDirector, so we never fight an explicit user choice.
    private fun getPreferredHighRefreshModeId(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return 0
        val display = display ?: return 0
        val currentMode = display.mode
        var best = currentMode
        for (mode in display.supportedModes) {
            if (mode.physicalWidth != currentMode.physicalWidth) continue
            if (mode.physicalHeight != currentMode.physicalHeight) continue
            if (mode.refreshRate > best.refreshRate) best = mode
        }
        return if (best.modeId == currentMode.modeId) 0 else best.modeId
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/navigation")
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialRoute") {
                    result.success(initialRoute)
                    initialRoute = null
                } else {
                    result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/navigation/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    navigationSink = events
                }
                override fun onCancel(arguments: Any?) {
                    navigationSink = null
                }
            })

        // adb remote (DebugReceiver): commands in, replies out to logcat.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/debug/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    ownDebugSink = events
                    attachDebugSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    ownDebugSink?.let { detachDebugSink(it) }
                    ownDebugSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/debug")
            .setMethodCallHandler { call, result ->
                if (call.method == "reply") {
                    logDebugReply(call.arguments as? String ?: "")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    } catch (e: Exception) {
                        result.error("ANDROID_ID_ERROR", "Failed to get Android ID: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(VpnPlugin)
        GlobalState.flutterEngine = flutterEngine

        // Sync VPN status when app opens - this ensures UI reflects actual VPN state
        // especially important when VPN was started via Tile while app was not in memory
        GlobalState.syncStatus()
    }

    override fun onDestroy() {
        // This activity's engine goes away with it; later adb commands queue
        // until the next engine subscribes. Identity-checked: a late onDestroy
        // of an old instance must not detach a newer instance's sink.
        ownDebugSink?.let { detachDebugSink(it) }
        ownDebugSink = null
        GlobalState.flutterEngine = null
        // Don't reset runState here - VPN might still be running via serviceEngine
        // The runState is managed by VpnPlugin.handleStart/handleStop
        super.onDestroy()
    }

    // Google Play rationale: always-on VPN is a core feature of this app, so a
    // battery-optimization exemption is genuinely needed to keep the tunnel
    // alive under Doze. To stay Play-policy compliant we make the request
    // CONTEXTUAL and ONE-TIME — it is shown only after the user has actually
    // started the VPN at least once (gated by `flutter.vpn_started_once`, set
    // from the VPN service start path) and only once ever (gated by
    // `flutter.battery_opt_prompted`). It is never an app-launch nag and is
    // never shown again even if the user declines.
    //
    // Mechanics ported from pluralplay/FlClashX maybeRequestBatteryExemption(),
    // with the added vpn_started_once gate and an onResume() (not cold-start)
    // call site.
    private fun maybeRequestBatteryExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val pm = getSystemService(PowerManager::class.java) ?: return
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Only prompt after the user has actually started the VPN at least once.
        if (!prefs.getBoolean("flutter.vpn_started_once", false)) return
        // Only prompt once ever — respected even if the user declines.
        if (prefs.getBoolean("flutter.battery_opt_prompted", false)) return
        prefs.edit().putBoolean("flutter.battery_opt_prompted", true).apply()
        runCatching {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                )
            )
        }
    }

    companion object {
        private const val EXTRA_ROUTE = "route"

        // ── adb remote holder (see DebugReceiver) ────────────────────────────
        // Process-wide so the receiver can reach the UI engine's Dart side.
        // Touched only on the main looper.
        private const val DEBUG_QUEUE_CAP = 20
        private const val DEBUG_CHUNK = 3500
        private val mainHandler = Handler(Looper.getMainLooper())
        private var debugSink: EventChannel.EventSink? = null
        private val debugPending = ArrayList<String>()

        private fun attachDebugSink(sink: EventChannel.EventSink) {
            mainHandler.post {
                debugSink = sink
                val queued = debugPending.toList()
                debugPending.clear()
                queued.forEach { sink.success(it) }
            }
        }

        private fun detachDebugSink(sink: EventChannel.EventSink) {
            mainHandler.post { if (debugSink === sink) debugSink = null }
        }

        /** Called by [DebugReceiver]; never starts an activity itself. */
        fun deliverDebugCommand(packageName: String, json: String) {
            mainHandler.post {
                val sink = debugSink
                if (sink != null) {
                    sink.success(json)
                    return@post
                }
                if (debugPending.size >= DEBUG_QUEUE_CAP) debugPending.removeAt(0)
                debugPending.add(json)
                Log.i(
                    DebugReceiver.TAG,
                    "queued: UI engine not running; start it: " +
                        "am start -n $packageName/app.dropweb.MainActivity"
                )
            }
        }

        /** Dart replies, chunked so logcat never truncates them. */
        fun logDebugReply(text: String) {
            if (text.length <= DEBUG_CHUNK) {
                Log.i(DebugReceiver.TAG, text)
                return
            }
            val chunks = text.chunked(DEBUG_CHUNK)
            chunks.forEachIndexed { i, chunk ->
                Log.i(DebugReceiver.TAG, "[${i + 1}/${chunks.size}] $chunk")
            }
        }
    }

    private fun applyAppTheme() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val configJson = prefs.getString("flutter.config", null)
            
            if (configJson != null) {
                val config = JSONObject(configJson)
                val themeProps = config.optJSONObject("themeProps")
                val themeMode = themeProps?.optString("themeMode", "ThemeMode.system") ?: "ThemeMode.system"
                
                when {
                    themeMode.contains("light", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
                    }
                    themeMode.contains("dark", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
                    }
                    else -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
                    }
                }
            } else {
                // Default to system theme if config not found
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            }
        } catch (e: Exception) {
            // Fallback to system theme on error
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
    }
}
