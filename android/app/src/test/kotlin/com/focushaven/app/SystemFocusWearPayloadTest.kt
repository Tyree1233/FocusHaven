package com.focushaven.app

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearPayloadTest {
    private val generatedAt = "2026-08-17T13:00:00Z"

    @Test
    fun convertsOnlyTheExactTextFreeSnapshotContract() {
        val payload = SystemFocusWearPayload.fromSnapshot(snapshot())!!

        assertEquals(SystemFocusWearPayload.WIRE_KEYS, payload.wireMap.keys)
        assertEquals("focus", payload.wireMap["session"])
        assertEquals("ready", payload.wireMap["activity"])
        assertEquals(900, payload.wireMap["secondsRemaining"])
        assertEquals(1_500, payload.wireMap["totalSessionSeconds"])
        assertEquals(
            Instant.parse(generatedAt).toEpochMilli(),
            payload.wireMap["generatedAtMilliseconds"],
        )
        assertEquals(0L, payload.wireMap["endsAtMilliseconds"])
        assertEquals(
            SystemFocusWearPayload.snapshotTokenFor(generatedAt),
            payload.wireMap["snapshotToken"],
        )
        assertEquals(64, payload.snapshotToken.length)
        assertTrue(
            payload.wireMap.values.none { value ->
                value.toString().contains("private", ignoreCase = true)
            },
        )
    }

    @Test
    fun preservesOneValidatedRunningDeadline() {
        val payload =
            SystemFocusWearPayload.fromSnapshot(
                snapshot(
                    activity = "running",
                    secondsRemaining = 300,
                    endsAt = "2026-08-17T13:05:00Z",
                ),
            )!!

        assertEquals(
            Instant.parse("2026-08-17T13:05:00Z").toEpochMilli(),
            payload.endsAtMilliseconds,
        )
        assertEquals(300, payload.secondsRemaining)
    }

    @Test
    fun supportsEveryBoundedSessionAndActivity() {
        val sessions = listOf("focus", "shortBreak", "longBreak")
        val activities = listOf("ready", "paused", "pendingResume")

        for (session in sessions) {
            for (activity in activities) {
                val payload =
                    SystemFocusWearPayload.fromSnapshot(
                        snapshot(session = session, activity = activity),
                    )
                assertEquals(session, payload?.session)
                assertEquals(activity, payload?.activity)
            }
        }
        assertEquals(
            "completed",
            SystemFocusWearPayload.fromSnapshot(
                snapshot(activity = "completed", secondsRemaining = 0),
            )?.activity,
        )
    }

    @Test
    fun unknownFieldsAndPrivateTextFailClosed() {
        assertNull(
            SystemFocusWearPayload.fromSnapshot(
                snapshot().toMutableMap().apply { put("task", "private launch plan") },
            ),
        )
        assertNull(
            SystemFocusWearPayload.fromSnapshot(
                snapshot().toMutableMap().apply { put("accountId", "private-account") },
            ),
        )
        assertFalse(SystemFocusWearPayload.APPLICATION_KEYS.contains("task"))
        assertFalse(SystemFocusWearPayload.WIRE_KEYS.contains("accountId"))
    }

    @Test
    fun malformedAndImpossibleStatesFailClosed() {
        assertNull(SystemFocusWearPayload.fromSnapshot(snapshot(session = "unknown")))
        assertNull(SystemFocusWearPayload.fromSnapshot(snapshot(activity = "unknown")))
        assertNull(SystemFocusWearPayload.fromSnapshot(snapshot(totalSessionSeconds = 0)))
        assertNull(SystemFocusWearPayload.fromSnapshot(snapshot(secondsRemaining = 1_501)))
        assertNull(SystemFocusWearPayload.fromSnapshot(snapshot(generatedAt = "local-time")))
        assertNull(
            SystemFocusWearPayload.fromSnapshot(
                snapshot(activity = "running", endsAt = null),
            ),
        )
        assertNull(
            SystemFocusWearPayload.fromSnapshot(
                snapshot(activity = "paused", endsAt = "2026-08-17T13:05:00Z"),
            ),
        )
        assertNull(
            SystemFocusWearPayload.fromSnapshot(
                snapshot(activity = "completed", secondsRemaining = 1),
            ),
        )
    }

    private fun snapshot(
        session: String = "focus",
        activity: String = "ready",
        secondsRemaining: Int = 900,
        totalSessionSeconds: Int = 1_500,
        generatedAt: String = this.generatedAt,
        endsAt: String? = null,
    ): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "session" to session,
            "activity" to activity,
            "secondsRemaining" to secondsRemaining,
            "totalSessionSeconds" to totalSessionSeconds,
            "generatedAt" to generatedAt,
            "endsAt" to endsAt,
        )
}
