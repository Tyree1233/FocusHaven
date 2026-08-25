import Foundation
import WatchConnectivity
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

  func testWatchAccessibilitySummaryUsesHumanDurationAndProgress() throws {
    let ready = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(secondsRemaining: 180)
      )
    )
    XCTAssertEqual(ready.progressPercent(at: generatedAt), 40)
    XCTAssertEqual(
      ready.accessibilitySummary(at: generatedAt),
      "Focus. Ready when you are. 3 minutes remaining. 40 percent complete."
    )

    let running = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(
          activity: "running",
          secondsRemaining: 83,
          endsAt: isoDate(generatedAt.addingTimeInterval(83))
        )
      )
    )
    XCTAssertEqual(
      running.accessibilitySummary(at: generatedAt),
      "Focus. Steady focus. Live countdown, 1 minute, 23 seconds remaining at last update. 72 percent complete."
    )
  }

  func testWatchAccessibilityDurationsAndActionsStayExplicit() {
    XCTAssertEqual(SystemFocusWatchSnapshot.accessibleDuration(0), "0 seconds")
    XCTAssertEqual(SystemFocusWatchSnapshot.accessibleDuration(1), "1 second")
    XCTAssertEqual(SystemFocusWatchSnapshot.accessibleDuration(60), "1 minute")
    XCTAssertEqual(SystemFocusWatchSnapshot.accessibleDuration(61), "1 minute, 1 second")
    XCTAssertEqual(
      SystemFocusWatchSnapshot.accessibleDuration(3_661),
      "1 hour, 1 minute, 1 second"
    )
    XCTAssertEqual(SystemFocusWatchAction.pause.accessibilityLabel, "Pause FocusHaven timer")
    XCTAssertEqual(
      Set(SystemFocusWatchAction.allCases.map(\.accessibilityLabel)).count,
      SystemFocusWatchAction.allCases.count
    )
  }

  func testComplicationProjectsOnlyCurrentBoundedTimerState() throws {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(secondsRemaining: 180)
      )
    )

    let content = SystemFocusWatchComplicationContent(
      snapshot: snapshot,
      at: generatedAt
    )

    XCTAssertEqual(content.session, .focus)
    XCTAssertEqual(content.activity, .ready)
    XCTAssertEqual(content.secondsRemaining, 180)
    XCTAssertEqual(content.totalSessionSeconds, 300)
    XCTAssertEqual(content.clockText, "3:00")
    XCTAssertEqual(content.compactDurationText, "3:00")
    XCTAssertEqual(content.progress, 0.4, accuracy: 0.001)
    XCTAssertNil(content.endsAt)
    XCTAssertNil(content.timelineReloadDate)
    XCTAssertEqual(
      content.accessibilitySummary,
      "Focus. Ready when you are. 3 minutes remaining. 40 percent complete."
    )
  }

  func testRunningComplicationUsesDeadlineAndExpiresLocally() throws {
    let deadline = generatedAt.addingTimeInterval(300)
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(
          activity: "running",
          endsAt: isoDate(deadline)
        )
      )
    )

    let running = SystemFocusWatchComplicationContent(
      snapshot: snapshot,
      at: generatedAt.addingTimeInterval(75)
    )
    XCTAssertEqual(running.activity, .running)
    XCTAssertEqual(running.secondsRemaining, 225)
    XCTAssertEqual(running.clockText, "3:45")
    XCTAssertEqual(running.progress, 0.25, accuracy: 0.001)
    XCTAssertEqual(running.endsAt, deadline)
    XCTAssertEqual(running.timelineReloadDate, deadline)

    let expired = SystemFocusWatchComplicationContent(
      snapshot: snapshot,
      at: deadline.addingTimeInterval(1)
    )
    XCTAssertEqual(expired.activity, .completed)
    XCTAssertEqual(expired.secondsRemaining, 0)
    XCTAssertEqual(expired.progress, 1)
    XCTAssertNil(expired.endsAt)
    XCTAssertNil(expired.timelineReloadDate)
  }

  func testComplicationFormatsLongDurationsWithoutUnboundedText() throws {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(
        applicationSnapshot(
          secondsRemaining: 3_661,
          totalSessionSeconds: 7_200
        )
      )
    )
    let content = SystemFocusWatchComplicationContent(
      snapshot: snapshot,
      at: generatedAt
    )

    XCTAssertEqual(content.clockText, "61:01")
    XCTAssertEqual(content.compactDurationText, "1:01")
  }

  func testWatchStoreMigratesValidatedLegacySnapshotIntoSharedDefaults() throws {
    let sharedSuite = "FocusHavenWatchSharedTests.\(UUID().uuidString)"
    let legacySuite = "FocusHavenWatchLegacyTests.\(UUID().uuidString)"
    let key = "snapshot"
    let shared = try XCTUnwrap(UserDefaults(suiteName: sharedSuite))
    let legacy = try XCTUnwrap(UserDefaults(suiteName: legacySuite))
    defer {
      shared.removePersistentDomain(forName: sharedSuite)
      legacy.removePersistentDomain(forName: legacySuite)
    }
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())
    )
    let legacyStore = SystemFocusWatchSnapshotStore(
      defaults: legacy,
      legacyDefaults: legacy,
      storageKey: key
    )
    XCTAssertTrue(legacyStore.save(snapshot.wireDictionary))

    let sharedStore = SystemFocusWatchSnapshotStore(
      defaults: shared,
      legacyDefaults: legacy,
      storageKey: key
    )
    XCTAssertEqual(sharedStore.load(), snapshot)
    XCTAssertNotNil(shared.data(forKey: key))
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

  func testCommandUsesOneExactBoundedTextFreeContract() throws {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())
    )
    let command = try XCTUnwrap(
      SystemFocusWatchCommand.create(
        action: .start,
        snapshot: snapshot,
        now: generatedAt.addingTimeInterval(10),
        requestId: "watch-request-123"
      )
    )

    XCTAssertEqual(
      Set(command.wireDictionary.keys),
      [
        "schemaVersion",
        "requestId",
        "action",
        "snapshotGeneratedAtMilliseconds",
        "createdAtMilliseconds",
      ]
    )
    XCTAssertNil(command.wireDictionary["task"])
    XCTAssertNil(command.wireDictionary["accountId"])
    XCTAssertEqual(
      SystemFocusWatchCommand.fromWireDictionary(command.wireDictionary),
      command
    )
  }

  func testMalformedExpandedAndUnboundedCommandsFailClosed() throws {
    let command = try validCommand()
    var expanded = command.wireDictionary
    expanded["reflection"] = "private"
    var floatingVersion = command.wireDictionary
    floatingVersion["schemaVersion"] = 1.0
    var booleanTime = command.wireDictionary
    booleanTime["createdAtMilliseconds"] = true
    var unknownAction = command.wireDictionary
    unknownAction["action"] = "extend"
    var shortRequest = command.wireDictionary
    shortRequest["requestId"] = "short"

    for value in [expanded, floatingVersion, booleanTime, unknownAction, shortRequest] {
      XCTAssertNil(SystemFocusWatchCommand.fromWireDictionary(value))
    }
  }

  func testCommandFreshnessUsesOneBoundedWindow() throws {
    let command = try validCommand(now: generatedAt)

    XCTAssertTrue(command.isFresh(at: generatedAt))
    XCTAssertTrue(
      command.isFresh(
        at: generatedAt.addingTimeInterval(SystemFocusWatchCommand.maximumAge)
      )
    )
    XCTAssertFalse(
      command.isFresh(
        at: generatedAt.addingTimeInterval(SystemFocusWatchCommand.maximumAge + 0.001)
      )
    )
    XCTAssertFalse(command.isFresh(at: generatedAt.addingTimeInterval(-1)))
  }

  func testEveryActivityAdvertisesOnlyItsSafeCommands() throws {
    let expectations: [(String, Set<SystemFocusWatchAction>)] = [
      ("ready", [.start]),
      ("running", [.pause, .reset]),
      ("paused", [.resume, .reset]),
      ("completed", [.beginNextSession]),
      ("pendingResume", [.resume, .discardPending]),
    ]

    for (activity, expected) in expectations {
      let remaining = activity == "completed" ? 0 : 300
      let endsAt: Any =
        activity == "running"
        ? isoDate(generatedAt.addingTimeInterval(300))
        : NSNull()
      let snapshot = try XCTUnwrap(
        SystemFocusWatchSnapshot.fromApplicationSnapshot(
          applicationSnapshot(
            activity: activity,
            secondsRemaining: remaining,
            endsAt: endsAt
          )
        )
      )
      XCTAssertEqual(snapshot.availableActions, expected)
    }
  }

  func testBridgeAuthorizesOneFreshCommandForTheExactSnapshot() throws {
    let bridge = SystemFocusWatchConnectivityBridge(session: nil)
    let snapshot = applicationSnapshot()
    bridge.publish(snapshot: snapshot)
    let command = try validCommand(now: generatedAt.addingTimeInterval(10))
    var delivered: [String: Any]?
    bridge.setCommandHandler { value, completion in
      delivered = value
      completion(true)
    }

    let result = receive(
      command,
      through: bridge,
      now: generatedAt.addingTimeInterval(20)
    )

    XCTAssertEqual(result?.accepted, true)
    XCTAssertEqual(delivered?["action"] as? String, "start")
    XCTAssertEqual(delivered?["requestId"] as? String, command.requestId)
    XCTAssertEqual(
      delivered.map { Set($0.keys) },
      ["schemaVersion", "requestId", "action", "snapshotGeneratedAt"]
    )
  }

  func testBridgeRejectsStaleUnavailableAndMismatchedCommands() throws {
    let bridge = SystemFocusWatchConnectivityBridge(session: nil)
    bridge.publish(snapshot: applicationSnapshot())
    var deliveries = 0
    bridge.setCommandHandler { _, completion in
      deliveries += 1
      completion(true)
    }
    let valid = try validCommand(now: generatedAt)
    var wrongAction = valid.wireDictionary
    wrongAction["action"] = "pause"
    var wrongSnapshot = valid.wireDictionary
    wrongSnapshot["requestId"] = "wrong-snapshot-123"
    wrongSnapshot["snapshotGeneratedAtMilliseconds"] =
      valid.snapshotGeneratedAtMilliseconds + 1

    XCTAssertEqual(
      receive(
        SystemFocusWatchCommand.fromWireDictionary(wrongAction)!,
        through: bridge,
        now: generatedAt
      )?.accepted,
      false
    )
    XCTAssertEqual(
      receive(
        SystemFocusWatchCommand.fromWireDictionary(wrongSnapshot)!,
        through: bridge,
        now: generatedAt
      )?.accepted,
      false
    )
    XCTAssertEqual(
      receive(
        valid,
        through: bridge,
        now: generatedAt.addingTimeInterval(61)
      )?.accepted,
      false
    )
    XCTAssertEqual(deliveries, 0)
  }

  func testBridgeConsumesBothTheRequestAndRenderedSnapshot() throws {
    let bridge = SystemFocusWatchConnectivityBridge(session: nil)
    bridge.publish(snapshot: applicationSnapshot())
    var deliveries = 0
    bridge.setCommandHandler { _, completion in
      deliveries += 1
      completion(false)
    }
    let first = try validCommand(
      now: generatedAt,
      requestId: "first-watch-request"
    )
    let second = try validCommand(
      now: generatedAt,
      requestId: "second-watch-request"
    )

    XCTAssertEqual(receive(first, through: bridge, now: generatedAt)?.accepted, false)
    XCTAssertEqual(receive(first, through: bridge, now: generatedAt)?.accepted, false)
    XCTAssertEqual(receive(second, through: bridge, now: generatedAt)?.accepted, false)
    XCTAssertEqual(deliveries, 1)
  }

  func testWatchStateChangePublishesTheLatestPendingSnapshotOnce() throws {
    let session = RecordingWatchSession()
    let bridge = SystemFocusWatchConnectivityBridge(session: session)
    let first = applicationSnapshot()
    let laterDate = generatedAt.addingTimeInterval(1)
    let second = applicationSnapshot(
      activity: "paused",
      secondsRemaining: 299,
      generatedAt: laterDate
    )

    bridge.publish(snapshot: first)
    bridge.publish(snapshot: second)
    XCTAssertEqual(session.publishedContexts.count, 0)

    session.activationState = .activated
    session.isPaired = true
    session.isWatchAppInstalled = true
    bridge.retryPendingSnapshotAfterWatchStateChange()
    bridge.retryPendingSnapshotAfterWatchStateChange()

    XCTAssertEqual(session.publishedContexts.count, 1)
    XCTAssertEqual(
      session.publishedContexts.first?["generatedAtMilliseconds"] as? Int,
      Int(laterDate.timeIntervalSince1970 * 1_000)
    )
  }

  func testFailedWatchPublicationRemainsPendingForStateChangeRetry() {
    let session = RecordingWatchSession()
    session.activationState = .activated
    session.isPaired = true
    session.isWatchAppInstalled = true
    session.publishError = RecordingWatchSession.TestError.unavailable
    let bridge = SystemFocusWatchConnectivityBridge(session: session)

    bridge.publish(snapshot: applicationSnapshot())
    XCTAssertEqual(session.publishAttempts, 1)
    XCTAssertEqual(session.publishedContexts.count, 0)

    session.publishError = nil
    bridge.retryPendingSnapshotAfterWatchStateChange()

    XCTAssertEqual(session.publishAttempts, 2)
    XCTAssertEqual(session.publishedContexts.count, 1)
  }

  func testCommandResultRequiresTheExactBooleanEnvelope() {
    let valid = SystemFocusWatchCommandResult(
      requestId: "watch-request-123",
      accepted: true
    )
    XCTAssertEqual(
      SystemFocusWatchCommandResult.fromWireDictionary(valid.wireDictionary),
      valid
    )

    var numericBoolean = valid.wireDictionary
    numericBoolean["accepted"] = 1
    var expanded = valid.wireDictionary
    expanded["message"] = "private"
    XCTAssertNil(SystemFocusWatchCommandResult.fromWireDictionary(numericBoolean))
    XCTAssertNil(SystemFocusWatchCommandResult.fromWireDictionary(expanded))
  }

  private func applicationSnapshot(
    session: String = "focus",
    activity: String = "ready",
    secondsRemaining: Int = 300,
    totalSessionSeconds: Int = 300,
    endsAt: Any = NSNull(),
    generatedAt: Date? = nil
  ) -> [String: Any] {
    [
      "schemaVersion": 1,
      "session": session,
      "activity": activity,
      "secondsRemaining": secondsRemaining,
      "totalSessionSeconds": totalSessionSeconds,
      "generatedAt": isoDate(generatedAt ?? self.generatedAt),
      "endsAt": endsAt,
    ]
  }

  private func validWireDictionary() -> [String: Any] {
    SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())!.wireDictionary
  }

  private func validCommand(
    now: Date? = nil,
    requestId: String = "watch-request-123"
  ) throws -> SystemFocusWatchCommand {
    let snapshot = try XCTUnwrap(
      SystemFocusWatchSnapshot.fromApplicationSnapshot(applicationSnapshot())
    )
    return try XCTUnwrap(
      SystemFocusWatchCommand.create(
        action: .start,
        snapshot: snapshot,
        now: now ?? generatedAt,
        requestId: requestId
      )
    )
  }

  private func receive(
    _ command: SystemFocusWatchCommand,
    through bridge: SystemFocusWatchConnectivityBridge,
    now: Date
  ) -> SystemFocusWatchCommandResult? {
    var result: SystemFocusWatchCommandResult?
    bridge.receiveCommand(
      command.wireDictionary,
      reply: { value in
        result = SystemFocusWatchCommandResult.fromWireDictionary(value)
      }, now: now)
    return result
  }

  private func isoDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

private final class RecordingWatchSession: SystemFocusWatchConnectivitySession {
  enum TestError: Error {
    case unavailable
  }

  weak var delegate: WCSessionDelegate?
  var activationState: WCSessionActivationState = .notActivated
  var isPaired = false
  var isWatchAppInstalled = false
  var publishError: Error?
  private(set) var activationCount = 0
  private(set) var publishAttempts = 0
  private(set) var publishedContexts: [[String: Any]] = []

  func activate() {
    activationCount += 1
  }

  func updateApplicationContext(_ applicationContext: [String: Any]) throws {
    publishAttempts += 1
    if let publishError { throw publishError }
    publishedContexts.append(applicationContext)
  }
}
