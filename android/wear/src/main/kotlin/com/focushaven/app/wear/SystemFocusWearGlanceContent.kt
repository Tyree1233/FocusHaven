package com.focushaven.app.wear

import java.time.Instant
import java.util.Locale

/** Read-only projection shared by the Tile and complication data source. */
internal data class SystemFocusWearGlanceContent(
    val session: SystemFocusWearSession,
    val activity: SystemFocusWearActivity,
    val secondsRemaining: Int,
    val totalSessionSeconds: Int,
    val endsAt: Instant?,
) {
    val completedSeconds: Int
        get() = (totalSessionSeconds - secondsRemaining).coerceIn(0, totalSessionSeconds)

    val compactTime: String
        get() = String.format(Locale.US, "%d:%02d", secondsRemaining / 60, secondsRemaining % 60)

    val progress: Float
        get() = completedSeconds.toFloat() / totalSessionSeconds.toFloat()

    companion object {
        fun from(
            snapshot: SystemFocusWearSnapshot,
            now: Instant = Instant.now(),
        ): SystemFocusWearGlanceContent {
            val presentation = snapshot.presentation(now)
            return SystemFocusWearGlanceContent(
                session = presentation.session,
                activity = presentation.activity,
                secondsRemaining = presentation.secondsRemaining,
                totalSessionSeconds = presentation.totalSessionSeconds,
                endsAt =
                    if (presentation.activity == SystemFocusWearActivity.RUNNING) {
                        snapshot.endsAt
                    } else {
                        null
                    },
            )
        }
    }
}
