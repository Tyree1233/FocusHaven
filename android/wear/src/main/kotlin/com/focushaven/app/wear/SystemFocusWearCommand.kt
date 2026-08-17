package com.focushaven.app.wear

import java.util.UUID

internal enum class SystemFocusWearAction(val wireName: String) {
    START("start"),
    PAUSE("pause"),
    RESUME("resume"),
    RESET("reset"),
    BEGIN_NEXT_SESSION("beginNextSession"),
    DISCARD_PENDING("discardPending"),
}

/** One bounded command tied to the exact phone-authored snapshot token. */
internal data class SystemFocusWearCommand(
    val requestId: String,
    val action: SystemFocusWearAction,
    val snapshotToken: String,
) {
    val wireMap: Map<String, Any>
        get() =
            mapOf(
                "schemaVersion" to SCHEMA_VERSION,
                "requestId" to requestId,
                "action" to action.wireName,
                "snapshotToken" to snapshotToken,
            )

    companion object {
        const val SCHEMA_VERSION = 1
        val WIRE_KEYS = setOf("schemaVersion", "requestId", "action", "snapshotToken")
        private val requestIdPattern = Regex("^[A-Za-z0-9_-]{8,64}$")
        private val snapshotTokenPattern = Regex("^[a-f0-9]{64}$")

        fun create(
            snapshot: SystemFocusWearSnapshot,
            action: SystemFocusWearAction,
            requestId: String = UUID.randomUUID().toString().replace("-", ""),
        ): SystemFocusWearCommand? {
            if (action !in snapshot.availableActions ||
                !requestIdPattern.matches(requestId) ||
                !snapshotTokenPattern.matches(snapshot.snapshotToken)
            ) {
                return null
            }
            return SystemFocusWearCommand(requestId, action, snapshot.snapshotToken)
        }
    }
}

internal data class SystemFocusWearAcknowledgement(
    val requestId: String,
    val accepted: Boolean,
) {
    companion object {
        val WIRE_KEYS = setOf("schemaVersion", "requestId", "accepted")
        private val requestIdPattern = Regex("^[A-Za-z0-9_-]{8,64}$")

        fun fromWireMap(value: Map<String, Any?>?): SystemFocusWearAcknowledgement? {
            if (value == null || value.keys != WIRE_KEYS) return null
            val schemaVersion = value["schemaVersion"] as? Int ?: return null
            val requestId = value["requestId"] as? String ?: return null
            val accepted = value["accepted"] as? Boolean ?: return null
            if (schemaVersion != SystemFocusWearCommand.SCHEMA_VERSION ||
                !requestIdPattern.matches(requestId)
            ) {
                return null
            }
            return SystemFocusWearAcknowledgement(requestId, accepted)
        }
    }
}
