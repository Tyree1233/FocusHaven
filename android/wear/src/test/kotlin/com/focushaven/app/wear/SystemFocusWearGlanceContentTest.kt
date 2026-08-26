package com.focushaven.app.wear

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearGlanceContentTest {
    private val now = Instant.parse("2026-08-25T16:00:00Z")

    @Test
    fun projectsOnlyBoundedDisplayState() {
        val content = SystemFocusWearGlanceContent.from(snapshot(), now)

        assertEquals(SystemFocusWearSession.FOCUS, content.session)
        assertEquals(SystemFocusWearActivity.PAUSED, content.activity)
        assertEquals(1_488, content.secondsRemaining)
        assertEquals(1_500, content.totalSessionSeconds)
        assertEquals("24:48", content.compactTime)
        assertEquals(12, content.completedSeconds)
        assertEquals(0.008f, content.progress, 0.0001f)
        assertNull(content.endsAt)
        assertTrue(
            SystemFocusWearGlanceContent::class.java.declaredFields.none {
                it.name.contains("token", ignoreCase = true)
            },
        )
    }

    @Test
    fun runningProjectionAdvancesFromDeadlineAndExpiresLocally() {
        val running =
            snapshot(
                activity = "running",
                secondsRemaining = 300,
                endsAt = now.plusSeconds(300),
            )

        val active = SystemFocusWearGlanceContent.from(running, now.plusSeconds(217))
        val expired = SystemFocusWearGlanceContent.from(running, now.plusSeconds(301))

        assertEquals(SystemFocusWearActivity.RUNNING, active.activity)
        assertEquals(83, active.secondsRemaining)
        assertEquals(now.plusSeconds(300), active.endsAt)
        assertEquals(SystemFocusWearActivity.COMPLETED, expired.activity)
        assertEquals(0, expired.secondsRemaining)
        assertNull(expired.endsAt)
    }

    private fun snapshot(
        activity: String = "paused",
        secondsRemaining: Int = 1_488,
        endsAt: Instant? = null,
    ): SystemFocusWearSnapshot =
        checkNotNull(
            SystemFocusWearSnapshot.fromWireMap(
                mapOf(
                    "schemaVersion" to 2,
                    "session" to "focus",
                    "activity" to activity,
                    "secondsRemaining" to secondsRemaining,
                    "totalSessionSeconds" to 1_500,
                    "generatedAtMilliseconds" to now.toEpochMilli(),
                    "endsAtMilliseconds" to (endsAt?.toEpochMilli() ?: 0L),
                    "snapshotToken" to "a".repeat(64),
                ),
            ),
        )
}
