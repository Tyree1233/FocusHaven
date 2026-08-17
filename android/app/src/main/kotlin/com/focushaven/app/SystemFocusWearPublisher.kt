package com.focushaven.app

import android.content.Context
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/** Publishes state changes once; the watch advances a running deadline locally. */
internal object SystemFocusWearPublisher {
    const val SNAPSHOT_PATH = "/focus_haven/system_focus/snapshot/v1"

    fun publish(
        context: Context,
        snapshot: Map<String, Any?>,
    ) {
        val payload = SystemFocusWearPayload.fromSnapshot(snapshot) ?: return
        val request = PutDataMapRequest.create(SNAPSHOT_PATH)
        val data = request.dataMap
        data.putInt("schemaVersion", SystemFocusWearPayload.SCHEMA_VERSION)
        data.putString("session", payload.session)
        data.putString("activity", payload.activity)
        data.putInt("secondsRemaining", payload.secondsRemaining)
        data.putInt("totalSessionSeconds", payload.totalSessionSeconds)
        data.putLong("generatedAtMilliseconds", payload.generatedAtMilliseconds)
        data.putLong("endsAtMilliseconds", payload.endsAtMilliseconds)
        Wearable.getDataClient(context)
            .putDataItem(request.asPutDataRequest().setUrgent())
            .addOnFailureListener {
                // A phone without Play services or a connected watch remains fully usable.
            }
    }
}
