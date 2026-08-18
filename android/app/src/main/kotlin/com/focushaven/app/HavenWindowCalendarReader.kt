package com.focushaven.app

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract

enum class HavenWindowCalendarAuthorization {
    UNSUPPORTED,
    DISCONNECTED,
    DENIED,
    READY,
}

interface HavenWindowCalendarReading {
    val authorization: HavenWindowCalendarAuthorization

    fun markPermissionRequested()

    fun busyIntervals(
        rangeStartMillis: Long,
        rangeEndMillis: Long,
    ): List<HavenWindowBusyInterval>
}

/** Reads only calendar-instance time boundaries from Android's local provider. */
class AndroidHavenWindowCalendarReader(
    context: Context,
) : HavenWindowCalendarReading {
    private val appContext = context.applicationContext
    private val preferences =
        appContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override val authorization: HavenWindowCalendarAuthorization
        get() {
            if (appContext.packageManager.resolveContentProvider(CalendarContract.AUTHORITY, 0) == null) {
                return HavenWindowCalendarAuthorization.UNSUPPORTED
            }
            if (
                appContext.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
                    PackageManager.PERMISSION_GRANTED
            ) {
                return HavenWindowCalendarAuthorization.READY
            }
            return if (preferences.getBoolean(PERMISSION_REQUESTED_KEY, false)) {
                HavenWindowCalendarAuthorization.DENIED
            } else {
                HavenWindowCalendarAuthorization.DISCONNECTED
            }
        }

    override fun markPermissionRequested() {
        preferences.edit().putBoolean(PERMISSION_REQUESTED_KEY, true).apply()
    }

    override fun busyIntervals(
        rangeStartMillis: Long,
        rangeEndMillis: Long,
    ): List<HavenWindowBusyInterval> {
        val uri =
            CalendarContract.Instances.CONTENT_URI.buildUpon().also { builder ->
                ContentUris.appendId(builder, rangeStartMillis)
                ContentUris.appendId(builder, rangeEndMillis)
            }.build()
        val projection =
            arrayOf(
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Events.AVAILABILITY,
                CalendarContract.Events.STATUS,
            )
        val intervals = mutableListOf<HavenWindowBusyInterval>()
        appContext.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val beginIndex = cursor.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
            val endIndex = cursor.getColumnIndexOrThrow(CalendarContract.Instances.END)
            val availabilityIndex =
                cursor.getColumnIndexOrThrow(CalendarContract.Events.AVAILABILITY)
            val statusIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.STATUS)
            while (cursor.moveToNext()) {
                val availability = cursor.getInt(availabilityIndex)
                val status = cursor.getInt(statusIndex)
                if (
                    availability == CalendarContract.Events.AVAILABILITY_FREE ||
                        status == CalendarContract.Events.STATUS_CANCELED
                ) {
                    continue
                }
                intervals.add(
                    HavenWindowBusyInterval(
                        startsAtMillis = cursor.getLong(beginIndex),
                        endsAtMillis = cursor.getLong(endIndex),
                    ),
                )
            }
        }
        return intervals
    }

    private companion object {
        const val PREFERENCES_NAME = "focus_haven_window_private_state"
        const val PERMISSION_REQUESTED_KEY = "calendar_permission_requested"
    }
}
