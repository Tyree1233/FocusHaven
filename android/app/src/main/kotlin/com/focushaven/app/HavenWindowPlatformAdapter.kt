package com.focushaven.app

import android.Manifest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Dedicated consent-first Flutter transport for private Android availability. */
class HavenWindowPlatformAdapter(
    private val activity: MainActivity,
    controller: HavenWindowNativeController? = null,
) {
    private val controller =
        controller ?: HavenWindowNativeController(AndroidHavenWindowCalendarReader(activity))
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    @Volatile
    private var disposed = false

    fun install(binaryMessenger: BinaryMessenger) {
        val installedChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel = installedChannel
        installedChannel.setMethodCallHandler(::handleMethodCall)
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return false
        pendingPermissionResult = null
        executeRead(result)
        return true
    }

    fun dispose() {
        disposed = true
        channel?.setMethodCallHandler(null)
        channel = null
        pendingPermissionResult = null
        executor.shutdownNow()
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!isValidRequest(call.arguments)) {
            result.error(
                "invalid-haven-window-request",
                "The Haven Window request was rejected.",
                null,
            )
            return
        }
        when (call.method) {
            READ_AVAILABILITY_METHOD -> executeRead(result)
            REQUEST_READ_ONLY_ACCESS_METHOD -> requestReadOnlyAccess(result)
            else -> result.notImplemented()
        }
    }

    private fun requestReadOnlyAccess(result: MethodChannel.Result) {
        if (!controller.canRequestAccess()) {
            executeRead(result)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "haven-window-operation-in-progress",
                "A Haven Window operation is already in progress.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        try {
            activity.requestPermissions(
                arrayOf(Manifest.permission.READ_CALENDAR),
                PERMISSION_REQUEST_CODE,
            )
            controller.markPermissionRequested()
        } catch (_: RuntimeException) {
            pendingPermissionResult = null
            result.error(
                "haven-window-access-request-failed",
                "Calendar access could not be requested.",
                null,
            )
        }
    }

    private fun executeRead(result: MethodChannel.Result) {
        if (disposed) return
        executor.execute {
            try {
                val availability = controller.readAvailability().toMap()
                activity.runOnUiThread {
                    if (!disposed) result.success(availability)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    if (!disposed) {
                        result.error(
                            "haven-window-read-failed",
                            "Private calendar availability could not be read.",
                            null,
                        )
                    }
                }
            }
        }
    }

    private fun isValidRequest(value: Any?): Boolean {
        val request = value as? Map<*, *> ?: return false
        return request.size == 1 && request["schemaVersion"] == 1
    }

    private companion object {
        const val CHANNEL_NAME = "com.focushaven/haven_window"
        const val READ_AVAILABILITY_METHOD = "readAvailability"
        const val REQUEST_READ_ONLY_ACCESS_METHOD = "requestReadOnlyAccess"
        const val PERMISSION_REQUEST_CODE = 7416
    }
}
