package com.focushaven.app

import android.content.Context

/** Bounded app-private receipt history that rejects repeated watch request IDs. */
internal object SystemFocusWearReplayStore {
    private const val PREFERENCES_NAME = "focus_haven_wear_command_receipts"
    private const val REQUEST_IDS_KEY = "request_ids_v1"

    @Synchronized
    fun claim(
        context: Context,
        requestId: String,
    ): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val remembered = preferences.getStringSet(REQUEST_IDS_KEY, emptySet()).orEmpty().toMutableSet()
        if (requestId in remembered) return false
        if (remembered.size >= SystemFocusWearCommandPolicy.MAXIMUM_REMEMBERED_REQUESTS) {
            remembered.clear()
        }
        remembered.add(requestId)
        return preferences.edit().putStringSet(REQUEST_IDS_KEY, remembered).commit()
    }
}
