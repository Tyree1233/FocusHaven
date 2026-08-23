package com.focushaven.app.wear

/** Prevents a completed command tap from falling through to the next action. */
internal class SystemFocusWearCommandCooldown(
    private val nowMilliseconds: () -> Long,
) {
    private var blockedUntilMilliseconds = 0L

    val isActive: Boolean
        get() = remainingMilliseconds > 0L

    val remainingMilliseconds: Long
        get() = (blockedUntilMilliseconds - nowMilliseconds()).coerceAtLeast(0L)

    fun start(durationMilliseconds: Long) {
        require(durationMilliseconds > 0L)
        blockedUntilMilliseconds = nowMilliseconds() + durationMilliseconds
    }
}
