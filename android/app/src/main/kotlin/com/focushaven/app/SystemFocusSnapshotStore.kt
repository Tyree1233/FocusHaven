package com.focushaven.app

import android.content.Context
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import kotlin.math.abs

internal object SystemFocusSnapshotStore {
    const val CHANNEL_NAME = "com.focushaven/system_focus"
    const val PUBLISH_METHOD = "publishSnapshot"

    private const val PREFERENCES_NAME = "focus_haven_system_focus"
    private const val SNAPSHOT_KEY = "snapshot_v1"
    private const val SCHEMA_VERSION = 1
    private const val MAXIMUM_SESSION_SECONDS = 24 * 60 * 60
    private val expectedKeys =
        setOf(
            "schemaVersion",
            "session",
            "activity",
            "secondsRemaining",
            "totalSessionSeconds",
            "generatedAt",
            "endsAt",
        )
    private val supportedSessions = setOf("focus", "shortBreak", "longBreak")
    private val supportedActivities =
        setOf("ready", "running", "paused", "completed", "pendingResume")

    fun validate(value: Any?): Map<String, Any?>? {
        val source = value as? Map<*, *> ?: return null
        if (source.keys != expectedKeys) return null

        val schemaVersion = source["schemaVersion"] as? Int ?: return null
        val session = source["session"] as? String ?: return null
        val activity = source["activity"] as? String ?: return null
        val secondsRemaining = source["secondsRemaining"] as? Int ?: return null
        val totalSessionSeconds = source["totalSessionSeconds"] as? Int ?: return null
        val generatedAtValue = source["generatedAt"] as? String ?: return null
        if (schemaVersion != SCHEMA_VERSION ||
            session !in supportedSessions ||
            activity !in supportedActivities ||
            totalSessionSeconds !in 1..MAXIMUM_SESSION_SECONDS ||
            secondsRemaining !in 0..totalSessionSeconds
        ) {
            return null
        }
        if ((activity == "completed") != (secondsRemaining == 0)) return null

        val generatedAt = parseInstant(generatedAtValue) ?: return null
        val endsAtValue = source["endsAt"]
        if (activity == "running") {
            val endsAtText = endsAtValue as? String ?: return null
            val endsAt = parseInstant(endsAtText) ?: return null
            if (!endsAt.isAfter(generatedAt)) return null
            val deadlineSeconds = Duration.between(generatedAt, endsAt).seconds
            if (abs(deadlineSeconds - secondsRemaining) > 1) return null
        } else if (endsAtValue != null) {
            return null
        }

        return expectedKeys.associateWith { key -> source[key] }
    }

    fun save(
        context: Context,
        snapshot: Map<String, Any?>,
    ) {
        val encoded = JSONObject()
        for ((key, value) in snapshot) {
            encoded.put(key, value ?: JSONObject.NULL)
        }
        context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(SNAPSHOT_KEY, encoded.toString())
            .apply()
        FocusHavenWidgetProvider.refresh(context)
        SystemFocusWearPublisher.publish(context, snapshot)
    }

    fun load(context: Context): Map<String, Any?>? {
        val encoded =
            context
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(SNAPSHOT_KEY, null) ?: return null
        return try {
            val json = JSONObject(encoded)
            val decoded =
                expectedKeys.associateWith { key ->
                    if (!json.has(key) || json.isNull(key)) null else json.get(key)
                }
            validate(decoded)
        } catch (_: Exception) {
            null
        }
    }

    private fun parseInstant(value: String): Instant? =
        try {
            Instant.parse(value)
        } catch (_: Exception) {
            null
        }
}
