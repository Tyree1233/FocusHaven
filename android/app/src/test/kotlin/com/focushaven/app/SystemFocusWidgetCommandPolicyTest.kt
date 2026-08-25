package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemFocusWidgetCommandPolicyTest {
    private val generatedAt = "2026-08-16T21:00:00Z"

    @Test
    fun everyActivityAllowsOnlyItsAdvertisedActions() {
        val expectations =
            mapOf(
                "ready" to setOf("start"),
                "running" to setOf("pause", "reset"),
                "paused" to setOf("resume", "reset"),
                "completed" to setOf("beginNextSession"),
                "pendingResume" to setOf("resume", "discardPending"),
            )
        val everyAction = expectations.values.flatten().toSet()

        for ((activity, allowed) in expectations) {
            for (action in everyAction) {
                assertEquals(
                    action in allowed,
                    SystemFocusWidgetCommandPolicy.isAllowed(
                        snapshot(activity),
                        action,
                        generatedAt,
                    ),
                )
            }
        }
    }

    @Test
    fun staleMalformedAndUnknownRequestsFailClosed() {
        val ready = snapshot("ready")

        assertFalse(
            SystemFocusWidgetCommandPolicy.isAllowed(
                ready,
                "start",
                "2026-08-16T20:59:59Z",
            ),
        )
        assertFalse(SystemFocusWidgetCommandPolicy.isAllowed(ready, "pause", generatedAt))
        assertFalse(SystemFocusWidgetCommandPolicy.isAllowed(ready, "unknown", generatedAt))
        assertFalse(SystemFocusWidgetCommandPolicy.isAllowed(ready, "start", "not-a-time"))
    }

    @Test
    fun exactTextFreeEnvelopeIsAccepted() {
        val envelope = command()

        assertEquals(envelope, SystemFocusWidgetCommandPolicy.validateEnvelope(envelope))
        assertTrue(envelope.values.none { it.toString().contains("private") })
    }

    @Test
    fun extraFieldsAndMalformedEnvelopeValuesAreRejected() {
        assertNull(
            SystemFocusWidgetCommandPolicy.validateEnvelope(
                command().toMutableMap().apply { put("task", "private plan") },
            ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.validateEnvelope(
                command().toMutableMap().apply { put("requestId", "short") },
            ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.validateEnvelope(
                command().toMutableMap().apply { put("snapshotGeneratedAt", "local time") },
            ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.validateEnvelope(
                command().toMutableMap().apply { put("action", "eraseEverything") },
            ),
        )
    }

    @Test
    fun pendingIntentIdentityRotatesWithActionAndSnapshot() {
        val startIdentity =
            SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                "start",
                generatedAt,
            )

        assertEquals(
            "focushaven://system-focus-command/start/1786914000000",
            startIdentity,
        )
        assertTrue(
            startIdentity !=
                SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                    "pause",
                    generatedAt,
                ),
        )
        assertTrue(
            startIdentity !=
                SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                    "start",
                    "2026-08-16T21:00:01Z",
                ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                "unknown",
                generatedAt,
            ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                "start",
                "not-a-time",
            ),
        )

        val notificationIdentity =
            SystemFocusWidgetCommandPolicy.notificationPendingIntentIdentity(
                "start",
                generatedAt,
            )
        assertEquals(
            "focushaven://system-focus-notification-command/start/1786914000000",
            notificationIdentity,
        )
        assertTrue(notificationIdentity != startIdentity)
        assertNull(
            SystemFocusWidgetCommandPolicy.notificationPendingIntentIdentity(
                "unknown",
                generatedAt,
            ),
        )
        assertNull(
            SystemFocusWidgetCommandPolicy.notificationPendingIntentIdentity(
                "start",
                "not-a-time",
            ),
        )
    }

    @Test
    fun onlyTrueAcknowledgementAllowsPendingCommandRemoval() {
        assertTrue(SystemFocusPendingCommandStore.shouldClearAfterAcknowledgement(true))
        assertFalse(SystemFocusPendingCommandStore.shouldClearAfterAcknowledgement(false))
        assertFalse(SystemFocusPendingCommandStore.shouldClearAfterAcknowledgement(null))
        assertFalse(SystemFocusPendingCommandStore.shouldClearAfterAcknowledgement("true"))
    }

    @Test
    fun pendingCommandsExpireQuicklyAndRejectFutureCreationTimes() {
        val now = 1_700_000_000_000L

        assertTrue(SystemFocusWidgetCommandPolicy.isFreshPendingCommand(now, now))
        assertTrue(
            SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
                now,
                now + SystemFocusWidgetCommandPolicy.MAXIMUM_PENDING_AGE_MILLIS,
            ),
        )
        assertFalse(
            SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
                now,
                now + SystemFocusWidgetCommandPolicy.MAXIMUM_PENDING_AGE_MILLIS + 1,
            ),
        )
        assertFalse(SystemFocusWidgetCommandPolicy.isFreshPendingCommand(now + 1, now))
    }

    private fun snapshot(activity: String): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "session" to "focus",
            "activity" to activity,
            "secondsRemaining" to if (activity == "completed") 0 else 300,
            "totalSessionSeconds" to 300,
            "generatedAt" to generatedAt,
            "endsAt" to null,
        )

    private fun command(): Map<String, Any?> =
        mapOf(
            "schemaVersion" to 1,
            "requestId" to "native_request_0001",
            "action" to "start",
            "snapshotGeneratedAt" to generatedAt,
        )
}
