package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Test

class SystemFocusOngoingNotificationPolicyTest {
    @Test
    fun runningStateIsTheOnlyStateThatCanCreateANotification() {
        assertEquals(
            SystemFocusOngoingNotificationOperation.PUBLISH,
            operation(SystemFocusWidgetActivity.RUNNING, existing = false),
        )
        for (
            activity in
                listOf(
                    SystemFocusWidgetActivity.READY,
                    SystemFocusWidgetActivity.PAUSED,
                    SystemFocusWidgetActivity.COMPLETED,
                    SystemFocusWidgetActivity.PENDING_RESUME,
                    null,
                )
        ) {
            assertEquals(
                SystemFocusOngoingNotificationOperation.IGNORE,
                operation(activity, existing = false),
            )
        }
    }

    @Test
    fun pausedAndPendingRecoveryUpdateOnlyAnExistingSurface() {
        for (
            activity in
                listOf(
                    SystemFocusWidgetActivity.PAUSED,
                    SystemFocusWidgetActivity.PENDING_RESUME,
                )
        ) {
            assertEquals(
                SystemFocusOngoingNotificationOperation.PUBLISH,
                operation(activity, existing = true),
            )
        }
    }

    @Test
    fun terminalUnavailableAndReadyStatesRemoveExistingSurface() {
        for (
            activity in
                listOf(
                    SystemFocusWidgetActivity.READY,
                    SystemFocusWidgetActivity.COMPLETED,
                    null,
                )
        ) {
            assertEquals(
                SystemFocusOngoingNotificationOperation.CANCEL,
                operation(activity, existing = true),
            )
        }
    }

    @Test
    fun deniedNotificationAccessNeverPublishesAndRemovesExistingSurface() {
        for (activity in SystemFocusWidgetActivity.entries) {
            assertEquals(
                SystemFocusOngoingNotificationOperation.IGNORE,
                operation(activity, existing = false, allowed = false),
            )
            assertEquals(
                SystemFocusOngoingNotificationOperation.CANCEL,
                operation(activity, existing = true, allowed = false),
            )
        }
    }

    private fun operation(
        activity: SystemFocusWidgetActivity?,
        existing: Boolean,
        allowed: Boolean = true,
    ): SystemFocusOngoingNotificationOperation =
        SystemFocusOngoingNotificationPolicy.operation(
            activity = activity,
            hasExistingNotification = existing,
            notificationsAllowed = allowed,
        )
}
