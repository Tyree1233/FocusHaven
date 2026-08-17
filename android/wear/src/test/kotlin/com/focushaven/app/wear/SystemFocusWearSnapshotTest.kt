package com.focushaven.app.wear

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearSnapshotTest {
    private val now = Instant.parse("2026-08-17T13:00:00Z")

    @Test
    fun acceptsOnlyTheExactBoundedContract() {
        val snapshot = SystemFocusWearSnapshot.fromWireMap(wireMap())!!

        assertEquals(SystemFocusWearSession.FOCUS, snapshot.session)
        assertEquals(SystemFocusWearActivity.READY, snapshot.activity)
        assertEquals(now, snapshot.generatedAt)
        assertEquals(snapshotToken, snapshot.snapshotToken)
        assertEquals(SystemFocusWearSnapshot.WIRE_KEYS, wireMap().keys)
        assertFalse(SystemFocusWearSnapshot.WIRE_KEYS.contains("task"))
        assertFalse(SystemFocusWearSnapshot.WIRE_KEYS.contains("accountId"))
    }

    @Test
    fun mapsEverySessionAndStaticActivity() {
        val sessions =
            mapOf(
                "focus" to SystemFocusWearSession.FOCUS,
                "shortBreak" to SystemFocusWearSession.SHORT_BREAK,
                "longBreak" to SystemFocusWearSession.LONG_BREAK,
            )
        val activities =
            mapOf(
                "ready" to SystemFocusWearActivity.READY,
                "paused" to SystemFocusWearActivity.PAUSED,
                "pendingResume" to SystemFocusWearActivity.PENDING_RESUME,
            )

        for ((sessionName, expectedSession) in sessions) {
            for ((activityName, expectedActivity) in activities) {
                val snapshot =
                    SystemFocusWearSnapshot.fromWireMap(
                        wireMap(session = sessionName, activity = activityName),
                    )!!
                val presentation = snapshot.presentation(now)
                assertEquals(expectedSession, presentation.session)
                assertEquals(expectedActivity, presentation.activity)
                assertEquals(900, presentation.secondsRemaining)
            }
        }
    }

    @Test
    fun runningPresentationAdvancesFromItsLocalDeadline() {
        val snapshot =
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(
                    activity = "running",
                    secondsRemaining = 300,
                    endsAtMilliseconds = now.plusSeconds(300).toEpochMilli(),
                ),
            )!!

        val presentation = snapshot.presentation(now.plusSeconds(217))

        assertEquals(SystemFocusWearActivity.RUNNING, presentation.activity)
        assertEquals(83, presentation.secondsRemaining)
        assertEquals(1_417, presentation.completedSeconds)
    }

    @Test
    fun expiredDeadlineSettlesLocallyWithoutAnotherPhoneUpdate() {
        val snapshot =
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(
                    activity = "running",
                    secondsRemaining = 30,
                    endsAtMilliseconds = now.plusSeconds(30).toEpochMilli(),
                ),
            )!!

        val presentation = snapshot.presentation(now.plusSeconds(31))

        assertEquals(SystemFocusWearActivity.COMPLETED, presentation.activity)
        assertEquals(0, presentation.secondsRemaining)
        assertEquals(1_500, presentation.completedSeconds)
    }

    @Test
    fun unknownFieldsAndWrongNumericTypesFailClosed() {
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap().toMutableMap().apply { put("reflection", "private") },
            ),
        )
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap().toMutableMap().apply { put("secondsRemaining", 900L) },
            ),
        )
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap().toMutableMap().apply { put("generatedAtMilliseconds", 1.0) },
            ),
        )
    }

    @Test
    fun malformedAndImpossibleStatesFailClosed() {
        assertNull(SystemFocusWearSnapshot.fromWireMap(wireMap(session = "unknown")))
        assertNull(SystemFocusWearSnapshot.fromWireMap(wireMap(activity = "unknown")))
        assertNull(SystemFocusWearSnapshot.fromWireMap(wireMap(totalSessionSeconds = 0)))
        assertNull(SystemFocusWearSnapshot.fromWireMap(wireMap(secondsRemaining = 1_501)))
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(activity = "running", endsAtMilliseconds = 0L),
            ),
        )
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(activity = "paused", endsAtMilliseconds = now.plusSeconds(10).toEpochMilli()),
            ),
        )
        assertNull(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(activity = "completed", secondsRemaining = 1),
            ),
        )
        assertTrue(
            SystemFocusWearSnapshot.fromWireMap(
                wireMap(activity = "completed", secondsRemaining = 0),
            ) != null,
        )
    }

    private fun wireMap(
        session: String = "focus",
        activity: String = "ready",
        secondsRemaining: Int = 900,
        totalSessionSeconds: Int = 1_500,
        generatedAtMilliseconds: Long = now.toEpochMilli(),
        endsAtMilliseconds: Long = 0L,
        snapshotToken: String = this.snapshotToken,
    ): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 2,
            "session" to session,
            "activity" to activity,
            "secondsRemaining" to secondsRemaining,
            "totalSessionSeconds" to totalSessionSeconds,
            "generatedAtMilliseconds" to generatedAtMilliseconds,
            "endsAtMilliseconds" to endsAtMilliseconds,
            "snapshotToken" to snapshotToken,
        )

    private val snapshotToken = "a".repeat(64)
}
