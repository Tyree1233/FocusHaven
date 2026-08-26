package com.focushaven.app.wear

import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem

/** Single decoder and path boundary shared by every Wear OS focus surface. */
internal object SystemFocusWearSnapshotData {
    const val PATH = "/focus_haven/system_focus/snapshot/v2"

    fun from(item: DataItem): SystemFocusWearSnapshot? {
        if (item.uri.path != PATH) return null
        return try {
            val data = DataMapItem.fromDataItem(item).dataMap
            if (data.keySet() != SystemFocusWearSnapshot.WIRE_KEYS) return null
            SystemFocusWearSnapshot.fromWireMap(
                data.keySet().associateWith { key -> data.get(key) },
            )
        } catch (_: Exception) {
            null
        }
    }
}
