package com.focushaven.app

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWidgetContentTest {
    private val now = Instant.parse("2026-08-16T18:00:00Z")

    @Test
    fun missingSnapshotStaysUnavailable() {
        assertNull(SystemFocusWidgetContent.fromSnapshot(null, now))
    }

    @Test
    fun mapsEverySessionAndStaticActivity() {
        val expectations =
            listOf(
                Triple("focus", "ready", SystemFocusWidgetSession.FOCUS),
                Triple("shortBreak", "paused", SystemFocusWidgetSession.SHORT_BREAK),
                Triple("longBreak", "pendingResume", SystemFocusWidgetSession.LONG_BREAK),
            )

        for ((session, activity, expectedSession) in expectations) {
            val content =
                SystemFocusWidgetContent.fromSnapshot(
                    snapshot(session = session, activity = activity),
                    now,
                )!!

            assertEquals(expectedSession, content.session)
            assertEquals(activityEnum(activity), content.activity)
            assertEquals(900, content.secondsRemaining)
            assertEquals(600, content.completedSeconds)
            assertFalse(content.isRunning)
            assertNull(content.endsAt)
        }
    }

    @Test
    fun runningContentUsesTheLiveDeadlineInsteadOfStoredAge() {
        val deadline = now.plusSeconds(83)

        val content =
            SystemFocusWidgetContent.fromSnapshot(
                snapshot(
                    activity = "running",
                    secondsRemaining = 120,
                    endsAt = deadline.toString(),
                ),
                now,
            )!!

        assertEquals(SystemFocusWidgetActivity.RUNNING, content.activity)
        assertEquals(83, content.secondsRemaining)
        assertEquals(deadline, content.endsAt)
        assertTrue(content.isRunning)
    }

    @Test
    fun expiredRunningContentSettlesAsCompleteWithoutBackgroundWork() {
        val content =
            SystemFocusWidgetContent.fromSnapshot(
                snapshot(
                    activity = "running",
                    secondsRemaining = 30,
                    endsAt = now.minusSeconds(1).toString(),
                ),
                now,
            )!!

        assertEquals(SystemFocusWidgetActivity.COMPLETED, content.activity)
        assertEquals(0, content.secondsRemaining)
        assertFalse(content.isRunning)
        assertNull(content.endsAt)
    }

    @Test
    fun malformedPresentationInputFailsClosed() {
        assertNull(
            SystemFocusWidgetContent.fromSnapshot(
                snapshot(session = "unknown"),
                now,
            ),
        )
        assertNull(
            SystemFocusWidgetContent.fromSnapshot(
                snapshot(totalSessionSeconds = 0),
                now,
            ),
        )
        assertNull(
            SystemFocusWidgetContent.fromSnapshot(
                snapshot(activity = "running", endsAt = "not-a-time"),
                now,
            ),
        )
    }

    @Test
    fun unrelatedPrivateTextCannotChangeWidgetContent() {
        val first = snapshot().toMutableMap().apply { put("task", "Private plan") }
        val second = snapshot().toMutableMap().apply { put("task", "Different secret") }

        assertEquals(
            SystemFocusWidgetContent.fromSnapshot(first, now),
            SystemFocusWidgetContent.fromSnapshot(second, now),
        )
    }

    private fun snapshot(
        session: String = "focus",
        activity: String = "ready",
        secondsRemaining: Int = 900,
        totalSessionSeconds: Int = 1500,
        endsAt: String? = null,
    ): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "session" to session,
            "activity" to activity,
            "secondsRemaining" to secondsRemaining,
            "totalSessionSeconds" to totalSessionSeconds,
            "generatedAt" to now.toString(),
            "endsAt" to endsAt,
        )

    private fun activityEnum(value: String): SystemFocusWidgetActivity =
        when (value) {
            "ready" -> SystemFocusWidgetActivity.READY
            "paused" -> SystemFocusWidgetActivity.PAUSED
            "pendingResume" -> SystemFocusWidgetActivity.PENDING_RESUME
            else -> error("Unsupported test activity")
        }
}
