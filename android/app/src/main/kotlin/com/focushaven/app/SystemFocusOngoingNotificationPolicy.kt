package com.focushaven.app

internal enum class SystemFocusOngoingNotificationOperation {
    IGNORE,
    PUBLISH,
    CANCEL,
}

/** Pure lifecycle policy for the optional Android notification and Lock Screen surface. */
internal object SystemFocusOngoingNotificationPolicy {
    fun operation(
        activity: SystemFocusWidgetActivity?,
        hasExistingNotification: Boolean,
        notificationsAllowed: Boolean,
    ): SystemFocusOngoingNotificationOperation {
        if (!notificationsAllowed) {
            return if (hasExistingNotification) {
                SystemFocusOngoingNotificationOperation.CANCEL
            } else {
                SystemFocusOngoingNotificationOperation.IGNORE
            }
        }
        return when (activity) {
            SystemFocusWidgetActivity.RUNNING ->
                SystemFocusOngoingNotificationOperation.PUBLISH
            SystemFocusWidgetActivity.PAUSED,
            SystemFocusWidgetActivity.PENDING_RESUME,
            ->
                if (hasExistingNotification) {
                    SystemFocusOngoingNotificationOperation.PUBLISH
                } else {
                    SystemFocusOngoingNotificationOperation.IGNORE
                }
            SystemFocusWidgetActivity.READY,
            SystemFocusWidgetActivity.COMPLETED,
            null,
            ->
                if (hasExistingNotification) {
                    SystemFocusOngoingNotificationOperation.CANCEL
                } else {
                    SystemFocusOngoingNotificationOperation.IGNORE
                }
        }
    }
}
