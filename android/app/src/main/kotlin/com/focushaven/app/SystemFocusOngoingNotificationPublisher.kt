package com.focushaven.app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import java.time.Duration
import java.time.Instant

/**
 * Mirrors only the validated, text-free timer snapshot into one optional system notification.
 *
 * This publisher never requests permission, starts a service, polls, or changes timer state.
 */
internal object SystemFocusOngoingNotificationPublisher {
    private const val CHANNEL_ID = "focus_haven_active_timer"
    private const val NOTIFICATION_ID = 18_400
    private const val OPEN_REQUEST_CODE = 18_401
    private const val DEADLINE_REQUEST_CODE = 18_402
    private const val COMMAND_REQUEST_CODE_BASE = 18_410

    fun publish(
        context: Context,
        snapshot: Map<String, Any?>,
    ) {
        reconcile(context, SystemFocusWidgetContent.fromSnapshot(snapshot))
    }

    fun refresh(context: Context) {
        reconcile(
            context,
            SystemFocusWidgetContent.fromSnapshot(SystemFocusSnapshotStore.load(context)),
        )
    }

    private fun reconcile(
        context: Context,
        content: SystemFocusWidgetContent?,
    ) {
        try {
            val manager = context.getSystemService(NotificationManager::class.java)
            val hasExisting =
                manager.activeNotifications.any { notification ->
                    notification.id == NOTIFICATION_ID
                }
            val notificationsAllowed = notificationsAllowed(context, manager)
            when (
                SystemFocusOngoingNotificationPolicy.operation(
                    content?.activity,
                    hasExisting,
                    notificationsAllowed,
                )
            ) {
                SystemFocusOngoingNotificationOperation.IGNORE -> {
                    if (!notificationsAllowed || content?.isRunning != true) {
                        cancelDeadlineRefresh(context)
                    }
                }
                SystemFocusOngoingNotificationOperation.CANCEL -> {
                    manager.cancel(NOTIFICATION_ID)
                    cancelDeadlineRefresh(context)
                }
                SystemFocusOngoingNotificationOperation.PUBLISH -> {
                    val safeContent = checkNotNull(content)
                    createChannel(manager, context)
                    manager.notify(NOTIFICATION_ID, notification(context, safeContent))
                    scheduleDeadlineRefresh(context, safeContent.endsAt)
                }
            }
        } catch (_: Exception) {
            // A system-surface failure must never affect the authoritative Flutter timer.
        }
    }

