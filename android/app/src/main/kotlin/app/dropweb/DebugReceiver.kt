package app.dropweb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

/**
 * adb remote («пульт») entry point: `adb shell am broadcast -p <pkg>
 * -a <pkg>.DEBUG --es cmd help`.
 *
 * SECURITY: registered in the manifest with
 * `android:permission="android.permission.DUMP"`. DUMP is a signature|privileged
 * permission held only by the shell (adb) and the system — third-party apps
 * cannot obtain it, so only a developer with adb access can reach this receiver.
 * The app itself does NOT request DUMP. On top of that the Dart dispatcher
 * refuses everything in the Play build and while developer mode is off.
 *
 * Collects every String extra into a JSON object and hands it to the Flutter
 * UI engine via [MainActivity.deliverDebugCommand]; replies are logged by
 * [MainActivity.logDebugReply] under the [TAG] logcat tag.
 */
class DebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val json = JSONObject()
        val preview = JSONObject()
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                @Suppress("DEPRECATION")
                val value = extras.get(key) as? String ?: continue
                json.put(key, value)
                if (value.length <= MAX_PREVIEW_VALUE) preview.put(key, value)
            }
        }
        Log.i(TAG, "recv $preview")
        MainActivity.deliverDebugCommand(context.packageName, json.toString())
    }

    companion object {
        const val TAG = "dropweb-dbg"
        private const val MAX_PREVIEW_VALUE = 200
    }
}
