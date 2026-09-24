package app.dropweb.plugins

/**
 * Tracks one outbound channel per attached Flutter engine and picks the
 * channel VpnPlugin must use for Kotlin → Dart calls.
 *
 * VpnPlugin is a singleton attached to BOTH the main UI engine and the
 * background service engine (`_service` entrypoint). Only the service isolate
 * owns the real VPN state (VpnListener, getStartForegroundParams, status), so:
 *   * the service engine's channel always wins while it is attached,
 *     regardless of attach order;
 *   * otherwise the most recently attached remaining engine is used;
 *   * a detached (destroyed) engine is never returned;
 *   * nothing attached → null (caller skips the call).
 *
 * Keys are compared by identity (===). Pure Kotlin — no Android deps — so it
 * is JVM-unit-testable. All methods are synchronized; callers may read from
 * any thread.
 */
class EngineChannelRegistry<K : Any, C : Any> {
    private class Entry<K, C>(val key: K, val channel: C, val isService: Boolean, val seq: Long)

    private val entries = mutableListOf<Entry<K, C>>()
    private var nextSeq = 0L

    /** Registers (or replaces) the channel for [key]. Returns the replaced channel, if any. */
    @Synchronized
    fun attach(key: K, channel: C, isService: Boolean): C? {
        val replaced = removeEntry(key)
        entries.add(Entry(key, channel, isService, nextSeq++))
        return replaced
    }

    /** Removes the channel for [key] and returns it (so the caller can clear its handler). */
    @Synchronized
    fun detach(key: K): C? = removeEntry(key)

    /** The channel outbound calls must use, or null when no engine is attached. */
    @Synchronized
    fun current(): C? {
        entries.lastOrNull { it.isService }?.let { return it.channel }
        return entries.maxByOrNull { it.seq }?.channel
    }

    @get:Synchronized
    val size: Int
        get() = entries.size

    private fun removeEntry(key: K): C? {
        val index = entries.indexOfFirst { it.key === key }
        if (index < 0) return null
        return entries.removeAt(index).channel
    }
}