    private fun notificationsAllowed(
        context: Context,
        manager: NotificationManager,
    ): Boolean {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = manager.getNotificationChannel(CHANNEL_ID)
            if (channel?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    private fun createChannel(
        manager: NotificationManager,
        context: Context,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.focus_haven_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    context.getString(R.string.focus_haven_notification_channel_description)
                enableVibration(false)
                setSound(null, null)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        manager.createNotificationChannel(channel)
    }

    private fun notification(
        context: Context,
        content: SystemFocusWidgetContent,
    ): Notification {
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
        builder
            .setSmallIcon(R.drawable.ic_focus_haven_notification)
            .setContentTitle(context.getString(content.session.titleResource))
            .setContentText(context.getString(content.activity.statusResource))
            .setContentIntent(openPendingIntent(context))
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setLocalOnly(true)
            .setShowWhen(false)
            .setProgress(
                content.totalSessionSeconds,
                content.completedSeconds,
                false,
            )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder
                .setPriority(Notification.PRIORITY_LOW)
                .setSound(null)
                .setVibrate(null)
        }
        if (content.isRunning) {
            val deadline = checkNotNull(content.endsAt)
            builder
                .setWhen(deadline.toEpochMilli())
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setShowWhen(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setTimeoutAfter(
                    Duration.between(Instant.now(), deadline).toMillis().coerceAtLeast(1),
                )
            }
        }
        for (action in content.availableActions) {
            builder.addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(context, R.drawable.ic_focus_haven_notification),
                    context.getString(action.labelResource),
                    commandPendingIntent(context, content, action),
                ).build(),
            )
        }
        return builder.build()
    }

    private fun openPendingIntent(context: Context): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        return PendingIntent.getActivity(
            context,
            OPEN_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun commandPendingIntent(
        context: Context,
        content: SystemFocusWidgetContent,
        action: SystemFocusWidgetAction,
    ): PendingIntent {
        val snapshotGeneratedAt = content.snapshotGeneratedAt.toString()
        val identity =
            checkNotNull(
                SystemFocusWidgetCommandPolicy.notificationPendingIntentIdentity(
                    action.wireName,
                    snapshotGeneratedAt,
                ),
            )
        val intent =
            Intent(context, FocusHavenWidgetCommandActivity::class.java).apply {
                data = Uri.parse(identity)
                putExtra(FocusHavenWidgetCommandActivity.EXTRA_ACTION, action.wireName)
                putExtra(
                    FocusHavenWidgetCommandActivity.EXTRA_SNAPSHOT_GENERATED_AT,
                    snapshotGeneratedAt,
                )
            }
        return PendingIntent.getActivity(
            context,
            COMMAND_REQUEST_CODE_BASE + action.ordinal,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleDeadlineRefresh(
        context: Context,
        deadline: Instant?,
    ) {
        if (deadline == null) {
            cancelDeadlineRefresh(context)
            return
        }
        val remainingMillis =
            Duration.between(Instant.now(), deadline).toMillis().coerceAtLeast(0)
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + remainingMillis,
            deadlinePendingIntent(context),
        )
    }

    private fun cancelDeadlineRefresh(context: Context) {
        context
            .getSystemService(AlarmManager::class.java)
            .cancel(deadlinePendingIntent(context))
    }

    private fun deadlinePendingIntent(context: Context): PendingIntent {
        val intent =
            Intent(context, SystemFocusOngoingNotificationReceiver::class.java).apply {
                action = SystemFocusOngoingNotificationReceiver.DEADLINE_REFRESH_ACTION
            }
        return PendingIntent.getBroadcast(
            context,
            DEADLINE_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private val SystemFocusWidgetSession.titleResource: Int
        get() =
            when (this) {
                SystemFocusWidgetSession.FOCUS -> R.string.focus_haven_notification_focus
                SystemFocusWidgetSession.SHORT_BREAK ->
                    R.string.focus_haven_notification_short_break
                SystemFocusWidgetSession.LONG_BREAK ->
                    R.string.focus_haven_notification_long_break
            }

    private val SystemFocusWidgetActivity.statusResource: Int
        get() =
            when (this) {
                SystemFocusWidgetActivity.READY -> R.string.focus_haven_notification_ready
                SystemFocusWidgetActivity.RUNNING -> R.string.focus_haven_notification_running
                SystemFocusWidgetActivity.PAUSED -> R.string.focus_haven_notification_paused
                SystemFocusWidgetActivity.COMPLETED -> R.string.focus_haven_notification_completed
                SystemFocusWidgetActivity.PENDING_RESUME ->
                    R.string.focus_haven_notification_pending_resume
            }

    private val SystemFocusWidgetAction.labelResource: Int
        get() =
            when (this) {
                SystemFocusWidgetAction.START -> R.string.focus_haven_widget_start
                SystemFocusWidgetAction.PAUSE -> R.string.focus_haven_widget_pause
                SystemFocusWidgetAction.RESUME -> R.string.focus_haven_widget_resume
                SystemFocusWidgetAction.RESET -> R.string.focus_haven_widget_reset
                SystemFocusWidgetAction.BEGIN_NEXT_SESSION -> R.string.focus_haven_widget_next
                SystemFocusWidgetAction.DISCARD_PENDING -> R.string.focus_haven_widget_discard
            }
}

/** Restores or settles the one optional notification after a deadline, reboot, or app update. */
class SystemFocusOngoingNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (
            intent.action == DEADLINE_REFRESH_ACTION ||
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            SystemFocusOngoingNotificationPublisher.refresh(context)
        }
    }

    companion object {
        const val DEADLINE_REFRESH_ACTION =
            "com.focushaven.app.action.REFRESH_FOCUS_NOTIFICATION_DEADLINE"
    }
}
