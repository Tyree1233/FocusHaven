package com.focushaven.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SystemFocusSnapshotStore.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            if (call.method != SystemFocusSnapshotStore.PUBLISH_METHOD) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val snapshot = SystemFocusSnapshotStore.validate(call.arguments)
            if (snapshot == null) {
                result.error(
                    "invalid-system-focus-snapshot",
                    "The system focus snapshot was rejected.",
                    null,
                )
                return@setMethodCallHandler
            }

            SystemFocusSnapshotStore.save(applicationContext, snapshot)
            result.success(null)
        }
    }
}
