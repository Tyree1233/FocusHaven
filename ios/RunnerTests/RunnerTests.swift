import Foundation
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {
  private var defaults: UserDefaults!
  private var store: SystemFocusSnapshotStore!
  private var suiteName: String!

  override func setUp() {
    super.setUp()
    suiteName = "FocusHavenSystemFocusTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    store = SystemFocusSnapshotStore(defaults: defaults, storageKey: "snapshot")
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    store = nil
    defaults = nil
    suiteName = nil
    super.tearDown()
  }

  func testValidatesEverySafeActivityAndSession() {
    let sessions = ["focus", "shortBreak", "longBreak"]
    let activities = ["ready", "paused", "completed", "pendingResume"]

    for session in sessions {
      for activity in activities {
        let remaining = activity == "completed" ? 0 : 300
        XCTAssertNotNil(
          store.validate(
            snapshot(
              session: session,
              activity: activity,
              secondsRemaining: remaining
            )
          )
        )
      }
    }
  }

  func testValidatesOneMatchingRunningDeadline() {
    let value = snapshot(
      activity: "running",
      secondsRemaining: 300,
      endsAt: "2026-08-16T21:05:00.000Z"
    )

    XCTAssertNotNil(store.validate(value))
  }

  func testRejectsUnknownFieldsAndPrivateText() {
    var value = snapshot()
    value["focusTask"] = "Private launch plan"

    XCTAssertNil(store.validate(value))
  }

  func testRejectsMalformedTypesDurationsAndTimestamps() {
    var floatingSchema = snapshot()
    floatingSchema["schemaVersion"] = 1.0
    var booleanDuration = snapshot()
    booleanDuration["secondsRemaining"] = true
    var oversized = snapshot()
    oversized["totalSessionSeconds"] = 86_401
    var localDate = snapshot()
    localDate["generatedAt"] = "2026-08-16T16:00:00-05:00"
    var impossibleCompletion = snapshot(activity: "completed", secondsRemaining: 1)
    impossibleCompletion["endsAt"] = NSNull()

    XCTAssertNil(store.validate(floatingSchema))
    XCTAssertNil(store.validate(booleanDuration))
    XCTAssertNil(store.validate(oversized))
    XCTAssertNil(store.validate(localDate))
    XCTAssertNil(store.validate(impossibleCompletion))
  }

  func testRejectsUnsafeRunningDeadlinesAndNonRunningEndsAt() {
    let wrongDeadline = snapshot(
      activity: "running",
      secondsRemaining: 300,
      endsAt: "2026-08-16T21:04:00.000Z"
    )
    let pausedWithDeadline = snapshot(
      activity: "paused",
      endsAt: "2026-08-16T21:05:00.000Z"
    )

    XCTAssertNil(store.validate(wrongDeadline))
    XCTAssertNil(store.validate(pausedWithDeadline))
  }

  func testPersistsOnlyValidatedJSONAndRoundTripsNull() {
    let value = snapshot(session: "shortBreak", activity: "paused")

    XCTAssertTrue(store.save(value))
    let restored = store.load()

    XCTAssertEqual(restored?["session"] as? String, "shortBreak")
    XCTAssertEqual(restored?["activity"] as? String, "paused")
    XCTAssertTrue(restored?["endsAt"] is NSNull)
    XCTAssertEqual(restored.map { Set($0.keys) }, Set(value.keys))
  }

  func testMalformedPersistedDataFailsClosed() {
    defaults.set(Data("not-json".utf8), forKey: "snapshot")

    XCTAssertNil(store.load())
  }

  private func snapshot(
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
      "generatedAt": "2026-08-16T21:00:00.000Z",
      "endsAt": endsAt,
    ]
  }
}
