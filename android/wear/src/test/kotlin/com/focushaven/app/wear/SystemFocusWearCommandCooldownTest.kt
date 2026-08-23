package com.focushaven.app.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearCommandCooldownTest {
    @Test
    fun blocksTheNextActionForOneBoundedPostCommandWindow() {
        var nowMilliseconds = 10_000L
        val cooldown = SystemFocusWearCommandCooldown { nowMilliseconds }

        assertFalse(cooldown.isActive)

        cooldown.start(FocusHavenWearActivity.COMMAND_INPUT_COOLDOWN_MILLIS)

        assertTrue(cooldown.isActive)
        assertEquals(1_000L, cooldown.remainingMilliseconds)

        nowMilliseconds += 999L
        assertTrue(cooldown.isActive)
        assertEquals(1L, cooldown.remainingMilliseconds)

        nowMilliseconds += 1L
        assertFalse(cooldown.isActive)
        assertEquals(0L, cooldown.remainingMilliseconds)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsAnUnboundedOrMissingCooldownDuration() {
        SystemFocusWearCommandCooldown { 0L }.start(0L)
    }
}
