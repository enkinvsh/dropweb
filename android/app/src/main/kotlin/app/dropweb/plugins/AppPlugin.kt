package app.dropweb.plugins

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ComponentInfo
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.getSystemService
import androidx.core.content.FileProvider
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile
import app.dropweb.DropwebApplication
import app.dropweb.GlobalState
import app.dropweb.R
import app.dropweb.extensions.awaitResult
import app.dropweb.extensions.getActionIntent
import app.dropweb.extensions.getBase64
import app.dropweb.models.Package
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.lang.ref.WeakReference
import java.util.zip.ZipFile

class AppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private var activityRef: WeakReference<Activity>? = null

    private lateinit var channel: MethodChannel

    private lateinit var scope: CoroutineScope

    private var vpnCallBack: (() -> Unit)? = null

    private val iconMap = mutableMapOf<String, String?>()

    private val packages = mutableListOf<Package>()

    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    // Lazily-built shared SoundPool for the dashboard power button cues.
    // Released in onDetachedFromEngine. Keep maxStreams low — we never need
    // more than one short UI tick at a time and overlapping cues sound bad.
    private var soundPool: SoundPool? = null

    // Maps DropwebSoundCue.name → SoundPool sample id. Samples are
    // preloaded once on engine attach so the very first tap is not silent.
    private val soundIdMap = mutableMapOf<String, Int>()

    // Cue → asset mapping. Reduced set after the SFX simplification pass:
    // power cues reuse the subscription-refresh / import-error timbres
    // (toggle_on.wav is a byte copy of refresh_subscriptions.wav,
    // toggle_off.wav is a byte copy of import_error.wav), and importError
    // shares the toggle_off.wav asset because the standalone
    // import_error.wav file was removed. Every entry is preloaded into
    // SoundPool on engine attach. Cue names must match DropwebSoundCue.name
    // on the Dart side; the contract is locked by
    // test/plugins/app_sounds_test.dart.
    private val cueAssets: Map<String, String> = mapOf(
        "powerOn" to "assets/sounds/toggle_on.wav",
        "powerOff" to "assets/sounds/toggle_off.wav",
        "subscriptionRefresh" to "assets/sounds/refresh_subscriptions.wav",
        "importSuccess" to "assets/sounds/import_success.wav",
        "importError" to "assets/sounds/toggle_off.wav",
    )

    private val skipPrefixList = listOf(
        "com.google",
        "com.android.chrome",
        "com.android.vending",
        "com.microsoft",
        "com.apple",
        "com.zhiliaoapp.musically", // Banned by China
    )

    private val chinaAppPrefixList = listOf(
        "com.tencent",
        "com.alibaba",
        "com.umeng",
        "com.qihoo",
        "com.ali",
        "com.alipay",
        "com.amap",
        "com.sina",
        "com.weibo",
        "com.vivo",
        "com.xiaomi",
        "com.huawei",
        "com.taobao",
        "com.secneo",
        "s.h.e.l.l",
        "com.stub",
        "com.kiwisec",
        "com.secshell",
        "com.wrapper",
        "cn.securitystack",
        "com.mogosec",
        "com.secoen",
        "com.netease",
        "com.mx",
        "com.qq.e",
        "com.baidu",
        "com.bytedance",
        "com.bugly",
        "com.miui",
        "com.oppo",
        "com.coloros",
        "com.iqoo",
        "com.meizu",
        "com.gionee",
        "cn.nubia",
        "com.oplus",
        "andes.oplus",
        "com.unionpay",
        "cn.wps"
    )

    private val chinaAppRegex by lazy {
        ("(" + chinaAppPrefixList.joinToString("|").replace(".", "\\.") + ").*").toRegex()
    }

    val VPN_PERMISSION_REQUEST_CODE = 1001

    val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002

    private var isBlockNotification: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(Dispatchers.Default)
        pluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app")
        channel.setMethodCallHandler(this)
        preloadUiSounds(flutterPluginBinding)
    }

    private fun initShortcuts(label: String) {
        val shortcut = ShortcutInfoCompat.Builder(DropwebApplication.getAppContext(), "toggle")
            .setShortLabel(label)
            .setIcon(
                IconCompat.createWithResource(
                    DropwebApplication.getAppContext(),
                    R.mipmap.ic_launcher_round
                )
            )
            .setIntent(DropwebApplication.getAppContext().getActionIntent("CHANGE"))
            .build()
        ShortcutManagerCompat.setDynamicShortcuts(
            DropwebApplication.getAppContext(),
            listOf(shortcut)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        soundPool?.release()
        soundPool = null
        soundIdMap.clear()
        pluginBinding = null
    }

    private fun tip(message: String?) {
        if (GlobalState.flutterEngine == null) {
            Toast.makeText(DropwebApplication.getAppContext(), message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "moveTaskToBack" -> {
                activityRef?.get()?.moveTaskToBack(true)
                result.success(true)
            }

            "updateExcludeFromRecents" -> {
                val value = call.argument<Boolean>("value")
                updateExcludeFromRecents(value)
                result.success(true)
            }

            "initShortcuts" -> {
                initShortcuts(call.arguments as String)
                result.success(true)
            }

            "getPackages" -> {
                scope.launch {
                    result.success(getPackagesToJson())
                }
            }

            "getChinaPackageNames" -> {
                scope.launch {
                    result.success(getChinaPackageNames())
                }
            }

            "getPackageIcon" -> {
                scope.launch {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.success(null)
                        return@launch
                    }
                    val packageIcon = getPackageIcon(packageName)
                    packageIcon.let {
                        if (it != null) {
                            result.success(it)
                            return@launch
                        }
                        if (iconMap["default"] == null) {
                            iconMap["default"] =
                                DropwebApplication.getAppContext().packageManager?.defaultActivityIcon?.getBase64()
                        }
                        result.success(iconMap["default"])
                        return@launch
                    }
                }
            }

            "tip" -> {
                val message = call.argument<String>("message")
                tip(message)
                result.success(true)
            }

            "openFile" -> {
                val path = call.argument<String>("path")!!
                openFile(path)
                result.success(true)
            }

            "performHapticFeedback" -> {
                val cue = call.argument<String>("cue")
                result.success(performHapticFeedback(cue))
            }

            "playUiSound" -> {
                val cue = call.argument<String>("cue")
                result.success(playUiSound(cue))
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Map semantic dashboard cues to Pixel-friendly [HapticFeedbackConstants]
     * and fire them through the activity's decor view so the system haptic
     * engine renders them with the user's preferred intensity.
     *
     * Returns true when a vibration was actually performed, false otherwise.
     * Falls back via the call site (Dart) to generic Flutter haptics on false.
     */
    private fun performHapticFeedback(cue: String?): Boolean {
        val view = activityRef?.get()?.window?.decorView ?: return false
        val constant: Int = when (cue) {
            "gestureStart" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    HapticFeedbackConstants.GESTURE_START
                } else {
                    HapticFeedbackConstants.CONTEXT_CLICK
                }
            }
            "confirm" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    HapticFeedbackConstants.CONFIRM
                } else {
                    HapticFeedbackConstants.VIRTUAL_KEY
                }
            }
            "cancel" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    HapticFeedbackConstants.GESTURE_END
                } else {
                    HapticFeedbackConstants.CLOCK_TICK
                }
            }
            else -> return false
        }
        // No flags → respect the user's system haptic settings.
        return view.performHapticFeedback(constant)
    }

    /**
     * Eagerly load every UI cue declared in [cueAssets] into a shared
     * SoundPool so the first tap after launch is not silent. SoundPool.load
     * is async, so even with eager preload the very first invocation right
     * after attach may still hit play() before the sample is decoded — in
     * that case play() returns streamId 0 and we report false so the Dart
     * wrapper falls back to SystemSound.click.
     */
    private fun preloadUiSounds(binding: FlutterPlugin.FlutterPluginBinding) {
        val pool = ensureSoundPool()
        val context = DropwebApplication.getAppContext()
        for ((cue, asset) in cueAssets) {
            if (soundIdMap.containsKey(cue)) continue
            try {
                val path = binding.flutterAssets.getAssetFilePathByName(asset)
                val afd = context.assets.openFd(path)
                val id = pool.load(afd, 1)
                afd.close()
                soundIdMap[cue] = id
            } catch (_: Throwable) {
                // Asset missing or unreadable — leave unmapped so playUiSound
                // returns false and Dart falls back to SystemSound.click.
            }
        }
    }

    private fun ensureSoundPool(): SoundPool {
        soundPool?.let { return it }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(attrs)
            .build()
        soundPool = pool
        return pool
    }

    /**
     * Play a short UI cue through SoundPool. Returns true when the cue was
     * "consumed" by the native side and the Dart wrapper should NOT fall
     * back to SystemSound.click. Specifically:
     *  - Returns true when SoundPool.play succeeded (streamId != 0).
     *  - Returns true when the user disabled system touch sounds
     *    (Settings.System.SOUND_EFFECTS_ENABLED == 0). The user asked for
     *    silence; falling back to SystemSound.click would defeat that.
     *  - Returns false on any other failure (sample not yet loaded, unknown
     *    cue, asset missing) so the Dart wrapper plays SystemSound.click.
     */
    private fun playUiSound(cue: String?): Boolean {
        val context = DropwebApplication.getAppContext()
        val asset = cueAssets[cue] ?: return false

        val effectsEnabled = try {
            Settings.System.getInt(
                context.contentResolver,
                Settings.System.SOUND_EFFECTS_ENABLED,
                1,
            ) == 1
        } catch (_: Throwable) {
            true
        }
        if (!effectsEnabled) return true

        val pool = soundPool ?: ensureSoundPool().also {
            pluginBinding?.let(::preloadUiSounds)
        }
        val sampleId = soundIdMap[cue] ?: return false
        val streamId = pool.play(sampleId, 0.8f, 0.8f, 1, 0, 1f)
        return streamId != 0
    }

    private fun openFile(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            DropwebApplication.getAppContext(),
            "${DropwebApplication.getAppContext().packageName}.fileProvider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(
            uri,
            "text/plain"
        )

        val flags =
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION

        // Attach grant flags to the intent itself so the viewer that ends up
        // resolving the ACTION_VIEW (including via system chooser) still gets
        // read/write access to the FileProvider URI even when the explicit
        // queryIntentActivities loop below returns no candidates (e.g. when
        // package-visibility queries do not match any installed viewer).
        intent.addFlags(flags)

        val resInfoList = DropwebApplication.getAppContext().packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )

        for (resolveInfo in resInfoList) {
            val packageName = resolveInfo.activityInfo.packageName
            DropwebApplication.getAppContext().grantUriPermission(
                packageName,
                uri,
                flags
            )
        }

        try {
            activityRef?.get()?.startActivity(intent)
        } catch (e: Exception) {
            println(e)
        }
    }

    private fun updateExcludeFromRecents(value: Boolean?) {
        val am = getSystemService(DropwebApplication.getAppContext(), ActivityManager::class.java)
        val task = am?.appTasks?.firstOrNull {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                it.taskInfo.taskId == activityRef?.get()?.taskId
            } else {
                it.taskInfo.id == activityRef?.get()?.taskId
            }
        }

        when (value) {
            true -> task?.setExcludeFromRecents(value)
            false -> task?.setExcludeFromRecents(value)
            null -> task?.setExcludeFromRecents(false)
        }
    }

    private suspend fun getPackageIcon(packageName: String): String? {
        val packageManager = DropwebApplication.getAppContext().packageManager
        if (iconMap[packageName] == null) {
            iconMap[packageName] = try {
                packageManager?.getApplicationIcon(packageName)?.getBase64()
            } catch (_: Exception) {
                null
            }

        }
        return iconMap[packageName]
    }

    private fun getPackages(): List<Package> {
        val packageManager = DropwebApplication.getAppContext().packageManager
        if (packages.isNotEmpty()) return packages
        packageManager?.getInstalledPackages(PackageManager.GET_META_DATA or PackageManager.GET_PERMISSIONS)
            ?.filter {
                it.packageName != DropwebApplication.getAppContext().packageName || it.packageName == "android"

            }?.map {
                Package(
                    packageName = it.packageName,
                    label = it.applicationInfo?.loadLabel(packageManager).toString(),
                    system = (it.applicationInfo?.flags?.and(ApplicationInfo.FLAG_SYSTEM)) == 1,
                    lastUpdateTime = it.lastUpdateTime,
                    internet = it.requestedPermissions?.contains(Manifest.permission.INTERNET) == true
                )
            }?.let { packages.addAll(it) }
        return packages
    }

    private suspend fun getPackagesToJson(): String {
        return withContext(Dispatchers.Default) {
            Gson().toJson(getPackages())
        }
    }

    private suspend fun getChinaPackageNames(): String {
        return withContext(Dispatchers.Default) {
            val packages: List<String> =
                getPackages().map { it.packageName }.filter { isChinaPackage(it) }
            Gson().toJson(packages)
        }
    }

    fun requestVpnPermission(callBack: () -> Unit) {
        vpnCallBack = callBack
        val intent = VpnService.prepare(DropwebApplication.getAppContext())
        if (intent != null) {
            activityRef?.get()?.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
            return
        }
        vpnCallBack?.invoke()
    }

    fun requestNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = ContextCompat.checkSelfPermission(
                DropwebApplication.getAppContext(),
                Manifest.permission.POST_NOTIFICATIONS
            )
            if (permission != PackageManager.PERMISSION_GRANTED) {
                if (isBlockNotification) return
                if (activityRef?.get() == null) return
                activityRef?.get()?.let {
                    ActivityCompat.requestPermissions(
                        it,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        NOTIFICATION_PERMISSION_REQUEST_CODE
                    )
                    return
                }
            }
        }
    }

    suspend fun getText(text: String): String? {
        return withContext(Dispatchers.Default) {
            channel.awaitResult<String>("getText", text)
        }
    }

    private fun isChinaPackage(packageName: String): Boolean {
        val packageManager = DropwebApplication.getAppContext().packageManager ?: return false
        skipPrefixList.forEach {
            if (packageName == it || packageName.startsWith("$it.")) return false
        }
        val packageManagerFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            PackageManager.MATCH_UNINSTALLED_PACKAGES or PackageManager.GET_ACTIVITIES or PackageManager.GET_SERVICES or PackageManager.GET_RECEIVERS or PackageManager.GET_PROVIDERS
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_UNINSTALLED_PACKAGES or PackageManager.GET_ACTIVITIES or PackageManager.GET_SERVICES or PackageManager.GET_RECEIVERS or PackageManager.GET_PROVIDERS
        }
        if (packageName.matches(chinaAppRegex)) {
            return true
        }
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(packageManagerFlags.toLong())
                )
            } else {
                packageManager.getPackageInfo(
                    packageName, packageManagerFlags
                )
            }
            mutableListOf<ComponentInfo>().apply {
                packageInfo.services?.let { addAll(it) }
                packageInfo.activities?.let { addAll(it) }
                packageInfo.receivers?.let { addAll(it) }
                packageInfo.providers?.let { addAll(it) }
            }.forEach {
                if (it.name.matches(chinaAppRegex)) return true
            }
            packageInfo.applicationInfo?.publicSourceDir?.let {
                ZipFile(File(it)).use {
                    for (packageEntry in it.entries()) {
                        if (packageEntry.name.startsWith("firebase-")) return false
                    }
                    for (packageEntry in it.entries()) {
                        if (!(packageEntry.name.startsWith("classes") && packageEntry.name.endsWith(
                                ".dex"
                            ))
                        ) {
                            continue
                        }
                        if (packageEntry.size > 15000000) {
                            return true
                        }
                        val input = it.getInputStream(packageEntry).buffered()
                        val dexFile = try {
                            DexBackedDexFile.fromInputStream(null, input)
                        } catch (e: Exception) {
                            return false
                        }
                        for (clazz in dexFile.classes) {
                            val clazzName =
                                clazz.type.substring(1, clazz.type.length - 1).replace("/", ".")
                                    .replace("$", ".")
                            if (clazzName.matches(chinaAppRegex)) return true
                        }
                    }
                }
            }
        } catch (_: Exception) {
            return false
        }
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
        binding.addActivityResultListener(::onActivityResult)
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityRef = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivity() {
        channel.invokeMethod("exit", null)
        activityRef = null
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == FlutterActivity.RESULT_OK) {
                GlobalState.initServiceEngine()
                vpnCallBack?.invoke()
            }
        }
        return true
    }

    private fun onRequestPermissionsResultListener(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            isBlockNotification = true
        }
        return true
    }
}
