package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HavenSystemAssistantAndroidAppActionResolverTest {
    private val completeCopy = HavenSystemAssistantAndroidNativeCopy { "Reviewed copy $it" }

    @Test
    fun exactFiveActionsSubmitOnlyTheExistingThreeFieldRequests() {
        val actions =
            listOf(
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_TIMER_STATUS_ACTION to
                    HavenSystemAssistantAndroidRoute.READ_TIMER_STATUS,
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_START_TIMER_ACTION to
                    HavenSystemAssistantAndroidRoute.START_FOCUS_TIMER,
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_PAUSE_TIMER_ACTION to
                    HavenSystemAssistantAndroidRoute.PAUSE_TIMER,
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_RESUME_TIMER_ACTION to
                    HavenSystemAssistantAndroidRoute.RESUME_TIMER,
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_OPEN_QUEUE_ACTION to
                    HavenSystemAssistantAndroidRoute.OPEN_FOCUS_QUEUE,
            )

        actions.forEachIndexed { index, (action, route) ->
            val store = HavenSystemAssistantAndroidPendingRequestStore()
            val resolver =
                HavenSystemAssistantAndroidAppActionResolver(
                    store = store,
                    copy = completeCopy,
                    invocationIdFactory = { "app-action-$index" },
                )
            val extras =
                if (route == HavenSystemAssistantAndroidRoute.OPEN_FOCUS_QUEUE) {
                    mapOf(
                        HavenSystemAssistantAndroidAppActionResolver.FEATURE_EXTRA to
                            HavenSystemAssistantAndroidAppActionResolver.FOCUS_QUEUE_REVIEW_ID,
                    )
                } else {
                    emptyMap()
                }

            assertEquals(
                HavenSystemAssistantAndroidAppActionOutcome.READY_FOR_REVIEW,
                resolver.submit(action, extras, false, false, false),
            )
            val request = requireNotNull(store.peek())
            assertEquals(route, request.kind)
            assertEquals("app-action-$index", request.invocationId)
            assertEquals(setOf("schemaVersion", "invocationId", "kind"), request.payload.keys)
            assertFalse(request.payload.containsKey("feature"))
        }
    }

    @Test
    fun unknownOrAugmentedInputsFailClosed() {
        val rejectedInputs =
            listOf(
                Input(null),
                Input("android.intent.action.MAIN"),
                Input("com.focushaven.app.action.REVIEW_UNKNOWN"),
                Input(
                    HavenSystemAssistantAndroidAppActionResolver.REVIEW_TIMER_STATUS_ACTION,
                    mapOf("duration" to 25),
                ),
                Input(
                    HavenSystemAssistantAndroidAppActionResolver.REVIEW_PAUSE_TIMER_ACTION,
                    hasData = true,
                ),
                Input(
                    HavenSystemAssistantAndroidAppActionResolver.REVIEW_RESUME_TIMER_ACTION,
                    hasClipData = true,
                ),
                Input(
                    HavenSystemAssistantAndroidAppActionResolver.REVIEW_START_TIMER_ACTION,
                    hasSelector = true,
                ),
            )

        for (input in rejectedInputs) {
            val store = HavenSystemAssistantAndroidPendingRequestStore()
            val resolver = HavenSystemAssistantAndroidAppActionResolver(store, completeCopy)
            assertEquals(
                HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE,
                resolver.submit(
                    input.action,
                    input.extras,
                    input.hasData,
                    input.hasClipData,
                    input.hasSelector,
                ),
            )
            assertNull(store.peek())
        }
    }

    @Test
    fun queueInventoryMustMatchExactlyAndIsDiscarded() {
        for (extras in listOf(emptyMap(), mapOf("feature" to "focus_queue"), mapOf("feature" to 1), mapOf("feature" to "focus_queue_review", "extra" to "value"))) {
            val store = HavenSystemAssistantAndroidPendingRequestStore()
            val resolver = HavenSystemAssistantAndroidAppActionResolver(store, completeCopy)
            assertEquals(
                HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE,
                resolver.submit(
                    HavenSystemAssistantAndroidAppActionResolver.REVIEW_OPEN_QUEUE_ACTION,
                    extras,
                    false,
                    false,
                    false,
                ),
            )
            assertNull(store.peek())
        }
    }

    @Test
    fun missingReviewedCopyOrMalformedGeneratedIdFailsBeforeSubmission() {
        val store = HavenSystemAssistantAndroidPendingRequestStore()
        val missingCopy = HavenSystemAssistantAndroidNativeCopy { null }
        val missingCopyResolver = HavenSystemAssistantAndroidAppActionResolver(store, missingCopy)
        assertEquals(
            HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE,
            missingCopyResolver.submit(
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_PAUSE_TIMER_ACTION,
                emptyMap(),
                false,
                false,
                false,
            ),
        )
        val malformedIdResolver =
            HavenSystemAssistantAndroidAppActionResolver(
                store,
                completeCopy,
                invocationIdFactory = { "invalid/id" },
            )
        assertEquals(
            HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE,
            malformedIdResolver.submit(
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_PAUSE_TIMER_ACTION,
                emptyMap(),
                false,
                false,
                false,
            ),
        )
        assertNull(store.peek())
    }

    @Test
    fun occupiedSlotIsPreservedAndReportedAsPending() {
        val store = HavenSystemAssistantAndroidPendingRequestStore()
        assertTrue(store.submit(HavenSystemAssistantAndroidRoute.PAUSE_TIMER, "existing"))
        val resolver = HavenSystemAssistantAndroidAppActionResolver(store, completeCopy)

        assertEquals(
            HavenSystemAssistantAndroidAppActionOutcome.PENDING_REQUEST,
            resolver.submit(
                HavenSystemAssistantAndroidAppActionResolver.REVIEW_RESUME_TIMER_ACTION,
                emptyMap(),
                false,
                false,
                false,
            ),
        )
        assertEquals("existing", store.peek()?.invocationId)
        assertEquals(HavenSystemAssistantAndroidRoute.PAUSE_TIMER, store.peek()?.kind)
    }

    private data class Input(
        val action: String?,
        val extras: Map<String, Any?> = emptyMap(),
        val hasData: Boolean = false,
        val hasClipData: Boolean = false,
        val hasSelector: Boolean = false,
    )
}
