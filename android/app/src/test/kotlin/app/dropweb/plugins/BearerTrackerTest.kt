package app.dropweb.plugins

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BearerTrackerTest {

    @Test
    fun `first bearer establishes baseline without notifying core`() {
        val tracker = BearerTracker()

        val transition = tracker.commit(100L)

        assertEquals(null, transition.previousId)
        assertEquals(100L, transition.currentId)
        assertTrue(transition.identityChanged)
        assertFalse(transition.notifyCore)
    }

    @Test
    fun `same bearer is a no-op`() {
        val tracker = BearerTracker()
        tracker.commit(100L)

        val transition = tracker.commit(100L)

        assertEquals(100L, transition.previousId)
        assertEquals(100L, transition.currentId)
        assertFalse(transition.identityChanged)
        assertFalse(transition.notifyCore)
    }

    @Test
    fun `real bearer replacement notifies exactly once`() {
        val tracker = BearerTracker()
        tracker.commit(100L)

        val replacement = tracker.commit(200L)
        assertEquals(100L, replacement.previousId)
        assertEquals(200L, replacement.currentId)
        assertTrue(replacement.identityChanged)
        assertTrue(replacement.notifyCore)

        val repeat = tracker.commit(200L)
        assertFalse(repeat.identityChanged)
        assertFalse(repeat.notifyCore)
    }

    @Test
    fun `stale loss cannot clear replacement`() {
        val tracker = BearerTracker()
        tracker.commit(100L)
        tracker.commit(200L)

        // The coordinator consults isCurrent() before acting on onLost(old);
        // a stale handle must not identify as the committed bearer.
        assertFalse(tracker.isCurrent(100L))
        assertTrue(tracker.isCurrent(200L))
        assertEquals(200L, tracker.currentId())
    }

    @Test
    fun `active loss does not notify`() {
        val tracker = BearerTracker()
        tracker.commit(100L)

        val transition = tracker.commit(null)

        assertEquals(100L, transition.previousId)
        assertEquals(null, transition.currentId)
        assertTrue(transition.identityChanged)
        assertFalse(transition.notifyCore)
    }

    @Test
    fun `replacement after offline notifies`() {
        val tracker = BearerTracker()
        tracker.commit(100L)
        tracker.commit(null)

        val transition = tracker.commit(200L)

        assertEquals(null, transition.previousId)
        assertEquals(200L, transition.currentId)
        assertTrue(transition.identityChanged)
        assertTrue(transition.notifyCore)
    }

    @Test
    fun `reset restores first-snapshot suppression`() {
        val tracker = BearerTracker()
        tracker.commit(100L)
        val replacement = tracker.commit(200L)
        assertTrue(replacement.notifyCore)

        tracker.reset()
        assertEquals(null, tracker.currentId())

        val fresh = tracker.commit(300L)
        assertTrue(fresh.identityChanged)
        assertFalse(fresh.notifyCore)
    }

    @Test
    fun `dual SIM network identity change notifies`() {
        val tracker = BearerTracker()
        tracker.commit(100L)

        // Both handles are TRANSPORT_CELLULAR in real life; identity is the
        // handle alone, so a new handle must notify.
        val transition = tracker.commit(101L)

        assertTrue(transition.identityChanged)
        assertTrue(transition.notifyCore)
    }
}
