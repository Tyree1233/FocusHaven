package com.focushaven.app.wear

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import java.util.Locale

/** Private Wear OS controls whose paired phone remains authoritative. */
class FocusHavenWearActivity :
    Activity(),
    DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var dataClient: DataClient
    private lateinit var messageClient: MessageClient
    private lateinit var commandSender: SystemFocusWearCommandSender
    private val commandCooldown =
        SystemFocusWearCommandCooldown(SystemClock::elapsedRealtime)
    private var snapshot: SystemFocusWearSnapshot? = null
    private var pendingRequestId: String? = null
    private var commandState = CommandState.IDLE

    private val ticker =
        object : Runnable {
            override fun run() {
                render()
            }
        }
    private val commandTimeout =
        Runnable {
            if (pendingRequestId != null) {
                pendingRequestId = null
                commandState = CommandState.NEEDS_PHONE
                render()
                loadLatestSnapshot()
            }
        }
    private val commandCooldownComplete = Runnable(::render)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_focus_haven_wear)
        dataClient = Wearable.getDataClient(this)
        messageClient = Wearable.getMessageClient(this)
        commandSender = SystemFocusWearCommandSender(this)
        render()
    }

    override fun onStart() {
        super.onStart()
        dataClient.addListener(this)
        messageClient.addListener(this)
        loadLatestSnapshot()
    }

    override fun onStop() {
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(commandTimeout)
        handler.removeCallbacks(commandCooldownComplete)
        if (pendingRequestId != null) {
            pendingRequestId = null
            commandState = CommandState.NEEDS_PHONE
        }
        dataClient.removeListener(this)
        messageClient.removeListener(this)
        super.onStop()
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        var latest = snapshot
        for (event in dataEvents) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val candidate = snapshotFrom(event.dataItem) ?: continue
            if (latest == null || candidate.generatedAt > latest.generatedAt) latest = candidate
        }
        latest?.let(::accept)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != SystemFocusWearCommandSender.ACKNOWLEDGEMENT_PATH) return
        val acknowledgement = decodeAcknowledgement(messageEvent.data) ?: return
        if (acknowledgement.requestId != pendingRequestId) return
        runOnUiThread {
            if (acknowledgement.requestId != pendingRequestId) return@runOnUiThread
            handler.removeCallbacks(commandTimeout)
            if (acknowledgement.accepted) {
                commandState = CommandState.PHONE_RECEIVED
                handler.postDelayed(commandTimeout, COMMAND_COMPLETION_TIMEOUT_MILLIS)
            } else {
                pendingRequestId = null
                commandState = CommandState.REJECTED
                loadLatestSnapshot()
            }
            render()
        }
    }

    private fun loadLatestSnapshot() {
        dataClient.getDataItems()
            .addOnSuccessListener { items ->
                try {
                    var latest = snapshot
                    for (item in items) {
                        val candidate = snapshotFrom(item) ?: continue
                        if (latest == null || candidate.generatedAt > latest.generatedAt) {
                            latest = candidate
                        }
                    }
                    latest?.let(::accept)
                } finally {
                    items.release()
                }
            }
            .addOnFailureListener {
                if (snapshot == null) render()
            }
    }

    private fun snapshotFrom(item: DataItem): SystemFocusWearSnapshot? {
        if (item.uri.path != SNAPSHOT_PATH) return null
        val data = DataMapItem.fromDataItem(item).dataMap
        if (data.keySet() != SystemFocusWearSnapshot.WIRE_KEYS) return null
        return SystemFocusWearSnapshot.fromWireMap(
            data.keySet().associateWith { key -> data.get(key) },
        )
    }

    private fun decodeAcknowledgement(bytes: ByteArray): SystemFocusWearAcknowledgement? {
        return try {
            val data = DataMap.fromByteArray(bytes)
            if (data.keySet() != SystemFocusWearAcknowledgement.WIRE_KEYS) return null
            SystemFocusWearAcknowledgement.fromWireMap(
                data.keySet().associateWith { key -> data.get(key) },
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun accept(value: SystemFocusWearSnapshot) {
        runOnUiThread {
            if (snapshot == null || value.generatedAt >= checkNotNull(snapshot).generatedAt) {
                val isNewSnapshot = snapshot == null || value.generatedAt > checkNotNull(snapshot).generatedAt
                val settledCommand = isNewSnapshot && commandState != CommandState.IDLE
                snapshot = value
                if (isNewSnapshot) {
                    clearCommandState()
                    if (settledCommand) startCommandCooldown()
                }
                render()
            }
        }
    }

    private fun startCommandCooldown() {
        commandCooldown.start(COMMAND_INPUT_COOLDOWN_MILLIS)
        handler.removeCallbacks(commandCooldownComplete)
        handler.postDelayed(
            commandCooldownComplete,
            commandCooldown.remainingMilliseconds,
        )
    }

    private fun render() {
        handler.removeCallbacks(ticker)
        val stateView = findViewById<View>(R.id.focus_haven_wear_state)
        val sessionView = findViewById<TextView>(R.id.focus_haven_wear_session)
        val statusView = findViewById<TextView>(R.id.focus_haven_wear_status)
        val timeView = findViewById<TextView>(R.id.focus_haven_wear_time)
        val progressView = findViewById<ProgressBar>(R.id.focus_haven_wear_progress)
        val commandStatusView = findViewById<TextView>(R.id.focus_haven_wear_command_status)
        val primaryButton = findViewById<Button>(R.id.focus_haven_wear_primary_action)
        val secondaryButton = findViewById<Button>(R.id.focus_haven_wear_secondary_action)
        val current = snapshot
        if (current == null) {
            sessionView.setText(R.string.app_name)
            statusView.setText(R.string.open_phone_to_sync)
            timeView.text = "--:--"
            progressView.max = 1
            progressView.progress = 0
            stateView.contentDescription = getString(R.string.open_phone_to_sync)
            commandStatusView.visibility = View.GONE
            primaryButton.visibility = View.GONE
            secondaryButton.visibility = View.GONE
            return
        }

        val presentation = current.presentation()
        val sessionLabel = getString(sessionLabel(presentation.session))
        val statusLabel = getString(activityLabel(presentation.activity))
        val timeLabel = formatTime(presentation.secondsRemaining)
        sessionView.text = sessionLabel
        statusView.text = statusLabel
        timeView.text = timeLabel
        progressView.max = presentation.totalSessionSeconds
        progressView.progress = presentation.completedSeconds
        stateView.contentDescription =
            getString(
                R.string.focus_state_description,
                sessionLabel,
                statusLabel,
                timeLabel,
            )
        renderControls(
            if (presentation.activity == current.activity) current.availableActions else emptySet(),
            primaryButton,
            secondaryButton,
            commandStatusView,
        )
        if (presentation.activity == SystemFocusWearActivity.RUNNING) {
            handler.postDelayed(ticker, 1_000)
        }
    }

    private fun renderControls(
        actions: Set<SystemFocusWearAction>,
        primaryButton: Button,
        secondaryButton: Button,
        commandStatusView: TextView,
    ) {
        val primary =
            listOf(
                SystemFocusWearAction.START,
                SystemFocusWearAction.PAUSE,
                SystemFocusWearAction.RESUME,
                SystemFocusWearAction.BEGIN_NEXT_SESSION,
            ).firstOrNull(actions::contains)
        val secondary =
            listOf(SystemFocusWearAction.RESET, SystemFocusWearAction.DISCARD_PENDING)
                .firstOrNull(actions::contains)
        bindAction(primaryButton, primary)
        bindAction(secondaryButton, secondary)
        val statusResource = commandState.statusResource
        commandStatusView.visibility = if (statusResource == null) View.GONE else View.VISIBLE
        if (statusResource != null) commandStatusView.setText(statusResource)
        val controlsBlocked = pendingRequestId != null || commandCooldown.isActive
        primaryButton.isEnabled = !controlsBlocked
        secondaryButton.isEnabled = !controlsBlocked
    }

    private fun bindAction(
        button: Button,
        action: SystemFocusWearAction?,
    ) {
        if (action == null) {
            button.visibility = View.GONE
            button.setOnClickListener(null)
            return
        }
        button.visibility = View.VISIBLE
        button.setText(action.labelResource)
        button.setOnClickListener {
            if (action.isDestructive) confirmDestructiveAction(action) else send(action)
        }
    }

    private fun confirmDestructiveAction(action: SystemFocusWearAction) {
        AlertDialog.Builder(this)
            .setTitle(action.confirmationTitleResource)
            .setMessage(R.string.destructive_action_message)
            .setNegativeButton(R.string.keep_session, null)
            .setPositiveButton(action.labelResource) { _, _ -> send(action) }
            .show()
    }

    private fun send(action: SystemFocusWearAction) {
        if (commandCooldown.isActive) return
        val current = snapshot ?: return
        val command = SystemFocusWearCommand.create(current, action)
        if (command == null) {
            commandState = CommandState.REJECTED
            render()
            loadLatestSnapshot()
            return
        }
        handler.removeCallbacks(commandTimeout)
        pendingRequestId = command.requestId
        commandState = CommandState.SENDING
        render()
        commandSender.send(command) { delivered ->
            runOnUiThread {
                if (pendingRequestId != command.requestId || commandState != CommandState.SENDING) {
                    return@runOnUiThread
                }
                if (delivered) {
                    commandState = CommandState.WAITING_FOR_PHONE
                    handler.postDelayed(commandTimeout, RECEIPT_TIMEOUT_MILLIS)
                } else {
                    pendingRequestId = null
                    commandState = CommandState.UNAVAILABLE
                }
                render()
            }
        }
    }

    private fun clearCommandState() {
        handler.removeCallbacks(commandTimeout)
        pendingRequestId = null
        commandState = CommandState.IDLE
    }

    private fun sessionLabel(session: SystemFocusWearSession): Int =
        when (session) {
            SystemFocusWearSession.FOCUS -> R.string.session_focus
            SystemFocusWearSession.SHORT_BREAK -> R.string.session_short_break
            SystemFocusWearSession.LONG_BREAK -> R.string.session_long_break
        }

    private fun activityLabel(activity: SystemFocusWearActivity): Int =
        when (activity) {
            SystemFocusWearActivity.READY -> R.string.activity_ready
            SystemFocusWearActivity.RUNNING -> R.string.activity_running
            SystemFocusWearActivity.PAUSED -> R.string.activity_paused
            SystemFocusWearActivity.COMPLETED -> R.string.activity_completed
            SystemFocusWearActivity.PENDING_RESUME -> R.string.activity_pending_resume
        }

    private fun formatTime(seconds: Int): String =
        String.format(Locale.US, "%d:%02d", seconds / 60, seconds % 60)

    companion object {
        const val SNAPSHOT_PATH = "/focus_haven/system_focus/snapshot/v2"
        private const val RECEIPT_TIMEOUT_MILLIS = 8_000L
        private const val COMMAND_COMPLETION_TIMEOUT_MILLIS = 12_000L
        internal const val COMMAND_INPUT_COOLDOWN_MILLIS = 1_000L
    }

    private enum class CommandState(val statusResource: Int?) {
        IDLE(null),
        SENDING(R.string.command_sending),
        WAITING_FOR_PHONE(R.string.command_waiting),
        PHONE_RECEIVED(R.string.command_received),
        REJECTED(R.string.command_rejected),
        UNAVAILABLE(R.string.command_unavailable),
        NEEDS_PHONE(R.string.command_needs_phone),
    }

    private val SystemFocusWearAction.labelResource: Int
        get() =
            when (this) {
                SystemFocusWearAction.START -> R.string.action_start
                SystemFocusWearAction.PAUSE -> R.string.action_pause
                SystemFocusWearAction.RESUME -> R.string.action_resume
                SystemFocusWearAction.RESET -> R.string.action_reset
                SystemFocusWearAction.BEGIN_NEXT_SESSION -> R.string.action_next_session
                SystemFocusWearAction.DISCARD_PENDING -> R.string.action_discard
            }

    private val SystemFocusWearAction.isDestructive: Boolean
        get() = this == SystemFocusWearAction.RESET || this == SystemFocusWearAction.DISCARD_PENDING

    private val SystemFocusWearAction.confirmationTitleResource: Int
        get() =
            when (this) {
                SystemFocusWearAction.RESET -> R.string.confirm_reset
                SystemFocusWearAction.DISCARD_PENDING -> R.string.confirm_discard
                else -> error("Only destructive actions require confirmation.")
            }
}
