package app.dropweb.plugins

/**
 * Result of committing a bearer identity to [BearerTracker].
 *
 * `notifyCore` is true only for a real bearer replacement: the core must drop
 * stale flows exactly once per physical-network change, never on baseline
 * establishment and never on connectivity loss.
 */
internal data class BearerTransition(
    val previousId: Long?,
    val currentId: Long?,
    val identityChanged: Boolean,
    val notifyCore: Boolean,
)

/**
 * Pure reducer owning the active-bearer identity for one VPN session.
 *
 * Identity is `Network.networkHandle` alone (as a [Long] so JVM tests need no
 * Android runtime). Transport, validation state, DNS, BSSID, interface name
 * and metering are deliberately NOT part of identity: a dual-SIM switch is a
 * real change even though both networks are TRANSPORT_CELLULAR, while a WiFi
 * BSSID roam that retains the same Network is not a bearer change.
 */
internal class BearerTracker {
    private var currentId: Long? = null
    private var baselineEstablished = false

    fun currentId(): Long? = currentId

    fun isCurrent(id: Long): Boolean = currentId == id

    fun commit(nextId: Long?): BearerTransition {
        val previous = currentId

        if (previous == nextId) {
            return BearerTransition(
                previousId = previous,
                currentId = nextId,
                identityChanged = false,
                notifyCore = false,
            )
        }

        currentId = nextId

        // Losing connectivity is not itself a core-reset event. Old connections
        // are reset when a replacement bearer is committed.
        if (nextId == null) {
            return BearerTransition(
                previousId = previous,
                currentId = null,
                identityChanged = true,
                notifyCore = false,
            )
        }

        // The first real bearer of each VPN session is a baseline. Connections
        // from a previous VPN session do not survive into this session.
        if (!baselineEstablished) {
            baselineEstablished = true
            return BearerTransition(
                previousId = previous,
                currentId = nextId,
                identityChanged = true,
                notifyCore = false,
            )
        }

        return BearerTransition(
            previousId = previous,
            currentId = nextId,
            identityChanged = true,
            notifyCore = true,
        )
    }

    fun reset() {
        currentId = null
        baselineEstablished = false
    }
}
