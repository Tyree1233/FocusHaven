package com.focushaven.app.wear

import android.content.Context
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.Wearable

/** Sends one command to the nearest connected phone; receipts return separately. */
internal class SystemFocusWearCommandSender(context: Context) {
    private val nodeClient = Wearable.getNodeClient(context)
    private val messageClient = Wearable.getMessageClient(context)

    fun send(
        command: SystemFocusWearCommand,
        onResult: (Boolean) -> Unit,
    ) {
        nodeClient.connectedNodes
            .addOnSuccessListener { nodes ->
                val target =
                    nodes.sortedWith(
                        compareByDescending<com.google.android.gms.wearable.Node> { it.isNearby }
                            .thenBy { it.id },
                    ).firstOrNull()
                if (target == null) {
                    onResult(false)
                    return@addOnSuccessListener
                }
                val data = DataMap()
                data.putInt("schemaVersion", SystemFocusWearCommand.SCHEMA_VERSION)
                data.putString("requestId", command.requestId)
                data.putString("action", command.action.wireName)
                data.putString("snapshotToken", command.snapshotToken)
                messageClient.sendMessage(target.id, COMMAND_PATH, data.toByteArray())
                    .addOnSuccessListener { onResult(true) }
                    .addOnFailureListener { onResult(false) }
            }
            .addOnFailureListener { onResult(false) }
    }

    companion object {
        const val COMMAND_PATH = "/focus_haven/system_focus/command/v1"
        const val ACKNOWLEDGEMENT_PATH = "/focus_haven/system_focus/ack/v1"
    }
}
