package com.focushaven.app

class HavenWindowNativeController(
    private val reader: HavenWindowCalendarReading,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    fun readAvailability(): HavenWindowAvailabilityPayload =
        when (reader.authorization) {
            HavenWindowCalendarAuthorization.UNSUPPORTED ->
                HavenWindowAvailabilityPayload.unavailable("unsupported")
            HavenWindowCalendarAuthorization.DISCONNECTED ->
                HavenWindowAvailabilityPayload.unavailable("disconnected")
            HavenWindowCalendarAuthorization.DENIED ->
                HavenWindowAvailabilityPayload.unavailable("denied")
            HavenWindowCalendarAuthorization.READY -> {
                val rangeStart = nowMillis()
                val rangeEnd = rangeStart + QUERY_DURATION_MILLIS
                HavenWindowAvailabilityPayload.ready(
                    rangeStart,
                    rangeEnd,
                    reader.busyIntervals(rangeStart, rangeEnd),
                )
            }
        }

    fun canRequestAccess(): Boolean =
        reader.authorization == HavenWindowCalendarAuthorization.DISCONNECTED

    fun markPermissionRequested() = reader.markPermissionRequested()

    private companion object {
        const val QUERY_DURATION_MILLIS = 24L * 60L * 60L * 1000L
    }
}
