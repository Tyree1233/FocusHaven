import Foundation
import XCTest

@testable import Runner

final class SystemFocusWatchSnapshotTests: XCTestCase {
  private let generatedAt = Date(timeIntervalSince1970: 1_787_002_400)

  func testApplicationSnapshotBecomesOneExactTextFreeWireContract() {
    let snapshot = SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())

    XCTAssertNotNil(snapshot)
    XCTAssertEqual(
      snapshot.map { Set($0.wireDictionary.keys) },
      [
        "schemaVersion",
        "session",
        "activity",
        "secondsRemaining",
        "totalSessionSeconds",
        "generatedAtMilliseconds",
        "endsAtMilliseconds",
      ]
    )
    XCTAssertNil(snapshot?.wireDictionary["task"])
    XCTAssertNil(snapshot?.wireDictionary["accountId"])
    XCTAssertNil(snapshot?.wireDictionary["reflection"])
  }

  func testEverySessionAndNonRunningActivityIsRepresentable() {
    for session in SystemFocusWatchSession.allCases {
      for activity in [
        SystemFocusWatchActivity.ready,
        .paused,
        .completed,
        .pendingResume,
      ] {
        let remaining = activity == .completed ? 0 : 300
        XCTAssertNotNil(
          SystemFocusWatchSnapshot.fromApplicationSnapshot(
            applicationSnapshot(
              session: session.rawValue,
              activity: activity.rawValue,
              secondsRemaining: remaining
            )
          )
        )
      }
    }
  }

  func testWireDictionaryRoundTripsWithoutLosingItsDeadline() {
    let source = SystemFocusWatchSnapshot.fromApplicationSnapshot(
      applicationSnapshot(
        activity: "running",
        endsAt: isoDate(generatedAt.addingTimeInterval(300))
      )
    )

    let restored = SystemFocusWatchSnapshot.fromWireDictionary(source?.wireDictionary)

    XCTAssertEqual(restored, source)
  }

  func testUnknownFieldsAndPrivateTextFailClosedOnBothSides() {
    var application = applicationSnapshot()
    application["task"] = "Private launch plan"
    var wire = validWireDictionary()
    wire["mood"] = "overwhelmed"

    XCTAssertNil(SystemFocusWatchSnapshot.fromApplicationSnapshot(application))
    XCTAssertNil(SystemFocusWatchSnapshot.fromWireDictionary(wire))
  }

  func testMalformedWireTypesEnumsAndDurationsFailClosed() {
    var booleanDuration = validWireDictionary()
    booleanDuration["secondsRemaining"] = true
    var floatingSchema = validWireDictionary()
    floatingSchema["schemaVersion"] = 1.0
    var unknownActivity = validWireDictionary()
    unknownActivity["activity"] = "distracted"
    var oversized = validWireDictionary()
    oversized["totalSessionSeconds"] = 86_401

    XCTAssertNil(SystemFocusWatchSnapshot.fromWireDictionary(booleanDuration))
    XCTAssertNil(SystemFocusWatchSnapshot.fromWireDictionary(floatingSchema))
    XCTAssertNil(SystemFocusWatchSnapshot.fromWireDictionary(unknownActivity))
    XCTAssertNil(SystemFocusWatchSnapshot.fromWireDictionary(oversized))
  }

  func testRunningDeadlineDrivesBoundedLiveCountdownAndProgress() throws {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(
          activity: "running",
          endsAt: isoDate(generatedAt.addingTimeInterval(300))
        )
      )
    )
    let now = generatedAt.addingTimeInterval(75)

    XCTAssertEqual(snapshot.activity(at: now), .running)
    XCTAssertEqual(snapshot.remainingSeconds(at: now), 225)
    XCTAssertEqual(snapshot.progress(at: now), 0.25, accuracy: 0.001)
  }

  func testExpiredRunningSnapshotCompletesOnlyItsWatchPresentation() throws {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(
          activity: "running",
          endsAt: isoDate(generatedAt.addingTimeInterval(300))
        )
      )
    )
    let later = generatedAt.addingTimeInterval(301)

    XCTAssertEqual(snapshot.activity(at: later), .completed)
    XCTAssertEqual(snapshot.remainingSeconds(at: later), 0)
    XCTAssertEqual(snapshot.progress(at: later), 1)
    XCTAssertEqual(snapshot.activity, .running)
  }

  func testImpossibleDeadlineShapesFailClosed() {
    let pausedWithDeadline = applicationSnapshot(
      activity: "paused",
      endsAt: isoDate(generatedAt.addingTimeInterval(300))
    )
    let runningWithoutDeadline = applicationSnapshot(activity: "running")
    let mismatchedRunningDeadline = applicationSnapshot(
      activity: "running",
      endsAt: isoDate(generatedAt.addingTimeInterval(200))
    )

    XCTAssertNil(SystemFocusWatchSnapshot.fromApplicationSnapshot(pausedWithDeadline))
    XCTAssertNil(SystemFocusWatchSnapshot.fromApplicationSnapshot(runningWithoutDeadline))
    XCTAssertNil(SystemFocusWatchSnapshot.fromApplicationSnapshot(mismatchedRunningDeadline))
  }

  func testCompletionAndRemainingTimeMustAgree() {
    XCTAssertNil(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(activity: "completed", secondsRemaining: 1)
      )
    )
    XCTAssertNil(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(activity: "ready", secondsRemaining: 0)
      )
    )
  }

  private func applicationSnapshot(
    session: String = "focus",
    activity: String = "ready",
    secondsRemaining: Int = 300,
    endsAt: Any = NSNull()
  ) -> [String: Any] {
    [
      "schemaVersion": 1,
      "session": session,
      "activity": activity,
      "secondsRemaining": secondsRemaining,
      "totalSessionSeconds": 300,
      "generatedAt": isoDate(generatedAt),
      "endsAt": endsAt,
    ]
  }

  private func validWireDictionary() -> [String: Any] {
    SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())!.wireDictionary
  }

  private func isoDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
