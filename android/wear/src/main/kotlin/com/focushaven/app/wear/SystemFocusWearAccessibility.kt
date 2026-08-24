package com.focushaven.app.wear

import kotlin.math.roundToInt

internal data class SystemFocusWearAccessibleDuration(
    val minutes: Int,
    val seconds: Int,
) {
    init {
        require(minutes >= 0)
        require(seconds in 0..59)
    }
}

/** Pure accessibility values derived only from the text-free timer snapshot. */
internal object SystemFocusWearAccessibility {
    fun duration(seconds: Int): SystemFocusWearAccessibleDuration {
        val boundedSeconds = seconds.coerceAtLeast(0)
        return SystemFocusWearAccessibleDuration(
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
}
