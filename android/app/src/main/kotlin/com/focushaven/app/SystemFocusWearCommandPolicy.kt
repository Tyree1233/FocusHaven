package com.focushaven.app

internal data class AuthorizedSystemFocusWearCommand(
    val requestId: String,
    val action: String,
    val snapshotGeneratedAt: String,
)

/** Strict text-free boundary for commands received from the paired Wear OS app. */
internal object SystemFocusWearCommandPolicy {
    const val SCHEMA_VERSION = 1
    const val MAXIMUM_REMEMBERED_REQUESTS = 64
    val WIRE_KEYS = setOf("schemaVersion", "requestId", "action", "snapshotToken")
    val ACKNOWLEDGEMENT_KEYS = setOf("schemaVersion", "requestId", "accepted")
    private val requestIdPattern = Regex("^[A-Za-z0-9_-]{8,64}$")
    private val snapshotTokenPattern = Regex("^[a-f0-9]{64}$")

    fun authorize(
        snapshot: Map<String, Any?>?,
        value: Map<String, Any?>?,
    ): AuthorizedSystemFocusWearCommand? {
        if (snapshot == null || value == null || value.keys != WIRE_KEYS) return null
        val schemaVersion = value["schemaVersion"] as? Int ?: return null
        val requestId = value["requestId"] as? String ?: return null
        val action = value["action"] as? String ?: return null
        val snapshotToken = value["snapshotToken"] as? String ?: return null
        val generatedAt = snapshot["generatedAt"] as? String ?: return null
        if (schemaVersion != SCHEMA_VERSION ||
            !requestIdPattern.matches(requestId) ||
            !snapshotTokenPattern.matches(snapshotToken) ||
            snapshotToken != SystemFocusWearPayload.snapshotTokenFor(generatedAt) ||
            !SystemFocusWidgetCommandPolicy.isAllowed(snapshot, action, generatedAt)
        ) {
            return null
        }
        return AuthorizedSystemFocusWearCommand(requestId, action, generatedAt)
    }

    fun acknowledgement(
        requestId: String,
        accepted: Boolean,
    ): Map<String, Any>? {
        if (!requestIdPattern.matches(requestId)) return null
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "requestId" to requestId,
            "accepted" to accepted,
        )
    }
}
