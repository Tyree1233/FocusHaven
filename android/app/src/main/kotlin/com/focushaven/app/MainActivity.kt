package com.focushaven.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var systemFocusChannel: MethodChannel? = null
    private var havenWindowPlatformAdapter: HavenWindowPlatformAdapter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                SystemFocusSnapshotStore.CHANNEL_NAME,
            )
        systemFocusChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                SystemFocusSnapshotStore.PUBLISH_METHOD -> {
                    val snapshot = SystemFocusSnapshotStore.validate(call.arguments)
                    if (snapshot == null) {
                        result.error(
                            "invalid-system-focus-snapshot",
                            "The system focus snapshot was rejected.",
                            null,
                        )
                    } else {
                        SystemFocusSnapshotStore.save(applicationContext, snapshot)
                        result.success(null)
                    }
                }
                SystemFocusPendingCommandStore.TAKE_METHOD ->
                    result.success(SystemFocusPendingCommandStore.take(applicationContext))
                else -> result.notImplemented()
            }
        }
        havenWindowPlatformAdapter =
            HavenWindowPlatformAdapter(this).also { adapter ->
                adapter.install(flutterEngine.dartExecutor.binaryMessenger)
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverWarmPendingCommand()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        havenWindowPlatformAdapter?.dispose()
        havenWindowPlatformAdapter = null
        systemFocusChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        havenWindowPlatformAdapter?.onRequestPermissionsResult(requestCode)
    }

    private fun deliverWarmPendingCommand() {
        val command = SystemFocusPendingCommandStore.peek(applicationContext) ?: return
        val requestId = command["requestId"] as? String ?: return
        systemFocusChannel?.invokeMethod(
            SystemFocusPendingCommandStore.EXECUTE_METHOD,
            command,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (result is Boolean) {
                        SystemFocusPendingCommandStore.clearIfMatches(
                            applicationContext,
                            requestId,
                        )
                    }
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) = Unit

                override fun notImplemented() = Unit
            },
        )
    }
}
