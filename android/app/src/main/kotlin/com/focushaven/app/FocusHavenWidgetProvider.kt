package com.focushaven.app

import android.app.PendingIntent
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.time.Duration
import java.time.Instant
import java.util.Locale

/** Private, text-free timer surface with narrowly authorized controls. */
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
                hideControls(views)
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
            configureControls(context, views, content)
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

        private fun configureControls(
            context: Context,
            views: RemoteViews,
            content: SystemFocusWidgetContent,
        ) {
            val primaryAction =
                when {
                    SystemFocusWidgetAction.START in content.availableActions ->
                        SystemFocusWidgetAction.START
                    SystemFocusWidgetAction.PAUSE in content.availableActions ->
                        SystemFocusWidgetAction.PAUSE
                    SystemFocusWidgetAction.RESUME in content.availableActions ->
                        SystemFocusWidgetAction.RESUME
                    SystemFocusWidgetAction.BEGIN_NEXT_SESSION in content.availableActions ->
                        SystemFocusWidgetAction.BEGIN_NEXT_SESSION
                    else -> null
                }
            if (primaryAction == null) {
                hideControls(views)
                return
            }
            views.setViewVisibility(R.id.focus_haven_widget_controls, View.VISIBLE)
            views.setViewVisibility(R.id.focus_haven_widget_primary_action, View.VISIBLE)
            views.setTextViewText(
                R.id.focus_haven_widget_primary_action,
                context.getString(primaryAction.labelResource),
            )
            views.setOnClickPendingIntent(
                R.id.focus_haven_widget_primary_action,
                commandPendingIntent(context, content, primaryAction),
            )
            if (SystemFocusWidgetAction.RESET in content.availableActions) {
                views.setViewVisibility(R.id.focus_haven_widget_reset_action, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.focus_haven_widget_reset_action,
                    commandPendingIntent(context, content, SystemFocusWidgetAction.RESET),
                )
            } else {
                views.setViewVisibility(R.id.focus_haven_widget_reset_action, View.GONE)
            }
        }

        private fun commandPendingIntent(
            context: Context,
            content: SystemFocusWidgetContent,
            action: SystemFocusWidgetAction,
        ): PendingIntent {
            val snapshotGeneratedAt = content.snapshotGeneratedAt.toString()
            val pendingIntentIdentity =
                checkNotNull(
                    SystemFocusWidgetCommandPolicy.pendingIntentIdentity(
                        action.wireName,
                        snapshotGeneratedAt,
                    ),
                )
            val intent =
                Intent(context, FocusHavenWidgetCommandActivity::class.java).apply {
                    data = Uri.parse(pendingIntentIdentity)
                    putExtra(FocusHavenWidgetCommandActivity.EXTRA_ACTION, action.wireName)
                    putExtra(
                        FocusHavenWidgetCommandActivity.EXTRA_SNAPSHOT_GENERATED_AT,
                        snapshotGeneratedAt,
                    )
                }
            return PendingIntent.getActivity(
                context,
                4200 + action.ordinal,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun hideControls(views: RemoteViews) {
            views.setViewVisibility(R.id.focus_haven_widget_controls, View.GONE)
            views.setViewVisibility(R.id.focus_haven_widget_primary_action, View.GONE)
            views.setViewVisibility(R.id.focus_haven_widget_reset_action, View.GONE)
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

        private val SystemFocusWidgetAction.labelResource: Int
            get() =
                when (this) {
                    SystemFocusWidgetAction.START -> R.string.focus_haven_widget_start
                    SystemFocusWidgetAction.PAUSE -> R.string.focus_haven_widget_pause
                    SystemFocusWidgetAction.RESUME -> R.string.focus_haven_widget_resume
                    SystemFocusWidgetAction.RESET -> R.string.focus_haven_widget_reset
                    SystemFocusWidgetAction.BEGIN_NEXT_SESSION ->
                        R.string.focus_haven_widget_next
                    SystemFocusWidgetAction.DISCARD_PENDING ->
                        R.string.focus_haven_widget_discard
                }
    }
}
