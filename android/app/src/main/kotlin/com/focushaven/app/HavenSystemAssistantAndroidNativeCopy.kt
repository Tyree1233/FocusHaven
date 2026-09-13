package com.focushaven.app

import android.content.res.Resources

/**
 * Stable resource identifiers for the completely reviewed Android-native
 * System Assistant copy.
 *
 * This type resolves localized text only. It does not declare a shortcut,
 * capability, query pattern, App Action, request submission, or Haven Action.
 */
internal enum class HavenSystemAssistantAndroidNativeCopyKey(
    val resourceId: Int,
) {
    CANCELLED_RESULT(R.string.android_system_assistant_native_cancelled_result),
    COLLECTION_TITLE(R.string.android_system_assistant_native_collection_title),
    DISCOVERY_DESCRIPTION(R.string.android_system_assistant_native_discovery_description),
    EXPIRED_RESULT(R.string.android_system_assistant_native_expired_result),
    NO_PARAMETERS_SUMMARY(R.string.android_system_assistant_native_no_parameters_summary),
    OPEN_FOCUS_QUEUE_INVOCATION_EXAMPLE(R.string.android_system_assistant_native_open_focus_queue_invocation_example),
    OPEN_FOCUS_QUEUE_LONG_LABEL(R.string.android_system_assistant_native_open_focus_queue_long_label),
    OPEN_FOCUS_QUEUE_SHORT_LABEL(R.string.android_system_assistant_native_open_focus_queue_short_label),
    PAUSE_TIMER_INVOCATION_EXAMPLE(R.string.android_system_assistant_native_pause_timer_invocation_example),
    PAUSE_TIMER_LONG_LABEL(R.string.android_system_assistant_native_pause_timer_long_label),
    PAUSE_TIMER_SHORT_LABEL(R.string.android_system_assistant_native_pause_timer_short_label),
    PENDING_REQUEST_ACCESSIBILITY_LABEL(R.string.android_system_assistant_native_pending_request_accessibility_label),
    PENDING_REQUEST_RESULT(R.string.android_system_assistant_native_pending_request_result),
    PRIVACY_SUMMARY(R.string.android_system_assistant_native_privacy_summary),
    READ_TIMER_STATUS_INVOCATION_EXAMPLE(R.string.android_system_assistant_native_read_timer_status_invocation_example),
    READ_TIMER_STATUS_LONG_LABEL(R.string.android_system_assistant_native_read_timer_status_long_label),
    READ_TIMER_STATUS_SHORT_LABEL(R.string.android_system_assistant_native_read_timer_status_short_label),
    REJECTED_RESULT(R.string.android_system_assistant_native_rejected_result),
    RESUME_TIMER_INVOCATION_EXAMPLE(R.string.android_system_assistant_native_resume_timer_invocation_example),
    RESUME_TIMER_LONG_LABEL(R.string.android_system_assistant_native_resume_timer_long_label),
    RESUME_TIMER_SHORT_LABEL(R.string.android_system_assistant_native_resume_timer_short_label),
    REVIEW_INSTRUCTION(R.string.android_system_assistant_native_review_instruction),
    REVIEW_REQUIRED_ACCESSIBILITY_LABEL(R.string.android_system_assistant_native_review_required_accessibility_label),
    REVIEW_REQUIRED_RESULT(R.string.android_system_assistant_native_review_required_result),
    START_FOCUS_TIMER_INVOCATION_EXAMPLE(R.string.android_system_assistant_native_start_focus_timer_invocation_example),
    START_FOCUS_TIMER_LONG_LABEL(R.string.android_system_assistant_native_start_focus_timer_long_label),
    START_FOCUS_TIMER_SHORT_LABEL(R.string.android_system_assistant_native_start_focus_timer_short_label),
    UNAVAILABLE_RESULT(R.string.android_system_assistant_native_unavailable_result),
}

/** Exact short-label, long-label, and invocation-example keys for one route. */
internal data class HavenSystemAssistantAndroidNativeRouteCopyKeys(
    val shortLabel: HavenSystemAssistantAndroidNativeCopyKey,
    val longLabel: HavenSystemAssistantAndroidNativeCopyKey,
    val invocationExample: HavenSystemAssistantAndroidNativeCopyKey,
)

