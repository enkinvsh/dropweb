package app.dropweb.services

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Regression lock for the TUN MTU.
 *
 * 9000 is the value inherited from the FlClashX desktop fork, where it targets
 * gigabit links. On a mobile bearer it forces fragmentation and was identified
 * as one of the root-cause layers behind slow Telegram uploads (investigation
 * 2026-04-09). The correction to 1500 was made and written up in CHANGELOG, then
 * silently reverted by the rebase conflict resolution in commit 9e7d946
 * (2026-05-26). It stayed broken for four months because nothing asserted it —
 * a one-constant fix with no test does not survive a rebase.
 *
 * This test is that assertion. Do not relax it without changing the reasoning
 * above.
 */
class TunMtuTest {

    @Test
    fun `tun mtu stays at the mobile link value and never returns to desktop 9000`() {
        assertEquals(
            "TUN MTU must stay 1500. 9000 is the inherited FlClashX desktop value and " +
                "fragments traffic on mobile bearers — it was reverted into the tree once " +
                "already by commit 9e7d946.",
            1500,
            DropwebVpnService.TUN_MTU,
        )
    }
}
