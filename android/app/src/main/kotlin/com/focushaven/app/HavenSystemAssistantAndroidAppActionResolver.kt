package com.focushaven.app

import java.util.UUID

/** The only outcomes Android Assistant fulfillment may produce before app review. */
internal enum class HavenSystemAssistantAndroidAppActionOutcome {
    READY_FOR_REVIEW,
    PENDING_REQUEST,
    UNAVAILABLE,
}

/**
 * A method-local snapshot of caller input, captured before plugin attachment.
 *
 * Plugins may augment the Activity's Intent during Flutter startup. Copy the
 * original nullable string values rather than retaining an Intent, Bundle, or
 * caller-owned map. No extra is removed or allowlisted here: the unchanged
 * resolver must still validate every original key and value.
 */
internal class HavenSystemAssistantAndroidAppActionInput private constructor(
    private val action: String?,
    private val extras: Map<String, String?>,
    private val hasData: Boolean,
    private val hasClipData: Boolean,
    private val hasSelector: Boolean,
) {
    fun submitTo(
        resolver: HavenSystemAssistantAndroidAppActionResolver,
    ): HavenSystemAssistantAndroidAppActionOutcome =
        resolver.submit(action, extras, hasData, hasClipData, hasSelector)

    companion object {
        fun capture(
            action: String?,
            extras: Map<String, String?>,
            hasData: Boolean,
            hasClipData: Boolean,
            hasSelector: Boolean,
        ): HavenSystemAssistantAndroidAppActionInput? =
            if (HavenSystemAssistantAndroidAppActionResolver.handlesAction(action)) {
                HavenSystemAssistantAndroidAppActionInput(
                    action,
                    extras.toMap(),
                    hasData,
                    hasClipData,
                    hasSelector,
                )
            } else {
                null
            }
    }
}

/**
 * Fail-closed fulfillment for the exact Phase 217J Android App Actions mapping.
 *
 * The resolver admits no Assistant-authored value into the FocusHaven request.
 * The OPEN_APP_FEATURE inventory identifier is validated and discarded; all
 * other routes are parameter-free. Successful submission writes only the
 * existing process-memory request and never reads or changes timer or queue
 * state, confirms a review, or executes a Haven Action.
 */
internal class HavenSystemAssistantAndroidAppActionResolver(
    private val store: HavenSystemAssistantAndroidPendingRequestStore =
        HavenSystemAssistantAndroidPendingRequestStore.shared,
    private val copy: HavenSystemAssistantAndroidNativeCopy,
    private val invocationIdFactory: () -> String = { UUID.randomUUID().toString() },
) {
    fun handles(action: String?): Boolean = handlesAction(action)

    fun submit(
        action: String?,
        extras: Map<String, Any?>,
        hasData: Boolean,
        hasClipData: Boolean,
        hasSelector: Boolean,
    ): HavenSystemAssistantAndroidAppActionOutcome {
        val route = routeByAction[action] ?: return HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE
        if (hasData || hasClipData || hasSelector || !hasExactInputs(route, extras)) {
            return HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE
        }
        if (!hasCompleteReviewedCopy(route)) {
            return HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE
        }
        val invocationId = invocationIdFactory()
        if (HavenSystemAssistantAndroidRequest.create(invocationId, route) == null) {
            return HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE
        }
        return if (store.submit(route, invocationId)) {
            HavenSystemAssistantAndroidAppActionOutcome.READY_FOR_REVIEW
        } else {
            HavenSystemAssistantAndroidAppActionOutcome.PENDING_REQUEST
        }
    }

    private fun hasExactInputs(
        route: HavenSystemAssistantAndroidRoute,
        extras: Map<String, Any?>,
    ): Boolean =
        if (route == HavenSystemAssistantAndroidRoute.OPEN_FOCUS_QUEUE) {
            extras.size == 1 && extras[FEATURE_EXTRA] == FOCUS_QUEUE_REVIEW_ID
        } else {
            extras.isEmpty()
        }

    private fun hasCompleteReviewedCopy(route: HavenSystemAssistantAndroidRoute): Boolean {
        val routeCopy = route.nativeCopyKeys
        return listOf(
            routeCopy.shortLabel,
            routeCopy.longLabel,
            routeCopy.invocationExample,
            HavenSystemAssistantAndroidNativeCopyKey.REVIEW_REQUIRED_RESULT,
            HavenSystemAssistantAndroidNativeCopyKey.PENDING_REQUEST_RESULT,
            HavenSystemAssistantAndroidNativeCopyKey.UNAVAILABLE_RESULT,
        ).all { copy.text(it) != null }
    }

    companion object {
        fun handlesAction(action: String?): Boolean = action in routeByAction

        const val REVIEW_TIMER_STATUS_ACTION =
            "com.focushaven.app.action.REVIEW_FOCUS_TIMER_STATUS"
        const val REVIEW_START_TIMER_ACTION =
            "com.focushaven.app.action.REVIEW_START_FOCUS_TIMER"
        const val REVIEW_PAUSE_TIMER_ACTION =
            "com.focushaven.app.action.REVIEW_PAUSE_FOCUS_TIMER"
        const val REVIEW_RESUME_TIMER_ACTION =
            "com.focushaven.app.action.REVIEW_RESUME_FOCUS_TIMER"
        const val REVIEW_OPEN_QUEUE_ACTION =
            "com.focushaven.app.action.REVIEW_OPEN_FOCUS_QUEUE"
        const val FEATURE_EXTRA = "feature"
        const val FOCUS_QUEUE_REVIEW_ID = "focus_queue_review"

        private val routeByAction =
            mapOf(
                REVIEW_TIMER_STATUS_ACTION to HavenSystemAssistantAndroidRoute.READ_TIMER_STATUS,
                REVIEW_START_TIMER_ACTION to HavenSystemAssistantAndroidRoute.START_FOCUS_TIMER,
                REVIEW_PAUSE_TIMER_ACTION to HavenSystemAssistantAndroidRoute.PAUSE_TIMER,
                REVIEW_RESUME_TIMER_ACTION to HavenSystemAssistantAndroidRoute.RESUME_TIMER,
                REVIEW_OPEN_QUEUE_ACTION to HavenSystemAssistantAndroidRoute.OPEN_FOCUS_QUEUE,
            )
    }
}
