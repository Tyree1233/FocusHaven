package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SystemFocusWidgetAccessibilityTest {
    @Test
    fun durationKeepsMinutesAndRemainingSecondsHumanReadable() {
        assertEquals(
            SystemFocusAccessibleDuration(minutes = 25, seconds = 0),
            SystemFocusWidgetAccessibility.duration(1_500),
        )
        assertEquals(
            SystemFocusAccessibleDuration(minutes = 1, seconds = 30),
            SystemFocusWidgetAccessibility.duration(90),
        )
        assertEquals(
            SystemFocusAccessibleDuration(minutes = 0, seconds = 0),
            SystemFocusWidgetAccessibility.duration(-1),
        )
    }

    @Test
    fun progressIsBoundedAndRejectsImpossibleTimerStates() {
        assertEquals(0, SystemFocusWidgetAccessibility.completedPercent(1_500, 1_500))
        assertEquals(50, SystemFocusWidgetAccessibility.completedPercent(750, 1_500))
        assertEquals(100, SystemFocusWidgetAccessibility.completedPercent(0, 1_500))
        assertNull(SystemFocusWidgetAccessibility.completedPercent(1, 0))
        assertNull(SystemFocusWidgetAccessibility.completedPercent(1_501, 1_500))
    }

    @Test
    fun compactLayoutIsSelectedWhenEitherDimensionIsConstrained() {
        assertEquals(
            SystemFocusWidgetLayout.STANDARD,
            SystemFocusWidgetAccessibility.layoutFor(180, 180),
        )
        assertEquals(
            SystemFocusWidgetLayout.COMPACT,
            SystemFocusWidgetAccessibility.layoutFor(179, 180),
        )
        assertEquals(
            SystemFocusWidgetLayout.COMPACT,
            SystemFocusWidgetAccessibility.layoutFor(180, 179),
        )
        assertEquals(
            SystemFocusWidgetLayout.COMPACT,
            SystemFocusWidgetAccessibility.layoutFor(0, 0),
        )
        assertEquals(
            SystemFocusWidgetLayout.COMPACT,
            SystemFocusWidgetAccessibility.layoutFor(180, 180, fontScale = 1.3f),
        )
        assertEquals(
            SystemFocusWidgetLayout.COMPACT,
            SystemFocusWidgetAccessibility.layoutFor(180, 180, fontScale = Float.NaN),
        )
    }
}
