package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearCommandPolicyTest {
    private val generatedAt = "2026-08-17T13:00:00.123456Z"
    private val requestId = "wear_request_123"

    @Test
    fun authorizesOnlyAnAdvertisedActionForTheExactOpaqueSnapshot() {
        val authorized =
            SystemFocusWearCommandPolicy.authorize(
                snapshot(activity = "running"),
                command(action = "pause"),
            )!!

        assertEquals(requestId, authorized.requestId)
        assertEquals("pause", authorized.action)
        assertEquals(generatedAt, authorized.snapshotGeneratedAt)
    }

    @Test
    fun everyActivityAcceptsOnlyItsAdvertisedActions() {
        val allowed =
            mapOf(
                "ready" to setOf("start"),
                "running" to setOf("pause", "reset"),
                "paused" to setOf("resume", "reset"),
                "completed" to setOf("beginNextSession"),
                "pendingResume" to setOf("resume", "discardPending"),
            )

        for ((activity, actions) in allowed) {
            for (action in actions) {
                assertEquals(
                    action,
                    SystemFocusWearCommandPolicy.authorize(
                        snapshot(activity = activity),
                        command(action = action),
                    )?.action,
                )
            }
            val disallowed = allowed.values.flatten().first { it !in actions }
            assertNull(
                SystemFocusWearCommandPolicy.authorize(
                    snapshot(activity = activity),
                    command(action = disallowed),
                ),
            )
        }
    }

    @Test
    fun staleMalformedAndPrivateCommandsFailClosed() {
        assertNull(
            SystemFocusWearCommandPolicy.authorize(
                snapshot(),
                command(snapshotToken = "b".repeat(64)),
            ),
        )
        assertNull(
            SystemFocusWearCommandPolicy.authorize(
                snapshot(),
                command().toMutableMap().apply { put("task", "private plan") },
            ),
        )
        assertNull(
            SystemFocusWearCommandPolicy.authorize(
                snapshot(),
                command(requestId = "short"),
            ),
        )
        assertNull(
            SystemFocusWearCommandPolicy.authorize(
                snapshot(),
                command().toMutableMap().apply { put("schemaVersion", 2) },
            ),
        )
        assertFalse(SystemFocusWearCommandPolicy.WIRE_KEYS.contains("accountId"))
    }

    @Test
    fun acknowledgementsAreExactAndTextFree() {
        val accepted = SystemFocusWearCommandPolicy.acknowledgement(requestId, true)!!

        assertEquals(SystemFocusWearCommandPolicy.ACKNOWLEDGEMENT_KEYS, accepted.keys)
        assertEquals(true, accepted["accepted"])
        assertTrue(accepted.values.none { it.toString().contains("private", ignoreCase = true) })
        assertNull(SystemFocusWearCommandPolicy.acknowledgement("bad id", false))
    }

    private fun command(
        action: String = "start",
        requestId: String = this.requestId,
        snapshotToken: String = SystemFocusWearPayload.snapshotTokenFor(generatedAt),
    ): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "requestId" to requestId,
            "action" to action,
            "snapshotToken" to snapshotToken,
        )

    private fun snapshot(activity: String = "ready"): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "session" to "focus",
            "activity" to activity,
            "secondsRemaining" to if (activity == "completed") 0 else 900,
            "totalSessionSeconds" to 1_500,
            "generatedAt" to generatedAt,
            "endsAt" to if (activity == "running") "2026-08-17T13:15:00.123456Z" else null,
        )
}
