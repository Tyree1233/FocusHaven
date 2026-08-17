package com.focushaven.app

import java.time.Duration
import java.time.Instant
import kotlin.math.abs

/** The only phone payload permitted to cross the private Wear OS Data Layer. */
internal data class SystemFocusWearPayload(
    val session: String,
    val activity: String,
    val secondsRemaining: Int,
    val totalSessionSeconds: Int,
    val generatedAtMilliseconds: Long,
    val endsAtMilliseconds: Long,
) {
    val wireMap: Map<String, Any>
        get() =
            mapOf(
                "schemaVersion" to SCHEMA_VERSION,
                "session" to session,
                "activity" to activity,
                "secondsRemaining" to secondsRemaining,
                "totalSessionSeconds" to totalSessionSeconds,
                "generatedAtMilliseconds" to generatedAtMilliseconds,
                "endsAtMilliseconds" to endsAtMilliseconds,
            )

    companion object {
        const val SCHEMA_VERSION = 1
        const val MAXIMUM_SESSION_SECONDS = 24 * 60 * 60
        val APPLICATION_KEYS =
            setOf(
                "schemaVersion",
                "session",
                "activity",
                "secondsRemaining",
                "totalSessionSeconds",
                "generatedAt",
                "endsAt",
            )
        val WIRE_KEYS =
            setOf(
                "schemaVersion",
                "session",
                "activity",
                "secondsRemaining",
                "totalSessionSeconds",
                "generatedAtMilliseconds",
                "endsAtMilliseconds",
            )
        private val supportedSessions = setOf("focus", "shortBreak", "longBreak")
        private val supportedActivities =
            setOf("ready", "running", "paused", "completed", "pendingResume")

        fun fromSnapshot(snapshot: Map<String, Any?>?): SystemFocusWearPayload? {
            if (snapshot == null || snapshot.keys != APPLICATION_KEYS) return null
            val schemaVersion = snapshot["schemaVersion"] as? Int ?: return null
            val session = snapshot["session"] as? String ?: return null
            val activity = snapshot["activity"] as? String ?: return null
            val secondsRemaining = snapshot["secondsRemaining"] as? Int ?: return null
            val totalSessionSeconds = snapshot["totalSessionSeconds"] as? Int ?: return null
            val generatedAt = parseInstant(snapshot["generatedAt"] as? String) ?: return null
            if (schemaVersion != SCHEMA_VERSION ||
                session !in supportedSessions ||
                activity !in supportedActivities ||
                totalSessionSeconds !in 1..MAXIMUM_SESSION_SECONDS ||
                secondsRemaining !in 0..totalSessionSeconds ||
                (activity == "completed") != (secondsRemaining == 0)
            ) {
                return null
            }

            val endsAtMilliseconds =
                if (activity == "running") {
                    val endsAt = parseInstant(snapshot["endsAt"] as? String) ?: return null
                    if (!endsAt.isAfter(generatedAt)) return null
                    val deadlineSeconds = Duration.between(generatedAt, endsAt).seconds
                    if (abs(deadlineSeconds - secondsRemaining) > 1) return null
                    endsAt.toEpochMilli()
                } else {
                    if (snapshot["endsAt"] != null) return null
                    0L
                }
            return SystemFocusWearPayload(
                session = session,
                activity = activity,
                secondsRemaining = secondsRemaining,
                totalSessionSeconds = totalSessionSeconds,
                generatedAtMilliseconds = generatedAt.toEpochMilli(),
                endsAtMilliseconds = endsAtMilliseconds,
            )
        }

        private fun parseInstant(value: String?): Instant? =
            try {
                value?.let(Instant::parse)
            } catch (_: Exception) {
                null
            }
    }
}
