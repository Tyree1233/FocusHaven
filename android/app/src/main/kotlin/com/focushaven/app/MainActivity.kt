package com.focushaven.app

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var systemFocusChannel: MethodChannel? = null
    private var havenWindowPlatformAdapter: HavenWindowPlatformAdapter? = null
    private var systemAssistantAndroidPlatformAdapter:
        HavenSystemAssistantAndroidPlatformAdapter? = null
    private val systemAssistantAndroidAppActionResolver by lazy {
        HavenSystemAssistantAndroidAppActionResolver(
            copy = HavenSystemAssistantAndroidNativeCopy.from(resources),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val assistantInput = captureSystemAssistantAndroidAppAction(intent)
        super.onCreate(savedInstanceState)
        resolveSystemAssistantAndroidAppAction(assistantInput)
    }

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
        systemAssistantAndroidPlatformAdapter =
            HavenSystemAssistantAndroidPlatformAdapter().also { adapter ->
                adapter.install(flutterEngine.dartExecutor.binaryMessenger)
            }
    }

    override fun onNewIntent(intent: Intent) {
        val assistantInput = captureSystemAssistantAndroidAppAction(intent)
        super.onNewIntent(intent)
        setIntent(intent)
        deliverWarmPendingCommand()
        resolveSystemAssistantAndroidAppAction(assistantInput)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        havenWindowPlatformAdapter?.dispose()
        havenWindowPlatformAdapter = null
        systemAssistantAndroidPlatformAdapter?.dispose()
        systemAssistantAndroidPlatformAdapter = null
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
                    if (SystemFocusPendingCommandStore.shouldClearAfterAcknowledgement(
                            result,
                        )
                    ) {
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

    private fun captureSystemAssistantAndroidAppAction(
        intent: Intent,
    ): HavenSystemAssistantAndroidAppActionInput? {
        val action = intent.action
        if (!HavenSystemAssistantAndroidAppActionResolver.handlesAction(action)) return null
        val extras =
            intent.extras
                ?.keySet()
                ?.associateWith { key -> intent.getStringExtra(key) }
                .orEmpty()
        return HavenSystemAssistantAndroidAppActionInput.capture(
            action = action,
            extras = extras,
            hasData = intent.data != null,
            hasClipData = intent.clipData != null,
            hasSelector = intent.selector != null,
        )
    }

    private fun resolveSystemAssistantAndroidAppAction(
        input: HavenSystemAssistantAndroidAppActionInput?,
    ) {
        if (input == null) return
        val outcome = input.submitTo(systemAssistantAndroidAppActionResolver)

        // Never retain a public fulfillment intent where recreation could replay it.
        setIntent(Intent(Intent.ACTION_MAIN).setPackage(packageName))
        if (outcome != HavenSystemAssistantAndroidAppActionOutcome.UNAVAILABLE) {
            systemAssistantAndroidPlatformAdapter?.deliverPendingRequest()
        }
    }
}
