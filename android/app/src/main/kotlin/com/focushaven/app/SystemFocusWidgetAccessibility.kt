package com.focushaven.app

import kotlin.math.roundToInt

internal data class SystemFocusAccessibleDuration(
    val minutes: Int,
    val seconds: Int,
) {
    init {
        require(minutes >= 0)
        require(seconds in 0..59)
    }
}

internal enum class SystemFocusWidgetLayout {
    STANDARD,
    COMPACT,
}

/** Pure presentation rules shared by the widget renderer and native tests. */
internal object SystemFocusWidgetAccessibility {
    const val STANDARD_MIN_WIDTH_DP = 180
    const val STANDARD_MIN_HEIGHT_DP = 180
    const val LARGE_TEXT_SCALE = 1.3f

    fun duration(seconds: Int): SystemFocusAccessibleDuration {
        val boundedSeconds = seconds.coerceAtLeast(0)
        return SystemFocusAccessibleDuration(
            minutes = boundedSeconds / 60,
            seconds = boundedSeconds % 60,
        )
    }

    fun completedPercent(
        secondsRemaining: Int,
        totalSessionSeconds: Int,
    ): Int? {
        if (totalSessionSeconds < 1 || secondsRemaining !in 0..totalSessionSeconds) return null
        return (
            (totalSessionSeconds - secondsRemaining).toDouble() /
                totalSessionSeconds.toDouble() *
                100.0
            ).roundToInt().coerceIn(0, 100)
    }

    fun layoutFor(
        minWidthDp: Int,
        minHeightDp: Int,
        fontScale: Float = 1.0f,
    ): SystemFocusWidgetLayout =
        if (
            minWidthDp >= STANDARD_MIN_WIDTH_DP &&
            minHeightDp >= STANDARD_MIN_HEIGHT_DP &&
            fontScale.isFinite() &&
            fontScale < LARGE_TEXT_SCALE
        ) {
            SystemFocusWidgetLayout.STANDARD
        } else {
            SystemFocusWidgetLayout.COMPACT
        }
}
