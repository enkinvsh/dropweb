package app.dropweb.plugins

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class EngineChannelRegistryTest {

    private val mainEngine = Any()
    private val serviceEngine = Any()

    @Test
    fun `service preferred when attached after main`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(mainEngine, "main", isService = false)
        registry.attach(serviceEngine, "service", isService = true)

        assertEquals("service", registry.current())
    }

    @Test
    fun `service preferred when main attaches last (app reopened while VPN live)`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(serviceEngine, "service", isService = true)
        registry.attach(mainEngine, "main", isService = false)

        assertEquals("service", registry.current())
    }

    @Test
    fun `detaching main while service attached keeps service`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(serviceEngine, "service", isService = true)
        registry.attach(mainEngine, "main", isService = false)

        assertEquals("main", registry.detach(mainEngine))
        assertEquals("service", registry.current())
        assertEquals(1, registry.size)
    }

    @Test
    fun `detaching preferred service falls back to remaining main`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(mainEngine, "main", isService = false)
        registry.attach(serviceEngine, "service", isService = true)

        assertEquals("service", registry.detach(serviceEngine))
        assertEquals("main", registry.current())
    }

    @Test
    fun `without service the most recently attached engine wins`() {
        val registry = EngineChannelRegistry<Any, String>()
        val other = Any()
        registry.attach(mainEngine, "main", isService = false)
        registry.attach(other, "other", isService = false)
        assertEquals("other", registry.current())

        registry.detach(other)
        assertEquals("main", registry.current())
    }

    @Test
    fun `none attached returns null`() {
        val registry = EngineChannelRegistry<Any, String>()
        assertNull(registry.current())

        registry.attach(mainEngine, "main", isService = false)
        registry.detach(mainEngine)
        assertNull(registry.current())
        assertEquals(0, registry.size)
    }

    @Test
    fun `detaching unknown engine is a no-op`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(serviceEngine, "service", isService = true)

        assertNull(registry.detach(mainEngine))
        assertEquals("service", registry.current())
    }

    @Test
    fun `re-attaching same engine replaces its channel`() {
        val registry = EngineChannelRegistry<Any, String>()
        registry.attach(mainEngine, "main-1", isService = false)

        assertEquals("main-1", registry.attach(mainEngine, "main-2", isService = false))
        assertEquals("main-2", registry.current())
        assertEquals(1, registry.size)
    }

    @Test
    fun `keys compare by identity not equality`() {
        val registry = EngineChannelRegistry<String, Any>()
        val keyA = String(charArrayOf('k'))
        val keyB = String(charArrayOf('k'))
        val channelA = Any()
        val channelB = Any()
        registry.attach(keyA, channelA, isService = true)
        registry.attach(keyB, channelB, isService = false)

        assertEquals(2, registry.size)
        registry.detach(keyA)
        assertSame(channelB, registry.current())
    }
}
