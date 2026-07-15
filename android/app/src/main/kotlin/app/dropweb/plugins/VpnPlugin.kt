package app.dropweb.plugins

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import app.dropweb.DropwebApplication
import app.dropweb.GlobalState
import app.dropweb.RunState
import org.dropweb.vpn.core.Core
import app.dropweb.extensions.asSocketAddressText
import app.dropweb.extensions.awaitResult
import app.dropweb.models.StartForegroundParams
import app.dropweb.models.VpnOptions
import app.dropweb.services.BaseServiceInterface
import app.dropweb.services.DropwebService
import app.dropweb.services.DropwebVpnService
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private const val TAG = "VpnPlugin"

    private lateinit var flutterMethodChannel: MethodChannel
    private var dropwebService: BaseServiceInterface? = null
    private var options: VpnOptions? = null
    private var isBind: Boolean = false
    private lateinit var scope: CoroutineScope
    private var lastStartForegroundParams: StartForegroundParams? = null
    private var timerJob: Job? = null
    // resolverProcess() is invoked as a JNI callback from the Go core, which
    // resolves per-connection process names from multiple concurrent goroutines.
    // A plain HashMap corrupts / throws ConcurrentModificationException under
    // that fan-in; ConcurrentHashMap gives lock-free reads and atomic writes.
    private val uidPageNameMap = java.util.concurrent.ConcurrentHashMap<Int, String>()
    private var screenReceiverRegistered: Boolean = false
    private var startRequested: Boolean = false
    private var attachCount = 0

    // ---------------------------------------------------------------------
    // Active-bearer tracking (single authoritative physical network).
    //
    // One serialized actor (dedicated HandlerThread) owns all bearer state.
    // A pure BearerTracker reducer owns identity + first-snapshot semantics.
    // The old all-network-set tracking keyed identity on the sorted SET of
    // INTERNET+NOT_VPN networks, which double-reset the core on LTE→WiFi
    // (cellular 30s linger teardown) and missed gradual WiFi death entirely.
    // ---------------------------------------------------------------------

    /** Networks seen via callbacks but not yet committed as the bearer. */
    private data class Candidate(
        val network: Network,
        var capabilities: NetworkCapabilities? = null,
        var linkProperties: LinkProperties? = null,
        var readinessAttempt: Int = 0,
        var token: Long = 0L,
    )

    private lateinit var bearerThread: HandlerThread
    private lateinit var bearerHandler: Handler

    private val bearerTracker = BearerTracker()
    private val candidates = mutableMapOf<Network, Candidate>()

    private var activeNetwork: Network? = null
    private var activeCapabilities: NetworkCapabilities? = null
    private var activeLinkProperties: LinkProperties? = null

    private var lastPublishedDns: List<String>? = null

    // Written from start/stop control paths, read from the actor thread.
    @Volatile
    private var callbackRegistered = false

    @Volatile
    private var bearerSession = 0L

    private var candidateToken = 0L
    private var pendingLoss: Runnable? = null

    private val connectivity by lazy {
        DropwebApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            isBind = true
            dropwebService = when (service) {
                is DropwebVpnService.LocalBinder -> service.getService()
                is DropwebService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            dropwebService = null
            stopForegroundJob()
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // This singleton is attached to BOTH the main engine and the service engine.
        // Create the scope and the bearer actor thread only once (first attach) so
        // we never overwrite the live scope (leak) nor spawn a second actor.
        // NO ConnectivityManager callback is registered here: tracking starts only
        // after Core.startTun succeeds (startBearerTracking in handleStartService).
        attachCount++
        if (attachCount == 1) {
            scope = CoroutineScope(Dispatchers.Default)
            bearerThread = HandlerThread("dropweb-bearer").also { it.start() }
            bearerHandler = Handler(bearerThread.looper)
        }
        // Channel assignment stays last-wins by design: the service engine attaches
        // later and is the correct receiver for VPN logic (service isolate runs it).
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        attachCount--
        // Only tear down once the last engine detaches; otherwise the surviving
        // engine keeps its handler and the bearer tracking stays live.
        if (attachCount <= 0) {
            attachCount = 0
            stopBearerTracking()
            if (::bearerHandler.isInitialized) {
                // Drop queued actor work (including the state-clear posted by
                // stopBearerTracking — startBearerTracking re-clears on next start)
                // and quit the thread safely.
                bearerHandler.removeCallbacksAndMessages(null)
                bearerThread.quitSafely()
            }
            flutterMethodChannel.setMethodCallHandler(null)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val data = call.argument<String>("data")
                result.success(handleStart(Gson().fromJson(data, VpnOptions::class.java)))
            }

            "stop" -> {
                handleStop()
                result.success(true)
            }

            "showSubscriptionNotification" -> {
                val title = call.argument<String>("title") ?: ""
                val message = call.argument<String>("message") ?: ""
                val actionLabel = call.argument<String>("actionLabel") ?: ""
                val actionUrl = call.argument<String>("actionUrl") ?: ""
                showSubscriptionNotification(title, message, actionLabel, actionUrl)
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    fun handleStart(options: VpnOptions): Boolean {
        startRequested = true
        if (options.enable != this.options?.enable) {
            this.dropwebService = null
        }
        this.options = options
        when (options.enable) {
            true -> handleStartVpn()
            false -> handleStartService()
        }
        return true
    }

    private fun handleStartVpn() {
        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
            handleStartService()
        }
    }

    fun requestGc() {
        flutterMethodChannel.invokeMethod("gc", null)
    }

    // -----------------------------------------------------------------
    // Bearer actor plumbing
    // -----------------------------------------------------------------

    private fun onBearerActor(block: () -> Unit) {
        if (Looper.myLooper() == bearerHandler.looper) {
            block()
        } else {
            bearerHandler.post(block)
        }
    }

    private fun isLiveBearerSession(): Boolean =
        callbackRegistered && GlobalState.runState.value == RunState.START

    // INTERNET + NOT_RESTRICTED + NOT_VPN, and deliberately NEVER VALIDATED:
    // RU/KZ networks with blocked Android validation endpoints, captive
    // portals, or partial internet access must remain eligible bearers.
    // VALIDATED / CAPTIVE_PORTAL are diagnostic fields only.
    private val bearerRequest = NetworkRequest.Builder()
        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        .build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            onBearerActor {
                if (!isLiveBearerSession()) return@onBearerActor
                candidateToken++
                candidates[network] = Candidate(
                    network = network,
                    token = candidateToken,
                )
                Log.d(TAG, "[bearer] available session=$bearerSession id=${network.networkHandle}")
                // Never commit from onAvailable alone: a candidate is ready only
                // when BOTH capabilities and LinkProperties have been observed.
                // On API 31 there is no onLost(old) when a better network
                // supersedes — onAvailable(new) + readiness IS the switch signal.
                scheduleLinkPropertiesReadiness(
                    network = network,
                    session = bearerSession,
                    token = candidateToken,
                )
            }
        }

        override fun onCapabilitiesChanged(
            network: Network,
            capabilities: NetworkCapabilities,
        ) {
            onBearerActor {
                if (!isLiveBearerSession()) return@onBearerActor

                val eligible = isEligiblePhysicalNetwork(capabilities)
                Log.d(
                    TAG,
                    "[bearer] capabilities id=${network.networkHandle} eligible=$eligible " +
                        "validated=${capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)} " +
                        "metered=${!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)}"
                )

                if (network == activeNetwork) {
                    if (!eligible) {
                        scheduleActiveLoss(network, reason = "capability-loss")
                        return@onBearerActor
                    }
                    cancelPendingLoss()
                    activeCapabilities = capabilities
                    applyUnderlyingNetwork()
                    // VALIDATED/CAPTIVE/metered changes do not change identity and
                    // do not emit networkChanged.
                    return@onBearerActor
                }

                val candidate = candidates.getOrPut(network) {
                    Candidate(network = network, token = ++candidateToken)
                }
                candidate.capabilities = capabilities

                if (!eligible) {
                    // On API 24–27 the default callback cannot take a
                    // NetworkRequest, so this capability check is mandatory;
                    // it also rejects the app's own VPN network.
                    candidates.remove(network)
                    return@onBearerActor
                }

                tryCommitCandidate(candidate, reason = "capabilities-ready")
            }
        }

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties,
        ) {
            onBearerActor {
                if (!isLiveBearerSession()) return@onBearerActor
                handleLinkProperties(network, linkProperties)
            }
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            onBearerActor {
                // Advisory only: never null the bearer, alter underlying
                // networks, emit DNS, or notify the core from onLosing.
                Log.d(
                    TAG,
                    "[bearer] losing id=${network.networkHandle} " +
                        "current=${network == activeNetwork} maxMs=$maxMsToLive"
                )
            }
        }

        override fun onLost(network: Network) {
            onBearerActor {
                if (!isLiveBearerSession()) return@onBearerActor

                candidates.remove(network)

                if (network != activeNetwork) {
                    // The 30–35s cellular linger teardown after LTE→WiFi lands
                    // here: the WiFi bearer is already committed, so the stale
                    // loss must produce ZERO additional core resets.
                    Log.d(
                        TAG,
                        "[bearer] ignore stale lost id=${network.networkHandle} " +
                            "active=${activeNetwork?.networkHandle}"
                    )
                    return@onBearerActor
                }

                scheduleActiveLoss(network, reason = "lost")
            }
        }
    }

    /** Uses the callback-supplied LinkProperties; runs on the actor thread. */
    private fun handleLinkProperties(network: Network, linkProperties: LinkProperties) {
        if (network == activeNetwork) {
            // Active bearer's DNS/routes/MTU change does not change identity and
            // must not close connections; DNS still propagates via dnsChanged.
            activeLinkProperties = linkProperties
            publishActiveDnsIfChanged()
            return
        }

        val candidate = candidates.getOrPut(network) {
            Candidate(network = network, token = ++candidateToken)
        }
        candidate.linkProperties = linkProperties
        Log.d(
            TAG,
            "[bearer] link-properties id=${network.networkHandle} " +
                "iface=${linkProperties.interfaceName} dns=${linkProperties.dnsServers.size}"
        )
        tryCommitCandidate(candidate, reason = "link-properties-ready")
    }

    // Sing-box-style LinkProperties fallback for devices whose callbacks skip
    // onLinkPropertiesChanged: up to 10 delayed actor tasks, 100 ms apart.
    // getLinkProperties is called ONLY from the delayed task, never
    // synchronously inside a ConnectivityManager callback.
    private fun scheduleLinkPropertiesReadiness(network: Network, session: Long, token: Long) {
        bearerHandler.postDelayed({
            if (session != bearerSession) return@postDelayed
            if (GlobalState.runState.value != RunState.START) return@postDelayed
            val candidate = candidates[network] ?: return@postDelayed
            if (candidate.token != token) return@postDelayed
            if (candidate.linkProperties != null) return@postDelayed

            candidate.readinessAttempt++
            val linkProperties = runCatching {
                connectivity?.getLinkProperties(network)
            }.getOrNull()
            if (linkProperties != null) {
                handleLinkProperties(network, linkProperties)
                return@postDelayed
            }
            if (candidate.readinessAttempt >= 10) {
                // Keep the candidate uncommitted; a later real LinkProperties
                // callback may still commit it.
                Log.d(
                    TAG,
                    "[bearer] readiness timeout id=${network.networkHandle} " +
                        "attempts=${candidate.readinessAttempt}"
                )
                return@postDelayed
            }
            scheduleLinkPropertiesReadiness(network, session, token)
        }, 100L)
    }

    private fun isEligiblePhysicalNetwork(capabilities: NetworkCapabilities): Boolean =
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)

    private fun tryCommitCandidate(candidate: Candidate, reason: String) {
        val capabilities = candidate.capabilities ?: return
        val linkProperties = candidate.linkProperties ?: return
        if (!isEligiblePhysicalNetwork(capabilities)) return

        commitBearer(
            network = candidate.network,
            capabilities = capabilities,
            linkProperties = linkProperties,
            reason = reason,
        )
    }

    private fun commitBearer(
        network: Network,
        capabilities: NetworkCapabilities,
        linkProperties: LinkProperties,
        reason: String,
    ) {
        val transition = bearerTracker.commit(network.networkHandle)

        if (!transition.identityChanged) {
            // Same bearer re-confirmed: refresh caches and publish a DNS delta
            // only; never notify the core.
            activeCapabilities = capabilities
            activeLinkProperties = linkProperties
            publishActiveDnsIfChanged()
            return
        }

        cancelPendingLoss()
        activeNetwork = network
        activeCapabilities = capabilities
        activeLinkProperties = linkProperties
        // Invalidate every remaining candidate and in-flight readiness task: a
        // superseded network must re-earn full readiness before recommitting.
        candidates.clear()
        candidateToken++

        applyUnderlyingNetwork()

        val dnsPayload = publishDnsIfChanged(dnsFrom(linkProperties))
        if (dnsPayload != null) {
            Log.i(
                TAG,
                "[bearer] dns id=${network.networkHandle} " +
                    "count=${linkProperties.dnsServers.size} changed=true"
            )
        }
        Log.i(
            TAG,
            "[bearer] commit session=$bearerSession old=${transition.previousId} " +
                "new=${transition.currentId} notifyCore=${transition.notifyCore} reason=$reason"
        )

        val details = mapOf(
            "session" to bearerSession,
            "from" to transition.previousId?.toString(),
            "to" to transition.currentId?.toString(),
            "reason" to reason,
        )
        // One ordered Main-thread effect block: DNS first (so the core resolver
        // state is current), then the single core reset for a real replacement.
        scope.launch {
            withContext(Dispatchers.Main) {
                dnsPayload?.let {
                    flutterMethodChannel.invokeMethod("dnsChanged", it)
                }
                if (transition.notifyCore) {
                    flutterMethodChannel.invokeMethod("networkChanged", details)
                }
            }
        }
    }

    private fun commitNoBearer(reason: String) {
        val transition = bearerTracker.commit(null)
        activeNetwork = null
        activeCapabilities = null
        activeLinkProperties = null
        applyUnderlyingNetwork()
        Log.i(
            TAG,
            "[bearer] commit session=$bearerSession old=${transition.previousId} " +
                "new=null notifyCore=false reason=$reason"
        )
        // Empty is a meaningful command: clear system DNS state. networkChanged
        // is never emitted on loss — old connections are reset when the NEXT
        // ready bearer commits, so an offline gap costs zero extra resets.
        val dnsPayload = publishDnsIfChanged(emptyList())
        if (dnsPayload != null) {
            scope.launch {
                withContext(Dispatchers.Main) {
                    flutterMethodChannel.invokeMethod("dnsChanged", dnsPayload)
                }
            }
        }
    }

    // 300 ms grace applies ONLY to loss of the currently committed bearer. A
    // ready replacement cancels it by committing (merely seeing onAvailable(new)
    // does not cancel — an unready candidate must not preserve a stale bearer).
    private fun scheduleActiveLoss(network: Network, reason: String) {
        pendingLoss?.let(bearerHandler::removeCallbacks)

        val session = bearerSession
        val expectedId = network.networkHandle

        val task = Runnable {
            if (session != bearerSession) return@Runnable
            if (GlobalState.runState.value != RunState.START) return@Runnable
            if (activeNetwork?.networkHandle != expectedId) return@Runnable

            commitNoBearer(reason = "$reason-timeout")
        }

        pendingLoss = task
        bearerHandler.postDelayed(task, 300L)
    }

    private fun cancelPendingLoss() {
        pendingLoss?.let(bearerHandler::removeCallbacks)
        pendingLoss = null
    }

    // -----------------------------------------------------------------
    // Effects: underlying network + DNS publication
    // -----------------------------------------------------------------

    private fun applyUnderlyingNetwork() {
        val vpnService = dropwebService as? DropwebVpnService ?: return
        val network = activeNetwork
        val capabilities = activeCapabilities

        val metered = capabilities?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_NOT_METERED
        ) == false

        // Only null or a one-element array is ever passed:
        //   * arrayOf(active) — the committed bearer;
        //   * null            — no bearer (follow Android's default network) or
        //                       the Android 9 (API 28) metered workaround;
        //   * NEVER emptyArray() — that means "VPN intentionally offline" and
        //     imposes traffic-blocked semantics;
        //   * never the candidate set or lingering networks.
        val underlying: Array<Network>? = when {
            network == null -> null
            Build.VERSION.SDK_INT == 28 && metered -> null
            else -> arrayOf(network)
        }

        val result = vpnService.setUnderlyingNetworks(underlying)

        Log.i(
            TAG,
            "[bearer] underlying id=${network?.networkHandle} " +
                "policy=${
                    when {
                        network == null -> "null-offline"
                        Build.VERSION.SDK_INT == 28 && metered -> "null-api28-metered"
                        else -> "single"
                    }
                } result=$result"
        )
    }

    // DNS comes exclusively from the committed active network's LinkProperties.
    // Android's DNS order is preserved; distinct() keeps first occurrence. The
    // old union over all observed networks leaked cellular DNS into WiFi
    // sessions (and vice versa) — never restore it.
    private fun dnsFrom(linkProperties: LinkProperties?): List<String> {
        if (linkProperties == null) return emptyList()

        return linkProperties.dnsServers
            .map { it.asSocketAddressText(53) }
            .distinct()
    }

    // emptyList().joinToString(",") intentionally produces "": an empty payload
    // is a meaningful clear-system-DNS command carried through Dart to Go.
    private fun publishDnsIfChanged(next: List<String>): String? {
        if (lastPublishedDns == next) return null
        lastPublishedDns = next
        return next.joinToString(",")
    }

    private fun publishActiveDnsIfChanged() {
        val payload = publishDnsIfChanged(dnsFrom(activeLinkProperties)) ?: return
        Log.i(
            TAG,
            "[bearer] dns id=${activeNetwork?.networkHandle} " +
                "count=${activeLinkProperties?.dnsServers?.size ?: 0} changed=true"
        )
        scope.launch {
            withContext(Dispatchers.Main) {
                flutterMethodChannel.invokeMethod("dnsChanged", payload)
            }
        }
    }

    // -----------------------------------------------------------------
    // Bearer tracking lifecycle — registered ONLY while the core session
    // is live (after Core.startTun success), never at engine attach.
    // -----------------------------------------------------------------

    private fun startBearerTracking() {
        // Fresh actor state before any callback of the new session can land:
        // the clear-block is queued ahead of registration, and callbacks are
        // delivered onto the same handler, so FIFO order guarantees it runs
        // first. bearerTracker.reset() restores first-snapshot suppression so
        // the session's first bearer is a baseline, not a core reset.
        onBearerActor {
            candidates.clear()
            activeNetwork = null
            activeCapabilities = null
            activeLinkProperties = null
            lastPublishedDns = null
            bearerTracker.reset()
        }

        bearerSession++
        val session = bearerSession

        try {
            val mode = when {
                Build.VERSION.SDK_INT >= 31 -> {
                    // Passive: tracks the one best non-VPN network and does not
                    // hold cellular alive.
                    connectivity?.registerBestMatchingNetworkCallback(
                        bearerRequest,
                        callback,
                        bearerHandler,
                    )
                    "best_matching"
                }

                Build.VERSION.SDK_INT >= 28 -> {
                    // The only reliable pre-31 way to migrate a filtered non-VPN
                    // request to the better satisfier. Radio-lifetime cost is
                    // bounded by lifecycle scoping: the request exists only
                    // while RunState.START. Requires CHANGE_NETWORK_STATE.
                    connectivity?.requestNetwork(
                        bearerRequest,
                        callback,
                        bearerHandler,
                    )
                    "request"
                }

                Build.VERSION.SDK_INT >= 26 -> {
                    connectivity?.registerDefaultNetworkCallback(
                        callback,
                        bearerHandler,
                    )
                    "default_handler"
                }

                else -> {
                    // API 24–25: callbacks arrive on ConnectivityManager's
                    // thread and are forwarded to the actor by every override.
                    connectivity?.registerDefaultNetworkCallback(callback)
                    "default"
                }
            }
            callbackRegistered = true
            Log.i(TAG, "[bearer] start session=$session api=${Build.VERSION.SDK_INT} mode=$mode")
        } catch (e: Exception) {
            // No fallback to the old all-network listener. Fail open:
            // setUnderlyingNetworks(null) below lets protected sockets follow
            // Android's default network.
            Log.e(
                TAG,
                "[bearer] registration failed session=$session api=${Build.VERSION.SDK_INT} error=$e"
            )
        }

        // Apply routing once even before the first callback arrives: with no
        // committed bearer this applies null (follow the default network).
        onBearerActor { applyUnderlyingNetwork() }
    }

    private fun stopBearerTracking() {
        bearerSession++

        if (::bearerHandler.isInitialized) {
            pendingLoss?.let(bearerHandler::removeCallbacks)
        }
        pendingLoss = null

        val wasRegistered = callbackRegistered
        if (callbackRegistered) {
            runCatching { connectivity?.unregisterNetworkCallback(callback) }
            callbackRegistered = false
        }

        if (::bearerHandler.isInitialized) {
            onBearerActor {
                candidates.clear()
                activeNetwork = null
                activeCapabilities = null
                activeLinkProperties = null
                lastPublishedDns = null
                bearerTracker.reset()
            }
        }

        // Never pass an empty array. No dnsChanged/networkChanged is emitted
        // during normal VPN shutdown.
        (dropwebService as? DropwebVpnService)?.setUnderlyingNetworks(null)
        Log.i(TAG, "[bearer] stop session=$bearerSession registered=$wasRegistered")
    }

    // -----------------------------------------------------------------
    // Screen receiver — cached routing reassertion ONLY. No
    // ConnectivityManager queries, no identity change, no readiness, no
    // dnsChanged, no networkChanged, no connection close.
    // -----------------------------------------------------------------

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_SCREEN_ON) return

            onBearerActor {
                if (!isLiveBearerSession()) return@onBearerActor
                Log.d(TAG, "[bearer] screen-on reassert active=${activeNetwork?.networkHandle}")
                applyUnderlyingNetwork()
            }
        }
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            DropwebApplication.getAppContext().registerReceiver(
                screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            DropwebApplication.getAppContext().registerReceiver(screenReceiver, filter)
        }
        screenReceiverRegistered = true
    }

    private fun unregisterScreenReceiver() {
        if (!screenReceiverRegistered) return
        try {
            DropwebApplication.getAppContext().unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        screenReceiverRegistered = false
    }

    private suspend fun startForeground() {
        GlobalState.runLock.lock()
        try {
            if (GlobalState.runState.value != RunState.START) return
            val data = flutterMethodChannel.awaitResult<String>("getStartForegroundParams")
            val startForegroundParams = if (data != null) Gson().fromJson(
                data, StartForegroundParams::class.java
            ) else StartForegroundParams(
                title = "", server = "", content = ""
            )
            if (lastStartForegroundParams != startForegroundParams) {
                lastStartForegroundParams = startForegroundParams
                dropwebService?.startForeground(
                    startForegroundParams.title,
                    startForegroundParams.server,
                    startForegroundParams.content,
                )
            }
        } finally {
            GlobalState.runLock.unlock()
        }
    }

    private fun startForegroundJob() {
        stopForegroundJob()
        timerJob = CoroutineScope(Dispatchers.Main).launch {
            while (isActive) {
                startForeground()
                delay(1000)
            }
        }
    }

    private fun stopForegroundJob() {
        timerJob?.cancel()
        timerJob = null
    }


    suspend fun getStatus(): Boolean? {
        return withContext(Dispatchers.Default) {
            flutterMethodChannel.awaitResult<Boolean>("status", null)
        }
    }

    private fun handleStartService() {
        if (dropwebService == null) {
            bindService()
            return
        }
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.START) return
            // A stop() arrived while bindService() was in flight; onServiceConnected
            // re-entered here after the bind completed. Honor that stop intent.
            if (!startRequested) return
            GlobalState.runState.value = RunState.START
            // start() returns a detached fd (service uses establish()?.detachFd()).
            // If startTun throws we own that fd and must close it, else it leaks and
            // runState would stay START with no live tun.
            val fd = dropwebService?.start(options!!)
            try {
                Core.startTun(
                    fd = fd ?: 0,
                    protect = this::protect,
                    resolverProcess = this::resolverProcess,
                )
            } catch (e: Exception) {
                Log.e(TAG, "Core.startTun failed", e)
                // Partial-start protection: tracking must never survive a failed
                // start (it was not started yet on this path, but the increment
                // invalidates any stray delayed task from a previous session).
                stopBearerTracking()
                if (fd != null && fd > 0) {
                    runCatching { ParcelFileDescriptor.adoptFd(fd).close() }
                }
                GlobalState.runState.value = RunState.STOP
                return
            }
            // Tracking starts ONLY after Core.startTun success — a live core
            // session is what makes bearer commits meaningful.
            startBearerTracking()
            registerScreenReceiver()
            startForegroundJob()
            // Cross-file flag read by MainActivity.maybeRequestBatteryExemption()
            // to gate the one-time, contextual battery-opt prompt after real VPN use.
            DropwebApplication.getAppContext()
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.vpn_started_once", true)
                .apply()
        }
    }

    private fun protect(fd: Int): Boolean {
        return (dropwebService as? DropwebVpnService)?.protect(fd) == true
    }

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String {
        val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
        } else {
            uid
        }
        if (nextUid == -1) {
            return ""
        }
        // Atomic compute-and-cache: the previous containsKey+put pair was a
        // check-then-act race across concurrent resolver callbacks. minSdk 24
        // guarantees ConcurrentHashMap.computeIfAbsent. The mapping lambda MUST
        // NOT return null — ConcurrentHashMap forbids null values — so the
        // `?: ""` fallback stays inside the lambda.
        return uidPageNameMap.computeIfAbsent(nextUid) {
            DropwebApplication.getAppContext().packageManager?.getPackagesForUid(nextUid)
                ?.firstOrNull() ?: ""
        }
    }

    fun handleStop() {
        Log.d(
            TAG,
            "handleStop: runState=${GlobalState.runState.value} caller=${Throwable().stackTrace.getOrNull(1)}"
        )
        startRequested = false
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.STOP) {
                // Partial-start / late-callback protection: bearer tracking must
                // never outlive a stop, even when the run state is already STOP.
                stopBearerTracking()
                return
            }
            GlobalState.runState.value = RunState.STOP
            // Before stopping the service or core, so no late callback can act
            // on a dying session (fresh identity baseline for the next session
            // comes from bearerTracker.reset() inside).
            stopBearerTracking()
            dropwebService?.stop()
            unregisterScreenReceiver()
            stopForegroundJob()
            Core.stopTun()
            // UID→package mappings go stale across sessions.
            uidPageNameMap.clear()
            // With BIND_AUTO_CREATE the binding keeps the stopped service instance
            // alive forever unless we unbind. After this isBind=false so bindService()
            // won't double-unbind; dropwebService=null forces a clean rebind on next start.
            if (isBind) {
                runCatching { DropwebApplication.getAppContext().unbindService(connection) }
                isBind = false
            }
            dropwebService = null
            GlobalState.handleTryDestroy()
        }
    }

    private fun bindService() {
        if (isBind) {
            DropwebApplication.getAppContext().unbindService(connection)
        }
        val intent = when (options?.enable == true) {
            true -> Intent(DropwebApplication.getAppContext(), DropwebVpnService::class.java)
            false -> Intent(DropwebApplication.getAppContext(), DropwebService::class.java)
        }
        DropwebApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun showSubscriptionNotification(title: String, message: String, actionLabel: String, actionUrl: String) {
        val context = DropwebApplication.getAppContext()
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for subscription alerts (Android O+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                GlobalState.SUBSCRIPTION_NOTIFICATION_CHANNEL,
                "Subscription Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications about subscription expiration"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent for action button (open URL)
        val actionIntent = Intent(Intent.ACTION_VIEW, Uri.parse(actionUrl))
        val actionPendingIntent = PendingIntent.getActivity(
            context,
            0,
            actionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create intent to open app when notification is tapped
        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, GlobalState.SUBSCRIPTION_NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openAppPendingIntent)
        
        // Only add action button if actionLabel is not empty
        if (actionLabel.isNotEmpty() && actionUrl.isNotEmpty()) {
            builder.addAction(0, actionLabel, actionPendingIntent)
        }

        notificationManager.notify(GlobalState.SUBSCRIPTION_NOTIFICATION_ID, builder.build())
    }
}
