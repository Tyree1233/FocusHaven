package com.focushaven.app.wear

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWearCommandTest {
    private val requestId = "wear_request_123"

    @Test
    fun everySnapshotExposesOnlyItsPhoneAuthorizedActions() {
        val allowed =
            mapOf(
                SystemFocusWearActivity.READY to setOf(SystemFocusWearAction.START),
                SystemFocusWearActivity.RUNNING to
                    setOf(SystemFocusWearAction.PAUSE, SystemFocusWearAction.RESET),
                SystemFocusWearActivity.PAUSED to
                    setOf(SystemFocusWearAction.RESUME, SystemFocusWearAction.RESET),
                SystemFocusWearActivity.COMPLETED to
                    setOf(SystemFocusWearAction.BEGIN_NEXT_SESSION),
                SystemFocusWearActivity.PENDING_RESUME to
                    setOf(SystemFocusWearAction.RESUME, SystemFocusWearAction.DISCARD_PENDING),
            )

        for ((activity, actions) in allowed) {
            assertEquals(actions, snapshot(activity).availableActions)
            for (action in actions) {
                assertEquals(
                    action,
                    SystemFocusWearCommand.create(snapshot(activity), action, requestId)?.action,
                )
            }
        }
    }

    @Test
    fun commandEnvelopeIsExactTextFreeAndBoundToTheSnapshotToken() {
        val command =
            SystemFocusWearCommand.create(
                snapshot(SystemFocusWearActivity.RUNNING),
                SystemFocusWearAction.PAUSE,
                requestId,
            )!!

        assertEquals(SystemFocusWearCommand.WIRE_KEYS, command.wireMap.keys)
        assertEquals(snapshotToken, command.wireMap["snapshotToken"])
        assertFalse(command.wireMap.keys.contains("task"))
        assertTrue(command.wireMap.values.none { it.toString().contains("private", true) })
    }

    @Test
    fun unavailableActionsAndMalformedCapabilitiesFailClosed() {
        assertNull(
            SystemFocusWearCommand.create(
                snapshot(SystemFocusWearActivity.READY),
                SystemFocusWearAction.RESET,
                requestId,
            ),
        )
        assertNull(
            SystemFocusWearCommand.create(
                snapshot(SystemFocusWearActivity.READY),
                SystemFocusWearAction.START,
                "short",
            ),
        )
        assertNull(
            SystemFocusWearCommand.create(
                snapshot(SystemFocusWearActivity.READY, token = "bad"),
                SystemFocusWearAction.START,
                requestId,
            ),
        )
    }

    @Test
    fun acknowledgementParserRequiresTheExactRequestAndBooleanReceipt() {
        val accepted =
            SystemFocusWearAcknowledgement.fromWireMap(
                mapOf(
                    "schemaVersion" to 1,
                    "requestId" to requestId,
                    "accepted" to true,
                ),
            )!!

        assertEquals(requestId, accepted.requestId)
        assertTrue(accepted.accepted)
        assertNull(
            SystemFocusWearAcknowledgement.fromWireMap(
                mapOf(
                    "schemaVersion" to 1,
                    "requestId" to requestId,
                    "accepted" to 1,
                ),
            ),
        )
        assertNull(
            SystemFocusWearAcknowledgement.fromWireMap(
                mapOf(
                    "schemaVersion" to 1,
                    "requestId" to requestId,
                    "accepted" to false,
                    "message" to "private text",
                ),
            ),
        )
    }

    private fun snapshot(
        activity: SystemFocusWearActivity,
        token: String = snapshotToken,
    ): SystemFocusWearSnapshot =
        SystemFocusWearSnapshot(
            session = SystemFocusWearSession.FOCUS,
            activity = activity,
            secondsRemaining = if (activity == SystemFocusWearActivity.COMPLETED) 0 else 900,
            totalSessionSeconds = 1_500,
            generatedAt = Instant.parse("2026-08-17T13:00:00Z"),
            endsAt =
                if (activity == SystemFocusWearActivity.RUNNING) {
                    Instant.parse("2026-08-17T13:15:00Z")
                } else {
                    null
                },
            snapshotToken = token,
        )

    private val snapshotToken = "a".repeat(64)
}
