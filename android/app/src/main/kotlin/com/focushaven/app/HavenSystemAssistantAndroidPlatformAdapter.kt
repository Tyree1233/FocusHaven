package com.focushaven.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Private Flutter transport for one future reviewed Android App Action request.
 *
 * Phase 217H intentionally declares no shortcuts capability or public Assistant
 * destination. This adapter can deliver only an already-bounded in-process
 * request and clears it only after Flutter acknowledges the exact three-field
 * payload. It cannot prepare, confirm, or execute a Haven Action.
 */
internal class HavenSystemAssistantAndroidPlatformAdapter(
    private val store: HavenSystemAssistantAndroidPendingRequestStore =
        HavenSystemAssistantAndroidPendingRequestStore.shared,
) {
    private var channel: MethodChannel? = null
    private var deliveryInFlight = false

    fun install(binaryMessenger: BinaryMessenger) {
        val installedChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel = installedChannel
        installedChannel.setMethodCallHandler(::handleMethodCall)
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        deliveryInFlight = false
    }

    fun deliverPendingRequest() {
        if (deliveryInFlight) return
        val activeChannel = channel ?: return
        val request = store.peek() ?: return
        deliveryInFlight = true
        activeChannel.invokeMethod(
            DELIVER_REQUEST_METHOD,
            request.payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    deliveryInFlight = false
                    if (result == true) {
                        store.clearIfMatches(request.invocationId)
                    }
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    deliveryInFlight = false
                }

                override fun notImplemented() {
                    deliveryInFlight = false
                }
            },
        )
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (call.method != REQUEST_PENDING_DELIVERY_METHOD) {
            result.notImplemented()
            return
        }
        if (!isValidDeliveryRequest(call.arguments)) {
            result.error(
                "invalid-system-assistant-android-request",
                "The Android system-assistant request was rejected.",
                null,
            )
            return
        }
        val hasPendingRequest = store.hasPendingRequest()
        result.success(hasPendingRequest)
        if (hasPendingRequest) deliverPendingRequest()
    }

    private fun isValidDeliveryRequest(value: Any?): Boolean {
        val request = value as? Map<*, *> ?: return false
        return request.size == 1 && request["schemaVersion"] == 1
    }

    companion object {
        const val CHANNEL_NAME = "com.focushaven/system_assistant_android"
        const val REQUEST_PENDING_DELIVERY_METHOD = "requestPendingDelivery"
        const val DELIVER_REQUEST_METHOD = "deliverRequest"
    }
}
