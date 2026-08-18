package com.focushaven.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class HavenWindowAvailabilityPayloadTest {
    private val rangeStart = 1_776_088_800_000L

    @Test
    fun unavailablePayloadContainsOnlyVersionAndStatus() {
        val payload = HavenWindowAvailabilityPayload.unavailable("denied").toMap()

        assertEquals(setOf("schemaVersion", "status"), payload.keys)
        assertEquals(1, payload["schemaVersion"])
        assertEquals("denied", payload["status"])
        assertFalse(payload.containsKey("calendarName"))
        assertFalse(payload.containsKey("eventTitle"))
        assertFalse(payload.containsKey("attendees"))
    }

    @Test
    fun readyPayloadClampsSortsAndMergesOnlyTimeBoundaries() {
        val rangeEnd = rangeStart + 4 * HOUR
        val payload =
            HavenWindowAvailabilityPayload.ready(
                rangeStart,
                rangeEnd,
                listOf(
                    HavenWindowBusyInterval(rangeStart + 90 * MINUTE, rangeStart + 120 * MINUTE),
                    HavenWindowBusyInterval(rangeStart - 30 * MINUTE, rangeStart + 30 * MINUTE),
                    HavenWindowBusyInterval(rangeStart + 20 * MINUTE, rangeStart + 60 * MINUTE),
                    HavenWindowBusyInterval(rangeStart + 120 * MINUTE, rangeStart + 150 * MINUTE),
                ),
            )

        assertEquals(
            listOf(
                HavenWindowBusyInterval(rangeStart, rangeStart + HOUR),
                HavenWindowBusyInterval(rangeStart + 90 * MINUTE, rangeStart + 150 * MINUTE),
            ),
            payload.busyIntervals,
        )
        val map = payload.toMap()
        assertEquals(
            setOf("schemaVersion", "status", "rangeStartUtc", "rangeEndUtc", "busyBlocks"),
            map.keys,
        )
        @Suppress("UNCHECKED_CAST")
        val blocks = map["busyBlocks"] as List<Map<String, String>>
        blocks.forEach { block ->
            assertEquals(setOf("startsAtUtc", "endsAtUtc"), block.keys)
            assertFalse(block.containsKey("title"))
            assertFalse(block.containsKey("calendar"))
            assertFalse(block.containsKey("identifier"))
        }
    }

    @Test
    fun oversizedFragmentationFailsClosedAsOneBusyRange() {
        val rangeEnd = rangeStart + 24 * HOUR
        val intervals =
            (0..HavenWindowAvailabilityPayload.MAXIMUM_BUSY_INTERVALS).map { index ->
                HavenWindowBusyInterval(
                    rangeStart + index * 2 * MINUTE,
                    rangeStart + index * 2 * MINUTE + MINUTE,
                )
            }

        val payload = HavenWindowAvailabilityPayload.ready(rangeStart, rangeEnd, intervals)

        assertEquals(
            listOf(HavenWindowBusyInterval(rangeStart, rangeEnd)),
            payload.busyIntervals,
        )
    }

    @Test
    fun impossibleReadyRangesAreRejected() {
        assertThrows(IllegalArgumentException::class.java) {
            HavenWindowAvailabilityPayload.ready(rangeStart, rangeStart, emptyList())
        }
        assertThrows(IllegalArgumentException::class.java) {
            HavenWindowAvailabilityPayload.ready(
                rangeStart,
                rangeStart + 37 * HOUR,
                emptyList(),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            HavenWindowAvailabilityPayload.ready(Long.MAX_VALUE, Long.MIN_VALUE, emptyList())
        }
    }

    @Test
    fun statusReadNeverMarksOrReadsWithoutAuthorization() {
        val reader = RecordingCalendarReader(HavenWindowCalendarAuthorization.DISCONNECTED)
        val controller = HavenWindowNativeController(reader) { rangeStart }

        val payload = controller.readAvailability()

        assertEquals("disconnected", payload.status)
        assertEquals(0, reader.markCount)
        assertEquals(0, reader.readCount)
        assertTrue(controller.canRequestAccess())
    }

    @Test
    fun readyControllerReadsOneBoundedDay() {
        val reader = RecordingCalendarReader(HavenWindowCalendarAuthorization.READY)
        val controller = HavenWindowNativeController(reader) { rangeStart }

        val payload = controller.readAvailability()

        assertEquals("ready", payload.status)
        assertEquals(rangeStart, payload.rangeStartMillis)
        assertEquals(rangeStart + 24 * HOUR, payload.rangeEndMillis)
        assertEquals(1, reader.readCount)
        assertEquals(rangeStart, reader.lastRangeStart)
        assertEquals(rangeStart + 24 * HOUR, reader.lastRangeEnd)
        assertFalse(controller.canRequestAccess())
    }

    private companion object {
        const val MINUTE = 60_000L
        const val HOUR = 60L * MINUTE
    }
}

private class RecordingCalendarReader(
    override var authorization: HavenWindowCalendarAuthorization,
) : HavenWindowCalendarReading {
    var markCount = 0
    var readCount = 0
    var lastRangeStart: Long? = null
    var lastRangeEnd: Long? = null

    override fun markPermissionRequested() {
        markCount += 1
        authorization = HavenWindowCalendarAuthorization.DENIED
    }

    override fun busyIntervals(
        rangeStartMillis: Long,
        rangeEndMillis: Long,
    ): List<HavenWindowBusyInterval> {
        readCount += 1
        lastRangeStart = rangeStartMillis
        lastRangeEnd = rangeEndMillis
        return emptyList()
    }
}
