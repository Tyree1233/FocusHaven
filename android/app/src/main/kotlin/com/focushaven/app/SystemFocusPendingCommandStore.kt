package com.focushaven.app

import android.content.Context
import android.util.Base64
import org.json.JSONObject
import java.security.SecureRandom

/** One app-private, text-free command waiting for Flutter authorization. */
internal object SystemFocusPendingCommandStore {
    const val TAKE_METHOD = "takePendingCommand"
    const val EXECUTE_METHOD = "executeCommand"

    private const val PREFERENCES_NAME = "focus_haven_system_focus_commands"
    private const val COMMAND_KEY = "pending_command_v1"
    private const val CREATED_AT_KEY = "pending_command_created_at_v1"
    private val secureRandom = SecureRandom()

    @Synchronized
    fun enqueue(
        context: Context,
        actionName: String?,
        snapshotGeneratedAt: String?,
        requestId: String? = null,
    ): Boolean {
        val snapshot = SystemFocusSnapshotStore.load(context) ?: return false
        if (!SystemFocusWidgetCommandPolicy.isAllowed(
                snapshot,
                actionName,
                snapshotGeneratedAt,
            )
        ) {
            return false
        }
        val candidate =
            mapOf(
                "schemaVersion" to 1,
                "requestId" to (requestId ?: createRequestId()),
                "action" to actionName,
                "snapshotGeneratedAt" to snapshotGeneratedAt,
            )
        val command = SystemFocusWidgetCommandPolicy.validateEnvelope(candidate) ?: return false
        val encoded = JSONObject(command).toString()
        return context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(COMMAND_KEY, encoded)
            .putLong(CREATED_AT_KEY, System.currentTimeMillis())
            .commit()
    }

    @Synchronized
    fun take(context: Context): Map<String, Any?>? {
        val command = peek(context) ?: return null
        val removed =
            context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(COMMAND_KEY)
            .remove(CREATED_AT_KEY)
            .commit()
        return if (removed) command else null
    }

    @Synchronized
    fun peek(context: Context): Map<String, Any?>? {
        val preferences =
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val encoded = preferences.getString(COMMAND_KEY, null) ?: return null
        val createdAt = preferences.getLong(CREATED_AT_KEY, -1)
        val command = decode(encoded)
        if (command != null &&
            SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
                createdAt,
                System.currentTimeMillis(),
            )
        ) {
            return command
        }
        preferences.edit().remove(COMMAND_KEY).remove(CREATED_AT_KEY).commit()
        return null
    }

    @Synchronized
    fun clearIfMatches(
        context: Context,
        requestId: String,
    ) {
        val current = peek(context) ?: return
        if (current["requestId"] != requestId) return
        context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(COMMAND_KEY)
            .remove(CREATED_AT_KEY)
            .commit()
    }

    private fun decode(encoded: String): Map<String, Any?>? =
        try {
            val json = JSONObject(encoded)
            val decoded = mutableMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                decoded[key] = json.get(key)
            }
            SystemFocusWidgetCommandPolicy.validateEnvelope(decoded)
        } catch (_: Exception) {
            null
        }

    private fun createRequestId(): String {
        val bytes = ByteArray(18)
        secureRandom.nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

}
