package com.focushaven.app.wear

import java.time.Duration
import java.time.Instant
import kotlin.math.abs
import kotlin.math.ceil

internal enum class SystemFocusWearSession {
    FOCUS,
    SHORT_BREAK,
    LONG_BREAK,
}

internal enum class SystemFocusWearActivity {
    READY,
    RUNNING,
    PAUSED,
    COMPLETED,
    PENDING_RESUME,
}

internal data class SystemFocusWearPresentation(
    val session: SystemFocusWearSession,
    val activity: SystemFocusWearActivity,
    val secondsRemaining: Int,
    val totalSessionSeconds: Int,
) {
    val completedSeconds: Int
        get() = (totalSessionSeconds - secondsRemaining).coerceIn(0, totalSessionSeconds)
}

/** Exact, text-free timer state accepted by the Wear OS surface. */
internal data class SystemFocusWearSnapshot(
    val session: SystemFocusWearSession,
    val activity: SystemFocusWearActivity,
    val secondsRemaining: Int,
    val totalSessionSeconds: Int,
    val generatedAt: Instant,
    val endsAt: Instant?,
    val snapshotToken: String,
) {
    val availableActions: Set<SystemFocusWearAction>
        get() =
            when (activity) {
                SystemFocusWearActivity.READY -> setOf(SystemFocusWearAction.START)
                SystemFocusWearActivity.RUNNING ->
                    setOf(SystemFocusWearAction.PAUSE, SystemFocusWearAction.RESET)
                SystemFocusWearActivity.PAUSED ->
                    setOf(SystemFocusWearAction.RESUME, SystemFocusWearAction.RESET)
                SystemFocusWearActivity.COMPLETED ->
                    setOf(SystemFocusWearAction.BEGIN_NEXT_SESSION)
                SystemFocusWearActivity.PENDING_RESUME ->
                    setOf(SystemFocusWearAction.RESUME, SystemFocusWearAction.DISCARD_PENDING)
            }

    fun presentation(now: Instant = Instant.now()): SystemFocusWearPresentation {
        if (activity != SystemFocusWearActivity.RUNNING || endsAt == null) {
            return SystemFocusWearPresentation(
                session,
                activity,
                secondsRemaining,
                totalSessionSeconds,
            )
        }
        val remainingMillis = Duration.between(now, endsAt).toMillis()
        if (remainingMillis <= 0) {
            return SystemFocusWearPresentation(
                session,
                SystemFocusWearActivity.COMPLETED,
                0,
                totalSessionSeconds,
            )
        }
        return SystemFocusWearPresentation(
            session,
            activity,
            ceil(remainingMillis / 1_000.0).toInt().coerceIn(1, totalSessionSeconds),
            totalSessionSeconds,
        )
    }

    companion object {
        const val SCHEMA_VERSION = 2
        const val MAXIMUM_SESSION_SECONDS = 24 * 60 * 60
        val WIRE_KEYS =
            setOf(
                "schemaVersion",
                "session",
                "activity",
                "secondsRemaining",
                "totalSessionSeconds",
                "generatedAtMilliseconds",
                "endsAtMilliseconds",
                "snapshotToken",
            )
        private val snapshotTokenPattern = Regex("^[a-f0-9]{64}$")

        fun fromWireMap(value: Map<String, Any?>?): SystemFocusWearSnapshot? {
            if (value == null || value.keys != WIRE_KEYS) return null
            val schemaVersion = value["schemaVersion"] as? Int ?: return null
            val session =
                when (value["session"]) {
                    "focus" -> SystemFocusWearSession.FOCUS
                    "shortBreak" -> SystemFocusWearSession.SHORT_BREAK
                    "longBreak" -> SystemFocusWearSession.LONG_BREAK
                    else -> return null
                }
            val activity =
                when (value["activity"]) {
                    "ready" -> SystemFocusWearActivity.READY
                    "running" -> SystemFocusWearActivity.RUNNING
                    "paused" -> SystemFocusWearActivity.PAUSED
                    "completed" -> SystemFocusWearActivity.COMPLETED
                    "pendingResume" -> SystemFocusWearActivity.PENDING_RESUME
                    else -> return null
                }
            val secondsRemaining = value["secondsRemaining"] as? Int ?: return null
            val totalSessionSeconds = value["totalSessionSeconds"] as? Int ?: return null
            val generatedAtMilliseconds = value["generatedAtMilliseconds"] as? Long ?: return null
            val endsAtMilliseconds = value["endsAtMilliseconds"] as? Long ?: return null
            val snapshotToken = value["snapshotToken"] as? String ?: return null
            if (schemaVersion != SCHEMA_VERSION ||
                totalSessionSeconds !in 1..MAXIMUM_SESSION_SECONDS ||
                secondsRemaining !in 0..totalSessionSeconds ||
                generatedAtMilliseconds <= 0L ||
                endsAtMilliseconds < 0L ||
                !snapshotTokenPattern.matches(snapshotToken) ||
                (activity == SystemFocusWearActivity.COMPLETED) != (secondsRemaining == 0)
            ) {
                return null
            }

            val generatedAt = Instant.ofEpochMilli(generatedAtMilliseconds)
            val endsAt =
                if (activity == SystemFocusWearActivity.RUNNING) {
                    if (endsAtMilliseconds == 0L) return null
                    Instant.ofEpochMilli(endsAtMilliseconds)
                } else {
                    if (endsAtMilliseconds != 0L) return null
                    null
                }
            if (endsAt != null) {
                if (!endsAt.isAfter(generatedAt)) return null
                val deadlineSeconds = Duration.between(generatedAt, endsAt).seconds
                if (abs(deadlineSeconds - secondsRemaining) > 1) return null
            }
            return SystemFocusWearSnapshot(
                session,
                activity,
                secondsRemaining,
                totalSessionSeconds,
                generatedAt,
                endsAt,
                snapshotToken,
            )
        }
    }
}
