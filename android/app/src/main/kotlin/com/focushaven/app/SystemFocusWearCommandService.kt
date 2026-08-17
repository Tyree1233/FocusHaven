package com.focushaven.app

import android.content.Intent
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService

/** Validates one paired-watch request before forwarding it to Flutter authorization. */
class SystemFocusWearCommandService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != COMMAND_PATH) return
        val wireMap = decode(messageEvent.data)
        val authorized =
            SystemFocusWearCommandPolicy.authorize(
                SystemFocusSnapshotStore.load(applicationContext),
                wireMap,
            )
        val accepted =
            if (authorized == null ||
                !SystemFocusWearReplayStore.claim(applicationContext, authorized.requestId)
            ) {
                false
            } else {
                SystemFocusPendingCommandStore.enqueue(
                    applicationContext,
                    authorized.action,
                    authorized.snapshotGeneratedAt,
                    authorized.requestId,
                )
            }
        val requestId = wireMap?.get("requestId") as? String
        if (requestId != null) acknowledge(messageEvent.sourceNodeId, requestId, accepted)
        if (accepted) openPhoneApp()
    }

    private fun acknowledge(
        nodeId: String,
        requestId: String,
        accepted: Boolean,
    ) {
        val acknowledgement =
            SystemFocusWearCommandPolicy.acknowledgement(requestId, accepted) ?: return
        val data = DataMap()
        data.putInt("schemaVersion", acknowledgement.getValue("schemaVersion") as Int)
        data.putString("requestId", acknowledgement.getValue("requestId") as String)
        data.putBoolean("accepted", acknowledgement.getValue("accepted") as Boolean)
        Wearable.getMessageClient(applicationContext)
            .sendMessage(nodeId, ACKNOWLEDGEMENT_PATH, data.toByteArray())
            .addOnFailureListener {
                // The command remains safely queued even if the receipt cannot return.
            }
    }

    private fun openPhoneApp() {
        try {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
            )
        } catch (_: RuntimeException) {
            // Modern Android may defer background launches. The private inbox is retained.
        }
    }

    private fun decode(bytes: ByteArray): Map<String, Any?>? =
        try {
            val data = DataMap.fromByteArray(bytes)
            data.keySet().associateWith { key -> data.get(key) }
        } catch (_: Exception) {
            null
        }

    companion object {
        const val COMMAND_PATH = "/focus_haven/system_focus/command/v1"
        const val ACKNOWLEDGEMENT_PATH = "/focus_haven/system_focus/ack/v1"
    }
}
