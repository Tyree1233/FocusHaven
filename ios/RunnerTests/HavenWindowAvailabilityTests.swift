import Foundation
import XCTest

@testable import Runner

@MainActor
final class HavenWindowAvailabilityTests: XCTestCase {
  private let rangeStart = ISO8601DateFormatter().date(
    from: "2026-08-18T13:00:00Z"
  )!

  func testUnavailablePayloadContainsOnlyVersionAndStatus() {
    let payload = HavenWindowAvailabilityPayload.unavailable(status: "denied")

    XCTAssertEqual(Set(payload.dictionary.keys), ["schemaVersion", "status"])
    XCTAssertEqual(payload.dictionary["schemaVersion"] as? Int, 1)
    XCTAssertEqual(payload.dictionary["status"] as? String, "denied")
    XCTAssertNil(payload.dictionary["calendarName"])
    XCTAssertNil(payload.dictionary["eventTitle"])
    XCTAssertNil(payload.dictionary["attendees"])
  }

  func testReadyPayloadClampsSortsAndMergesOnlyTimeBoundaries() throws {
    let rangeEnd = rangeStart.addingTimeInterval(4 * 60 * 60)
    let payload = try HavenWindowAvailabilityPayload.ready(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      busyIntervals: [
        HavenWindowBusyInterval(
          startsAt: rangeStart.addingTimeInterval(90 * 60),
          endsAt: rangeStart.addingTimeInterval(120 * 60)
        ),
        HavenWindowBusyInterval(
          startsAt: rangeStart.addingTimeInterval(-30 * 60),
          endsAt: rangeStart.addingTimeInterval(30 * 60)
        ),
        HavenWindowBusyInterval(
          startsAt: rangeStart.addingTimeInterval(20 * 60),
          endsAt: rangeStart.addingTimeInterval(60 * 60)
        ),
        HavenWindowBusyInterval(
          startsAt: rangeStart.addingTimeInterval(120 * 60),
          endsAt: rangeStart.addingTimeInterval(150 * 60)
        ),
      ]
    )

    XCTAssertEqual(
      Set(payload.dictionary.keys),
      ["schemaVersion", "status", "rangeStartUtc", "rangeEndUtc", "busyBlocks"]
    )
    XCTAssertEqual(payload.busyIntervals.count, 2)
    XCTAssertEqual(payload.busyIntervals[0].startsAt, rangeStart)
    XCTAssertEqual(
      payload.busyIntervals[0].endsAt,
      rangeStart.addingTimeInterval(60 * 60)
    )
    XCTAssertEqual(
      payload.busyIntervals[1].startsAt,
      rangeStart.addingTimeInterval(90 * 60)
    )
    XCTAssertEqual(
      payload.busyIntervals[1].endsAt,
      rangeStart.addingTimeInterval(150 * 60)
    )

    let blocks = try XCTUnwrap(
      payload.dictionary["busyBlocks"] as? [[String: Any]]
    )
    for block in blocks {
      XCTAssertEqual(Set(block.keys), ["startsAtUtc", "endsAtUtc"])
      XCTAssertNil(block["title"])
      XCTAssertNil(block["calendar"])
      XCTAssertNil(block["identifier"])
    }
  }

  func testOversizedFragmentationFailsClosedAsOneBusyRange() throws {
    let rangeEnd = rangeStart.addingTimeInterval(24 * 60 * 60)
    let intervals = (0...HavenWindowAvailabilityPayload.maximumBusyIntervals).map {
      index in
      HavenWindowBusyInterval(
        startsAt: rangeStart.addingTimeInterval(Double(index * 120)),
        endsAt: rangeStart.addingTimeInterval(Double(index * 120 + 60))
      )
    }

    let payload = try HavenWindowAvailabilityPayload.ready(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      busyIntervals: intervals
    )

    XCTAssertEqual(
      payload.busyIntervals,
      [HavenWindowBusyInterval(startsAt: rangeStart, endsAt: rangeEnd)]
    )
  }

  func testImpossibleReadyRangesAreRejected() {
    XCTAssertThrowsError(
      try HavenWindowAvailabilityPayload.ready(
        rangeStart: rangeStart,
        rangeEnd: rangeStart,
        busyIntervals: []
      )
    )
    XCTAssertThrowsError(
      try HavenWindowAvailabilityPayload.ready(
        rangeStart: rangeStart,
        rangeEnd: rangeStart.addingTimeInterval(37 * 60 * 60),
        busyIntervals: []
      )
    )
  }

  func testStatusReadNeverRequestsPermission() throws {
    let reader = RecordingCalendarReader(authorization: .disconnected)
    let controller = HavenWindowNativeController(reader: reader)

    let payload = try controller.readAvailability()

    XCTAssertEqual(payload.status, "disconnected")
    XCTAssertEqual(reader.requestCount, 0)
    XCTAssertEqual(reader.readCount, 0)
  }

  func testExplicitRequestCanTransitionToBoundedReadyAvailability() async throws {
    let reader = RecordingCalendarReader(
      authorization: .disconnected,
      authorizationAfterRequest: .ready,
      intervals: [
        HavenWindowBusyInterval(
          startsAt: rangeStart.addingTimeInterval(60 * 60),
          endsAt: rangeStart.addingTimeInterval(90 * 60)
        )
      ]
    )
    let controller = HavenWindowNativeController(
      reader: reader,
      now: { self.rangeStart }
    )

    let payload = try await controller.requestReadOnlyAccess()

    XCTAssertEqual(reader.requestCount, 1)
    XCTAssertEqual(reader.readCount, 1)
    XCTAssertEqual(payload.status, "ready")
    XCTAssertEqual(payload.rangeStart, rangeStart)
    XCTAssertEqual(
      payload.rangeEnd,
      rangeStart.addingTimeInterval(24 * 60 * 60)
    )
  }

  func testDeniedStateCannotPromptAgain() async throws {
    let reader = RecordingCalendarReader(authorization: .denied)
    let controller = HavenWindowNativeController(reader: reader)

    let payload = try await controller.requestReadOnlyAccess()

    XCTAssertEqual(payload.status, "denied")
    XCTAssertEqual(reader.requestCount, 0)
    XCTAssertEqual(reader.readCount, 0)
  }
}

@MainActor
private final class RecordingCalendarReader: HavenWindowCalendarReading {
  var authorization: HavenWindowCalendarAuthorization
  let authorizationAfterRequest: HavenWindowCalendarAuthorization
  let intervals: [HavenWindowBusyInterval]
  private(set) var requestCount = 0
  private(set) var readCount = 0

  init(
    authorization: HavenWindowCalendarAuthorization,
    authorizationAfterRequest: HavenWindowCalendarAuthorization = .denied,
    intervals: [HavenWindowBusyInterval] = []
  ) {
    self.authorization = authorization
    self.authorizationAfterRequest = authorizationAfterRequest
    self.intervals = intervals
  }

  func requestAccess() async throws {
    requestCount += 1
    authorization = authorizationAfterRequest
  }

  func busyIntervals(from rangeStart: Date, to rangeEnd: Date) throws
    -> [HavenWindowBusyInterval]
  {
    readCount += 1
    return intervals
  }
}
