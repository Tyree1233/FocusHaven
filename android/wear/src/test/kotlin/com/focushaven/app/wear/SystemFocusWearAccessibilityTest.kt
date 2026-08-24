package com.focushaven.app.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SystemFocusWearAccessibilityTest {
    @Test
    fun durationDescribesExactMinutesAndSeconds() {
        assertEquals(
            SystemFocusWearAccessibleDuration(minutes = 25, seconds = 0),
            SystemFocusWearAccessibility.duration(1_500),
        )
        assertEquals(
            SystemFocusWearAccessibleDuration(minutes = 1, seconds = 1),
            SystemFocusWearAccessibility.duration(61),
        )
        assertEquals(
            SystemFocusWearAccessibleDuration(minutes = 0, seconds = 0),
            SystemFocusWearAccessibility.duration(-10),
        )
    }

    @Test
    fun percentCompleteIsRoundedBoundedAndFailClosed() {
        assertEquals(0, SystemFocusWearAccessibility.completedPercent(1_500, 1_500))
        assertEquals(50, SystemFocusWearAccessibility.completedPercent(750, 1_500))
        assertEquals(100, SystemFocusWearAccessibility.completedPercent(0, 1_500))
        assertNull(SystemFocusWearAccessibility.completedPercent(-1, 1_500))
        assertNull(SystemFocusWearAccessibility.completedPercent(1_501, 1_500))
        assertNull(SystemFocusWearAccessibility.completedPercent(0, 0))
    }
}