internal val HavenSystemAssistantAndroidRoute.nativeCopyKeys:
    HavenSystemAssistantAndroidNativeRouteCopyKeys
    get() =
        when (this) {
            HavenSystemAssistantAndroidRoute.READ_TIMER_STATUS ->
                HavenSystemAssistantAndroidNativeRouteCopyKeys(
                    shortLabel = HavenSystemAssistantAndroidNativeCopyKey.READ_TIMER_STATUS_SHORT_LABEL,
                    longLabel = HavenSystemAssistantAndroidNativeCopyKey.READ_TIMER_STATUS_LONG_LABEL,
                    invocationExample =
                        HavenSystemAssistantAndroidNativeCopyKey.READ_TIMER_STATUS_INVOCATION_EXAMPLE,
                )
            HavenSystemAssistantAndroidRoute.START_FOCUS_TIMER ->
                HavenSystemAssistantAndroidNativeRouteCopyKeys(
                    shortLabel = HavenSystemAssistantAndroidNativeCopyKey.START_FOCUS_TIMER_SHORT_LABEL,
                    longLabel = HavenSystemAssistantAndroidNativeCopyKey.START_FOCUS_TIMER_LONG_LABEL,
                    invocationExample =
                        HavenSystemAssistantAndroidNativeCopyKey.START_FOCUS_TIMER_INVOCATION_EXAMPLE,
                )
            HavenSystemAssistantAndroidRoute.PAUSE_TIMER ->
                HavenSystemAssistantAndroidNativeRouteCopyKeys(
                    shortLabel = HavenSystemAssistantAndroidNativeCopyKey.PAUSE_TIMER_SHORT_LABEL,
                    longLabel = HavenSystemAssistantAndroidNativeCopyKey.PAUSE_TIMER_LONG_LABEL,
                    invocationExample =
                        HavenSystemAssistantAndroidNativeCopyKey.PAUSE_TIMER_INVOCATION_EXAMPLE,
                )
            HavenSystemAssistantAndroidRoute.RESUME_TIMER ->
                HavenSystemAssistantAndroidNativeRouteCopyKeys(
                    shortLabel = HavenSystemAssistantAndroidNativeCopyKey.RESUME_TIMER_SHORT_LABEL,
                    longLabel = HavenSystemAssistantAndroidNativeCopyKey.RESUME_TIMER_LONG_LABEL,
                    invocationExample =
                        HavenSystemAssistantAndroidNativeCopyKey.RESUME_TIMER_INVOCATION_EXAMPLE,
                )
            HavenSystemAssistantAndroidRoute.OPEN_FOCUS_QUEUE ->
                HavenSystemAssistantAndroidNativeRouteCopyKeys(
                    shortLabel = HavenSystemAssistantAndroidNativeCopyKey.OPEN_FOCUS_QUEUE_SHORT_LABEL,
                    longLabel = HavenSystemAssistantAndroidNativeCopyKey.OPEN_FOCUS_QUEUE_LONG_LABEL,
                    invocationExample =
                        HavenSystemAssistantAndroidNativeCopyKey.OPEN_FOCUS_QUEUE_INVOCATION_EXAMPLE,
                )
        }

/** Fail-closed access to the reviewed Android resource catalog. */
internal class HavenSystemAssistantAndroidNativeCopy internal constructor(
    private val lookup: (Int) -> String?,
) {
    fun text(key: HavenSystemAssistantAndroidNativeCopyKey): String? =
        lookup(key.resourceId)?.takeIf(::isValid)

    companion object {
        const val MAXIMUM_TEXT_UTF8_LENGTH = 1024

        fun from(resources: Resources): HavenSystemAssistantAndroidNativeCopy =
            HavenSystemAssistantAndroidNativeCopy { resourceId ->
                try {
                    resources.getString(resourceId)
                } catch (_: Resources.NotFoundException) {
                    null
                }
            }

        fun isValid(value: String): Boolean =
            value.isNotEmpty() &&
                value == value.trim() &&
                value.toByteArray(Charsets.UTF_8).size <= MAXIMUM_TEXT_UTF8_LENGTH &&
                value.none(Char::isISOControl) &&
                !value.contains('%') &&
                !PLACEHOLDER_PATTERN.containsMatchIn(value)

        private val PLACEHOLDER_PATTERN = Regex("""\{[^}]+}""")
    }
}
