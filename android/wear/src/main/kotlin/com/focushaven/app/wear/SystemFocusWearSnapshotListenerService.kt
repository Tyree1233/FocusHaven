package com.focushaven.app.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService

/** Receives the tiny timer snapshot even when the Watch activity is not alive. */
class SystemFocusWearSnapshotListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val store = SystemFocusWearSnapshotStore(this)
        var latest = store.read()
        for (event in dataEvents) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val candidate = SystemFocusWearSnapshotData.from(event.dataItem) ?: continue
            if (latest == null || candidate.generatedAt >= latest.generatedAt) latest = candidate
        }
        val accepted = latest ?: return
        if (store.save(accepted)) SystemFocusWearSurfaceUpdater.request(this)
    }
}
