package com.focushaven.app

import java.time.Instant

data class HavenWindowBusyInterval(
    val startsAtMillis: Long,
    val endsAtMillis: Long,
)

/** Complete text-free calendar availability returned to Flutter. */
class HavenWindowAvailabilityPayload private constructor(
    val status: String,
    val rangeStartMillis: Long?,
    val rangeEndMillis: Long?,
    val busyIntervals: List<HavenWindowBusyInterval>,
) {
    fun toMap(): Map<String, Any> {
        val rangeStart = rangeStartMillis
        val rangeEnd = rangeEndMillis
        if (status != READY || rangeStart == null || rangeEnd == null) {
            return mapOf(
                "schemaVersion" to SCHEMA_VERSION,
                "status" to status,
            )
        }
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "status" to status,
            "rangeStartUtc" to timestamp(rangeStart),
            "rangeEndUtc" to timestamp(rangeEnd),
            "busyBlocks" to
                busyIntervals.map { interval ->
                    mapOf(
                        "startsAtUtc" to timestamp(interval.startsAtMillis),
                        "endsAtUtc" to timestamp(interval.endsAtMillis),
                    )
                },
        )
    }

    companion object {
        const val SCHEMA_VERSION = 1
        const val MAXIMUM_RANGE_MILLIS = 36L * 60L * 60L * 1000L
        const val MAXIMUM_BUSY_INTERVALS = 64
        const val READY = "ready"

        private val unavailableStatuses = setOf("unsupported", "disconnected", "denied")

        fun unavailable(status: String): HavenWindowAvailabilityPayload {
            require(status in unavailableStatuses)
            return HavenWindowAvailabilityPayload(status, null, null, emptyList())
        }

        fun ready(
            rangeStartMillis: Long,
            rangeEndMillis: Long,
            busyIntervals: List<HavenWindowBusyInterval>,
        ): HavenWindowAvailabilityPayload {
            require(rangeEndMillis > rangeStartMillis)
            val duration = rangeEndMillis - rangeStartMillis
            require(duration <= MAXIMUM_RANGE_MILLIS)

            val bounded =
                busyIntervals
                    .mapNotNull { interval ->
                        val startsAt = maxOf(interval.startsAtMillis, rangeStartMillis)
                        val endsAt = minOf(interval.endsAtMillis, rangeEndMillis)
                        if (startsAt >= endsAt) {
                            null
                        } else {
                            HavenWindowBusyInterval(startsAt, endsAt)
                        }
                    }.sortedWith(
                        compareBy<HavenWindowBusyInterval> { it.startsAtMillis }
                            .thenBy { it.endsAtMillis },
                    )

            val merged = mutableListOf<HavenWindowBusyInterval>()
            bounded.forEach { interval ->
                val previous = merged.lastOrNull()
                if (previous == null || interval.startsAtMillis > previous.endsAtMillis) {
                    merged.add(interval)
                } else {
                    merged[merged.lastIndex] =
                        previous.copy(endsAtMillis = maxOf(previous.endsAtMillis, interval.endsAtMillis))
                }
            }

            // Never truncate fragmented busy time into a false opening.
            val safeIntervals =
                if (merged.size > MAXIMUM_BUSY_INTERVALS) {
                    listOf(HavenWindowBusyInterval(rangeStartMillis, rangeEndMillis))
                } else {
                    merged.toList()
                }
            return HavenWindowAvailabilityPayload(
                READY,
                rangeStartMillis,
                rangeEndMillis,
                safeIntervals,
            )
        }

        private fun timestamp(milliseconds: Long): String = Instant.ofEpochMilli(milliseconds).toString()
    }
}
