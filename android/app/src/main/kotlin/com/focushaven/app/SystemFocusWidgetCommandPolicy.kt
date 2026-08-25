package com.focushaven.app

import java.time.Instant

/** Pure native checks performed before a widget command may enter the inbox. */
internal object SystemFocusWidgetCommandPolicy {
    const val MAXIMUM_PENDING_AGE_MILLIS = 2 * 60 * 1000L
    private const val SCHEMA_VERSION = 1
    private val expectedKeys =
        setOf("schemaVersion", "requestId", "action", "snapshotGeneratedAt")
    private val requestIdPattern = Regex("^[A-Za-z0-9_-]{8,64}$")
    private val supportedActions =
        setOf("start", "pause", "resume", "reset", "beginNextSession", "discardPending")

    fun isAllowed(
        snapshot: Map<String, Any?>,
        actionName: String?,
        snapshotGeneratedAt: String?,
    ): Boolean {
        if (snapshot["generatedAt"] != snapshotGeneratedAt ||
            parseInstant(snapshotGeneratedAt) == null
        ) {
            return false
        }
        val activity = snapshot["activity"] as? String ?: return false
        return actionName in allowedActions(activity)
    }

    fun validateEnvelope(value: Map<String, Any?>): Map<String, Any?>? {
        if (value.keys != expectedKeys || value["schemaVersion"] != SCHEMA_VERSION) {
            return null
        }
        val requestId = value["requestId"] as? String ?: return null
        val action = value["action"] as? String ?: return null
        val generatedAt = value["snapshotGeneratedAt"] as? String ?: return null
        if (!requestIdPattern.matches(requestId) ||
            action !in supportedActions ||
            parseInstant(generatedAt) == null
        ) {
            return null
        }
        return expectedKeys.associateWith(value::get)
    }

    fun pendingIntentIdentity(
        actionName: String?,
        snapshotGeneratedAt: String?,
    ): String? {
        if (actionName !in supportedActions) return null
        val generatedAt = parseInstant(snapshotGeneratedAt) ?: return null
        return "focushaven://system-focus-command/" +
            "$actionName/${generatedAt.toEpochMilli()}"
    }

    fun notificationPendingIntentIdentity(
        actionName: String?,
        snapshotGeneratedAt: String?,
    ): String? {
        if (actionName !in supportedActions) return null
        val generatedAt = parseInstant(snapshotGeneratedAt) ?: return null
        return "focushaven://system-focus-notification-command/" +
            "$actionName/${generatedAt.toEpochMilli()}"
    }

    fun isFreshPendingCommand(
        createdAtEpochMillis: Long,
        nowEpochMillis: Long,
    ): Boolean {
        val age = nowEpochMillis - createdAtEpochMillis
        return age in 0..MAXIMUM_PENDING_AGE_MILLIS
    }

    private fun allowedActions(activity: String): Set<String> =
        when (activity) {
            "ready" -> setOf("start")
            "running" -> setOf("pause", "reset")
            "paused" -> setOf("resume", "reset")
            "completed" -> setOf("beginNextSession")
            "pendingResume" -> setOf("resume", "discardPending")
            else -> emptySet()
        }

    private fun parseInstant(value: String?): Instant? =
        try {
            value?.let(Instant::parse)
        } catch (_: Exception) {
            null
        }
}
