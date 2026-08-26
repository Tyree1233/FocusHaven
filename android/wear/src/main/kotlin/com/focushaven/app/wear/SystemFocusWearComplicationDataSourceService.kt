package com.focushaven.app.wear

import android.app.PendingIntent
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationText
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.CountDownTimeReference
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.data.TimeDifferenceComplicationText
import androidx.wear.watchface.complications.data.TimeDifferenceStyle
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.ComplicationRequest

/** Read-only timer data for user-selected watch-face complication slots. */
class SystemFocusWearComplicationDataSourceService : ComplicationDataSourceService() {
    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener,
    ) {
        listener.onComplicationData(complicationData(request.complicationType))
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        buildData(
            type,
            SystemFocusWearGlanceContent(
                session = SystemFocusWearSession.FOCUS,
                activity = SystemFocusWearActivity.RUNNING,
                secondsRemaining = 1_500,
                totalSessionSeconds = 1_500,
                endsAt = null,
            ),
        )

    private fun complicationData(type: ComplicationType): ComplicationData? {
        val content =
            SystemFocusWearSnapshotStore(this).read()?.let(SystemFocusWearGlanceContent::from)
                ?: return null
        return buildData(type, content)
    }

    private fun buildData(
        type: ComplicationType,
        content: SystemFocusWearGlanceContent,
    ): ComplicationData? {
        val description =
            plain(
                getString(
                    R.string.complication_description,
                    getString(content.session.labelResource),
                    getString(content.activity.labelResource),
                    content.compactTime,
                ),
            )
        val time = content.complicationTime
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(time, description)
                    .setTitle(plain(getString(content.session.shortLabelResource)))
                    .setTapAction(openAppAction)
                    .build()
            ComplicationType.RANGED_VALUE ->
                RangedValueComplicationData.Builder(
                    content.completedSeconds.toFloat(),
                    0f,
                    content.totalSessionSeconds.toFloat(),
                    description,
                )
                    .setText(time)
                    .setTitle(plain(getString(content.session.shortLabelResource)))
                    .setTapAction(openAppAction)
                    .build()
            else -> null
        }
    }

    private val SystemFocusWearGlanceContent.complicationTime: ComplicationText
        get() {
            val deadline = endsAt
            return if (activity == SystemFocusWearActivity.RUNNING && deadline != null) {
                TimeDifferenceComplicationText.Builder(
                    TimeDifferenceStyle.STOPWATCH,
                    CountDownTimeReference(deadline),
                ).setDisplayAsNow(false).build()
            } else {
                plain(compactTime)
            }
        }

    private fun plain(value: String): ComplicationText =
        PlainComplicationText.Builder(value).build()

    private val openAppAction: PendingIntent
        get() =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, FocusHavenWearActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

    private val SystemFocusWearSession.labelResource: Int
        get() =
            when (this) {
                SystemFocusWearSession.FOCUS -> R.string.session_focus
                SystemFocusWearSession.SHORT_BREAK -> R.string.session_short_break
                SystemFocusWearSession.LONG_BREAK -> R.string.session_long_break
            }

    private val SystemFocusWearSession.shortLabelResource: Int
        get() =
            when (this) {
                SystemFocusWearSession.FOCUS -> R.string.session_focus_short
                SystemFocusWearSession.SHORT_BREAK -> R.string.session_short_break_short
                SystemFocusWearSession.LONG_BREAK -> R.string.session_long_break_short
            }

    private val SystemFocusWearActivity.labelResource: Int
        get() =
            when (this) {
                SystemFocusWearActivity.READY -> R.string.activity_ready
                SystemFocusWearActivity.RUNNING -> R.string.activity_running
                SystemFocusWearActivity.PAUSED -> R.string.activity_paused
                SystemFocusWearActivity.COMPLETED -> R.string.activity_completed
                SystemFocusWearActivity.PENDING_RESUME -> R.string.activity_pending_resume
            }
}
