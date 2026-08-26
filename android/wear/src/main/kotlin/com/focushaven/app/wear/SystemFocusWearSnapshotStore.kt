package com.focushaven.app.wear

import android.content.Context

/** Private, bounded cache that lets system surfaces render while the Watch app is not running. */
internal class SystemFocusWearSnapshotStore(context: Context) {
    private val preferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun read(): SystemFocusWearSnapshot? {
        if (!STORED_KEYS.all(preferences::contains)) return null
        return SystemFocusWearSnapshot.fromWireMap(
            mapOf(
                "schemaVersion" to preferences.getInt("schemaVersion", 0),
                "session" to preferences.getString("session", null),
                "activity" to preferences.getString("activity", null),
                "secondsRemaining" to preferences.getInt("secondsRemaining", -1),
                "totalSessionSeconds" to preferences.getInt("totalSessionSeconds", -1),
                "generatedAtMilliseconds" to
                    preferences.getLong("generatedAtMilliseconds", 0L),
                "endsAtMilliseconds" to preferences.getLong("endsAtMilliseconds", -1L),
                "snapshotToken" to preferences.getString("snapshotToken", null),
            ),
        )
    }

    fun save(snapshot: SystemFocusWearSnapshot): Boolean {
        val existing = read()
        if (existing != null && snapshot.generatedAt <= existing.generatedAt) return false
        return preferences.edit()
            .putInt("schemaVersion", SystemFocusWearSnapshot.SCHEMA_VERSION)
            .putString("session", snapshot.session.wireValue)
            .putString("activity", snapshot.activity.wireValue)
            .putInt("secondsRemaining", snapshot.secondsRemaining)
            .putInt("totalSessionSeconds", snapshot.totalSessionSeconds)
            .putLong("generatedAtMilliseconds", snapshot.generatedAt.toEpochMilli())
            .putLong("endsAtMilliseconds", snapshot.endsAt?.toEpochMilli() ?: 0L)
            .putString("snapshotToken", snapshot.snapshotToken)
            .commit()
    }

    private val SystemFocusWearSession.wireValue: String
        get() =
            when (this) {
                SystemFocusWearSession.FOCUS -> "focus"
                SystemFocusWearSession.SHORT_BREAK -> "shortBreak"
                SystemFocusWearSession.LONG_BREAK -> "longBreak"
            }

    private val SystemFocusWearActivity.wireValue: String
        get() =
            when (this) {
                SystemFocusWearActivity.READY -> "ready"
                SystemFocusWearActivity.RUNNING -> "running"
                SystemFocusWearActivity.PAUSED -> "paused"
                SystemFocusWearActivity.COMPLETED -> "completed"
                SystemFocusWearActivity.PENDING_RESUME -> "pendingResume"
            }

    private companion object {
        const val PREFERENCES_NAME = "focus_haven_wear_snapshot_v2"
        val STORED_KEYS = SystemFocusWearSnapshot.WIRE_KEYS
    }
}
