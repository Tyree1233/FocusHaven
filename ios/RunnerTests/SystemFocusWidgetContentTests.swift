import Foundation
import XCTest

@testable import Runner

final class SystemFocusWidgetContentTests: XCTestCase {
  private let now = ISO8601DateFormatter().date(from: "2026-08-16T21:00:00Z")!

  func testMissingSnapshotStaysUnavailable() {
    XCTAssertNil(SystemFocusWidgetContent.fromSnapshot(nil, now: now))
  }

  func testMapsEverySessionAndStaticActivity() {
    let expectations: [(String, String, SystemFocusWidgetSession)] = [
      ("focus", "ready", .focus),
      ("shortBreak", "paused", .shortBreak),
      ("longBreak", "pendingResume", .longBreak),
    ]

    for (session, activity, expectedSession) in expectations {
      guard let content = SystemFocusWidgetContent.fromSnapshot(
        snapshot(session: session, activity: activity),
        now: now
      ) else {
        XCTFail("Expected safe widget content for \(session) \(activity)")
        continue
      }

      XCTAssertEqual(content.session, expectedSession)
      XCTAssertEqual(content.activity.rawValue, activity)
      XCTAssertEqual(content.secondsRemaining, 900)
      XCTAssertEqual(content.completedSeconds, 600)
      XCTAssertEqual(content.progress, 0.4, accuracy: 0.000_001)
      XCTAssertNil(content.endsAt)
    }
  }

  func testRunningContentUsesTheLiveDeadlineInsteadOfStoredAge() {
    let deadline = now.addingTimeInterval(83)
    let content = SystemFocusWidgetContent.fromSnapshot(
      snapshot(
        activity: "running",
        secondsRemaining: 120,
        endsAt: Self.utcText(deadline)
      ),
      now: now
    )

    XCTAssertEqual(content?.activity, .running)
    XCTAssertEqual(content?.secondsRemaining, 83)
    XCTAssertEqual(content?.endsAt, deadline)
  }

  func testExpiredRunningContentSettlesWithoutBackgroundPolling() {
    let content = SystemFocusWidgetContent.fromSnapshot(
      snapshot(
        activity: "running",
        secondsRemaining: 30,
        endsAt: Self.utcText(now.addingTimeInterval(-1))
      ),
      now: now
    )

    XCTAssertEqual(content?.activity, .completed)
    XCTAssertEqual(content?.secondsRemaining, 0)
    XCTAssertEqual(content?.progress, 1)
    XCTAssertNil(content?.endsAt)
  }

  func testMalformedPresentationInputFailsClosed() {
    var unknownSession = snapshot()
    unknownSession["session"] = "unknown"
    var zeroTotal = snapshot()
    zeroTotal["totalSessionSeconds"] = 0
    var booleanDuration = snapshot()
    booleanDuration["secondsRemaining"] = true
    var floatingDuration = snapshot()
    floatingDuration["secondsRemaining"] = 900.0
    var badDeadline = snapshot(activity: "running", endsAt: "not-a-time")
    badDeadline["secondsRemaining"] = 30
    var pausedDeadline = snapshot(activity: "paused")
    pausedDeadline["endsAt"] = Self.utcText(now.addingTimeInterval(30))

    for value in [
      unknownSession,
      zeroTotal,
      booleanDuration,
      floatingDuration,
      badDeadline,
      pausedDeadline,
    ] {
      XCTAssertNil(SystemFocusWidgetContent.fromSnapshot(value, now: now))
    }
  }

  func testUnrelatedPrivateTextCannotChangeWidgetContent() {
    var first = snapshot()
    first["task"] = "Private launch plan"
    var second = snapshot()
    second["task"] = "Different private text"

    XCTAssertEqual(
      SystemFocusWidgetContent.fromSnapshot(first, now: now),
      SystemFocusWidgetContent.fromSnapshot(second, now: now)
    )
  }

  func testUnavailableSharedDefaultsFailClosed() {
    let store = SystemFocusSnapshotStore(defaults: nil)

    XCTAssertFalse(store.save(snapshot()))
    XCTAssertNil(store.load())
  }

  private func snapshot(
    session: String = "focus",
    activity: String = "ready",
    secondsRemaining: Int = 900,
    totalSessionSeconds: Int = 1_500,
    endsAt: Any = NSNull()
  ) -> [String: Any] {
    [
      "schemaVersion": 1,
      "session": session,
      "activity": activity,
      "secondsRemaining": secondsRemaining,
      "totalSessionSeconds": totalSessionSeconds,
      "generatedAt": Self.utcText(now),
      "endsAt": endsAt,
    ]
  }

  private static func utcText(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
