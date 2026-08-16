package com.focushaven.app

import android.app.PendingIntent
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.time.Duration
import java.time.Instant
import java.util.Locale

/** Read-only home-screen view of the private, text-free timer snapshot. */
class FocusHavenWidgetProvider : AppWidgetProvider() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        super.onReceive(context, intent)
        if (intent.action == DEADLINE_REFRESH_ACTION) refresh(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    companion object {
        private const val OPEN_REQUEST_CODE = 4107
        private const val DEADLINE_REQUEST_CODE = 4108
        private const val DEADLINE_REFRESH_ACTION =
            "com.focushaven.app.action.REFRESH_FOCUS_WIDGET_DEADLINE"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, FocusHavenWidgetProvider::class.java)
            update(context, manager, manager.getAppWidgetIds(component))
        }

        private fun update(
            context: Context,
            manager: AppWidgetManager,
            widgetIds: IntArray,
        ) {
            if (widgetIds.isEmpty()) {
                scheduleDeadlineRefresh(context, null)
                return
            }
            val content =
                SystemFocusWidgetContent.fromSnapshot(
                    SystemFocusSnapshotStore.load(context),
                )
            scheduleDeadlineRefresh(context, content?.endsAt)
            for (widgetId in widgetIds) {
                manager.updateAppWidget(widgetId, render(context, content))
            }
        }

        private fun render(
            context: Context,
            content: SystemFocusWidgetContent?,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.focus_haven_widget)
            val openIntent =
                Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
            val openPendingIntent =
                PendingIntent.getActivity(
                    context,
                    OPEN_REQUEST_CODE,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            views.setOnClickPendingIntent(R.id.focus_haven_widget_root, openPendingIntent)

            if (content == null) {
                views.setTextViewText(
                    R.id.focus_haven_widget_session,
                    context.getString(R.string.focus_haven_widget_name),
                )
                views.setTextViewText(
                    R.id.focus_haven_widget_status,
                    context.getString(R.string.focus_haven_widget_open_to_begin),
                )
                showStaticTime(views, 0)
                views.setProgressBar(R.id.focus_haven_widget_progress, 1, 0, false)
                setDescription(
                    context,
                    views,
                    context.getString(R.string.focus_haven_widget_open_to_begin),
                )
                return views
            }

            val sessionLabel = context.getString(content.session.labelResource)
            val statusLabel = context.getString(content.activity.labelResource)
            views.setTextViewText(R.id.focus_haven_widget_session, sessionLabel)
            views.setTextViewText(R.id.focus_haven_widget_status, statusLabel)
            views.setProgressBar(
                R.id.focus_haven_widget_progress,
                content.totalSessionSeconds,
                content.completedSeconds,
                false,
            )
            if (content.isRunning) {
                val deadline = checkNotNull(content.endsAt)
                val remainingMillis =
                    Duration.between(Instant.now(), deadline).toMillis().coerceAtLeast(0)
                views.setViewVisibility(R.id.focus_haven_widget_time, View.GONE)
                views.setViewVisibility(R.id.focus_haven_widget_chronometer, View.VISIBLE)
                views.setChronometer(
                    R.id.focus_haven_widget_chronometer,
                    SystemClock.elapsedRealtime() + remainingMillis,
                    null,
                    true,
                )
                views.setChronometerCountDown(R.id.focus_haven_widget_chronometer, true)
            } else {
                showStaticTime(views, content.secondsRemaining)
            }
            setDescription(
                context,
                views,
                context.getString(
                    R.string.focus_haven_widget_description_template,
                    sessionLabel,
                    statusLabel,
                    formatTime(content.secondsRemaining),
                ),
            )
            return views
        }

        private fun scheduleDeadlineRefresh(
            context: Context,
            deadline: Instant?,
        ) {
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            val refreshIntent =
                Intent(context, FocusHavenWidgetProvider::class.java).apply {
                    action = DEADLINE_REFRESH_ACTION
                }
            val pendingIntent =
                PendingIntent.getBroadcast(
                    context,
                    DEADLINE_REQUEST_CODE,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            if (deadline == null) {
                alarmManager.cancel(pendingIntent)
                return
            }
            val remainingMillis =
                Duration.between(Instant.now(), deadline).toMillis().coerceAtLeast(0)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + remainingMillis,
                pendingIntent,
            )
        }

        private fun showStaticTime(
            views: RemoteViews,
            seconds: Int,
        ) {
            views.setViewVisibility(R.id.focus_haven_widget_chronometer, View.GONE)
            views.setViewVisibility(R.id.focus_haven_widget_time, View.VISIBLE)
            views.setTextViewText(R.id.focus_haven_widget_time, formatTime(seconds))
        }

        private fun setDescription(
            context: Context,
            views: RemoteViews,
            stateDescription: String,
        ) {
            views.setContentDescription(
                R.id.focus_haven_widget_root,
                context.getString(
                    R.string.focus_haven_widget_accessibility,
                    stateDescription,
                ),
            )
        }

        private fun formatTime(seconds: Int): String =
            String.format(Locale.US, "%d:%02d", seconds / 60, seconds % 60)

        private val SystemFocusWidgetSession.labelResource: Int
            get() =
                when (this) {
                    SystemFocusWidgetSession.FOCUS -> R.string.focus_haven_widget_focus
                    SystemFocusWidgetSession.SHORT_BREAK -> R.string.focus_haven_widget_short_break
                    SystemFocusWidgetSession.LONG_BREAK -> R.string.focus_haven_widget_long_break
                }

        private val SystemFocusWidgetActivity.labelResource: Int
            get() =
                when (this) {
                    SystemFocusWidgetActivity.READY -> R.string.focus_haven_widget_ready
                    SystemFocusWidgetActivity.RUNNING -> R.string.focus_haven_widget_running
                    SystemFocusWidgetActivity.PAUSED -> R.string.focus_haven_widget_paused
                    SystemFocusWidgetActivity.COMPLETED -> R.string.focus_haven_widget_completed
                    SystemFocusWidgetActivity.PENDING_RESUME ->
                        R.string.focus_haven_widget_pending_resume
                }
    }
}
