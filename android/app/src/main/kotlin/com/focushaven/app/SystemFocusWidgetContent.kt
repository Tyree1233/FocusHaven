package com.focushaven.app

import java.time.Duration
import java.time.Instant
import kotlin.math.ceil

internal enum class SystemFocusWidgetSession {
    FOCUS,
    SHORT_BREAK,
    LONG_BREAK,
}

internal enum class SystemFocusWidgetActivity {
    READY,
    RUNNING,
    PAUSED,
    COMPLETED,
    PENDING_RESUME,
}

/** Text-free presentation state derived only from the validated snapshot. */
internal data class SystemFocusWidgetContent(
    val session: SystemFocusWidgetSession,
    val activity: SystemFocusWidgetActivity,
    val secondsRemaining: Int,
    val totalSessionSeconds: Int,
    val endsAt: Instant?,
) {
    val isRunning: Boolean
        get() = activity == SystemFocusWidgetActivity.RUNNING && endsAt != null

    val completedSeconds: Int
        get() = (totalSessionSeconds - secondsRemaining).coerceIn(0, totalSessionSeconds)

    companion object {
        fun fromSnapshot(
            snapshot: Map<String, Any?>?,
            now: Instant = Instant.now(),
        ): SystemFocusWidgetContent? {
            if (snapshot == null) return null
            val session =
                when (snapshot["session"]) {
                    "focus" -> SystemFocusWidgetSession.FOCUS
                    "shortBreak" -> SystemFocusWidgetSession.SHORT_BREAK
                    "longBreak" -> SystemFocusWidgetSession.LONG_BREAK
                    else -> return null
                }
            val activity =
                when (snapshot["activity"]) {
                    "ready" -> SystemFocusWidgetActivity.READY
                    "running" -> SystemFocusWidgetActivity.RUNNING
                    "paused" -> SystemFocusWidgetActivity.PAUSED
                    "completed" -> SystemFocusWidgetActivity.COMPLETED
                    "pendingResume" -> SystemFocusWidgetActivity.PENDING_RESUME
                    else -> return null
                }
            val storedRemaining = snapshot["secondsRemaining"] as? Int ?: return null
            val total = snapshot["totalSessionSeconds"] as? Int ?: return null
            if (storedRemaining !in 0..total || total < 1) return null
            if (activity != SystemFocusWidgetActivity.RUNNING) {
                return SystemFocusWidgetContent(
                    session = session,
                    activity = activity,
                    secondsRemaining = storedRemaining,
                    totalSessionSeconds = total,
                    endsAt = null,
                )
            }

            val endsAtText = snapshot["endsAt"] as? String ?: return null
            val deadline = runCatching { Instant.parse(endsAtText) }.getOrNull() ?: return null
            val remainingMillis = Duration.between(now, deadline).toMillis()
            if (remainingMillis <= 0) {
                return SystemFocusWidgetContent(
                    session = session,
                    activity = SystemFocusWidgetActivity.COMPLETED,
                    secondsRemaining = 0,
                    totalSessionSeconds = total,
                    endsAt = null,
                )
            }
            val liveRemaining = ceil(remainingMillis / 1000.0).toInt().coerceIn(1, total)
            return SystemFocusWidgetContent(
                session = session,
                activity = activity,
                secondsRemaining = liveRemaining,
                totalSessionSeconds = total,
                endsAt = deadline,
            )
        }
    }
}
