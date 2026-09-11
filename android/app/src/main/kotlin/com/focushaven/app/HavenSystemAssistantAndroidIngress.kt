package com.focushaven.app

import java.util.UUID

/** The complete Android-side mirror of the Phase 217A text-free route allowlist. */
internal enum class HavenSystemAssistantAndroidRoute(
    val wireName: String,
) {
    READ_TIMER_STATUS("readTimerStatus"),
    START_FOCUS_TIMER("startFocusTimer"),
    PAUSE_TIMER("pauseTimer"),
    RESUME_TIMER("resumeTimer"),
    OPEN_FOCUS_QUEUE("openFocusQueue"),
}

/** One exact Android request that may cross into the Flutter review host. */
internal class HavenSystemAssistantAndroidRequest private constructor(
    val invocationId: String,
    val kind: HavenSystemAssistantAndroidRoute,
) {
    val payload: Map<String, Any>
        get() =
            mapOf(
                "schemaVersion" to SCHEMA_VERSION,
                "invocationId" to invocationId,
                "kind" to kind.wireName,
            )

    companion object {
        const val SCHEMA_VERSION = 1
        const val MAXIMUM_INVOCATION_ID_LENGTH = 128
        private val invocationIdPattern = Regex("^[A-Za-z0-9][A-Za-z0-9._-]*$")

        fun create(
            invocationId: String,
            kind: HavenSystemAssistantAndroidRoute,
        ): HavenSystemAssistantAndroidRequest? {
            if (invocationId.isEmpty() ||
                invocationId.length > MAXIMUM_INVOCATION_ID_LENGTH ||
                !invocationIdPattern.matches(invocationId)
            ) {
                return null
            }
            return HavenSystemAssistantAndroidRequest(invocationId, kind)
        }
    }
}

/**
 * Single-slot, process-memory-only handoff for a future reviewed Android App Action.
 *
 * This store writes no preferences, file, database, cloud value, transcript, or
 * utterance. It rejects a second request and clears the first only after Flutter
 * acknowledges that exact invocation ID.
 */
internal class HavenSystemAssistantAndroidPendingRequestStore {
    private var pendingRequest: HavenSystemAssistantAndroidRequest? = null

    @Synchronized
    fun hasPendingRequest(): Boolean = pendingRequest != null

    @Synchronized
    fun submit(
        kind: HavenSystemAssistantAndroidRoute,
        invocationId: String = UUID.randomUUID().toString(),
    ): Boolean {
        if (pendingRequest != null) return false
        val request = HavenSystemAssistantAndroidRequest.create(invocationId, kind) ?: return false
        pendingRequest = request
        return true
    }

    @Synchronized
    fun peek(): HavenSystemAssistantAndroidRequest? = pendingRequest

    @Synchronized
    fun clearIfMatches(invocationId: String): Boolean {
        if (pendingRequest?.invocationId != invocationId) return false
        pendingRequest = null
        return true
    }

    companion object {
        val shared = HavenSystemAssistantAndroidPendingRequestStore()
    }
}
