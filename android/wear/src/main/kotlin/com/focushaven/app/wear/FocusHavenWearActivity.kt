package com.focushaven.app.wear

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import java.util.Locale

/** Read-only Wear OS companion. The paired phone remains authoritative. */
class FocusHavenWearActivity : Activity(), DataClient.OnDataChangedListener {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var dataClient: DataClient
    private var snapshot: SystemFocusWearSnapshot? = null

    private val ticker =
        object : Runnable {
            override fun run() {
                render()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_focus_haven_wear)
        dataClient = Wearable.getDataClient(this)
        render()
    }

    override fun onStart() {
        super.onStart()
        dataClient.addListener(this)
        loadLatestSnapshot()
    }

    override fun onStop() {
        handler.removeCallbacks(ticker)
        dataClient.removeListener(this)
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

    private fun accept(value: SystemFocusWearSnapshot) {
        runOnUiThread {
            if (snapshot == null || value.generatedAt >= checkNotNull(snapshot).generatedAt) {
                snapshot = value
                render()
            }
        }
    }

    private fun render() {
        handler.removeCallbacks(ticker)
        val root = findViewById<View>(R.id.focus_haven_wear_root)
        val sessionView = findViewById<TextView>(R.id.focus_haven_wear_session)
        val statusView = findViewById<TextView>(R.id.focus_haven_wear_status)
        val timeView = findViewById<TextView>(R.id.focus_haven_wear_time)
        val progressView = findViewById<ProgressBar>(R.id.focus_haven_wear_progress)
        val current = snapshot
        if (current == null) {
            sessionView.setText(R.string.app_name)
            statusView.setText(R.string.open_phone_to_sync)
            timeView.text = "--:--"
            progressView.max = 1
            progressView.progress = 0
            root.contentDescription = getString(R.string.open_phone_to_sync)
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
        root.contentDescription =
            getString(
                R.string.focus_state_description,
                sessionLabel,
                statusLabel,
                timeLabel,
            )
        if (presentation.activity == SystemFocusWearActivity.RUNNING) {
            handler.postDelayed(ticker, 1_000)
        }
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
        const val SNAPSHOT_PATH = "/focus_haven/system_focus/snapshot/v1"
    }
}
