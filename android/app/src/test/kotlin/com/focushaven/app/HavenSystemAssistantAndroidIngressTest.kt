package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HavenSystemAssistantAndroidIngressTest {
    @Test
    fun routeAllowlistContainsExactlyFiveTextFreeKinds() {
        assertEquals(
            listOf(
                "readTimerStatus",
                "startFocusTimer",
                "pauseTimer",
                "resumeTimer",
                "openFocusQueue",
            ),
            HavenSystemAssistantAndroidRoute.entries.map { it.wireName },
        )
    }

    @Test
    fun payloadContainsOnlyVersionOpaqueIdAndKind() {
        val request =
            requireNotNull(
                HavenSystemAssistantAndroidRequest.create(
                    "android-request_1",
                    HavenSystemAssistantAndroidRoute.START_FOCUS_TIMER,
                ),
            )

        assertEquals(setOf("schemaVersion", "invocationId", "kind"), request.payload.keys)
        assertEquals(1, request.payload["schemaVersion"])
        assertEquals("android-request_1", request.payload["invocationId"])
        assertEquals("startFocusTimer", request.payload["kind"])
        assertFalse(request.payload.containsKey("transcript"))
        assertFalse(request.payload.containsKey("utterance"))
        assertFalse(request.payload.containsKey("task"))
        assertFalse(request.payload.containsKey("duration"))
    }

    @Test
    fun malformedInvocationIdsAreRejected() {
        val invalidIds =
            listOf(
                "",
                " leading-space",
                "contains/slash",
                "a".repeat(129),
                "private-🗒️",
            )
        for (invocationId in invalidIds) {
            assertNull(
                HavenSystemAssistantAndroidRequest.create(
                    invocationId,
                    HavenSystemAssistantAndroidRoute.READ_TIMER_STATUS,
                ),
            )
        }
    }

    @Test
    fun storeRejectsStackingAndRequiresExactAcknowledgement() {
        val store = HavenSystemAssistantAndroidPendingRequestStore()

        assertTrue(store.submit(HavenSystemAssistantAndroidRoute.PAUSE_TIMER, "first"))
        assertFalse(store.submit(HavenSystemAssistantAndroidRoute.RESUME_TIMER, "second"))
        assertEquals("first", store.peek()?.invocationId)
        assertFalse(store.clearIfMatches("different"))
        assertEquals(HavenSystemAssistantAndroidRoute.PAUSE_TIMER, store.peek()?.kind)
        assertTrue(store.clearIfMatches("first"))
        assertNull(store.peek())
    }
}
