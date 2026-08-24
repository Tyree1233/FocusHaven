import Foundation
import XCTest

@testable import Runner

final class SystemFocusWidgetCommandTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!
  private var snapshotStore: SystemFocusSnapshotStore!
  private var commandStore: SystemFocusPendingCommandStore!
  private let generatedAt = "2026-08-16T21:00:00.000Z"
  private let token = "ABCDEFGHIJKLMNOPQRSTUVWX12345678"
  private let now = ISO8601DateFormatter().date(from: "2026-08-16T21:00:30Z")!

  override func setUp() {
    super.setUp()
    suiteName = "FocusHavenWidgetCommandTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    snapshotStore = SystemFocusSnapshotStore(defaults: defaults)
    commandStore = SystemFocusPendingCommandStore(defaults: defaults)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    commandStore = nil
    snapshotStore = nil
    defaults = nil
    suiteName = nil
    super.tearDown()
  }

  func testParsesOnlyTheExactBoundedCommandURL() {
    let request = SystemFocusWidgetCommandPolicy.parseCommandURL(
      commandURL(action: .pause, token: token)
    )

    XCTAssertEqual(request?.action, .pause)
    XCTAssertEqual(request?.snapshotGeneratedAt, generatedAt)
    XCTAssertEqual(request?.controlToken, token)
  }

  func testMalformedAndExpandedURLsFailClosed() {
    let invalidURLs = [
      "other://system-focus-command?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)",
      "focushaven://other?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)",
      "focushaven://system-focus-command/path?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)",
      "focushaven://system-focus-command?action=start&action=pause&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)",
      "focushaven://system-focus-command?action=start&snapshotGeneratedAt=not-a-time&controlToken=\(token)",
      "focushaven://system-focus-command?action=unknown&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)",
      "focushaven://system-focus-command?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=short",
      "focushaven://system-focus-command?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)&extra=value",
      "focushaven://system-focus-command?action=start&snapshotGeneratedAt=\(generatedAt)&controlToken=\(token)#fragment",
    ]

    for text in invalidURLs {
      let url = URL(string: text)!
      XCTAssertNil(
        SystemFocusWidgetCommandPolicy.parseCommandURL(url),
        "Expected URL rejection: \(text)"
      )
    }
  }

  func testEveryActionIsAllowedOnlyByItsAdvertisedActivity() {
    let expectations: [(String, Set<SystemFocusWidgetAction>)] = [
      ("ready", [.start]),
      ("running", [.pause, .reset]),
      ("paused", [.resume, .reset]),
      ("completed", [.beginNextSession]),
      ("pendingResume", [.resume, .discardPending]),
    ]

    for (activity, allowed) in expectations {
      let snapshot = snapshot(activity: activity)
      for action in SystemFocusWidgetAction.allCases {
        let request = SystemFocusWidgetLinkRequest(
          action: action,
          snapshotGeneratedAt: generatedAt,
          controlToken: token
        )
        XCTAssertEqual(
          SystemFocusWidgetCommandPolicy.isAllowed(snapshot: snapshot, request: request),
          allowed.contains(action),
          "Unexpected authorization for \(activity) \(action.rawValue)"
        )
      }
    }
  }

  func testMismatchedSnapshotTimestampIsRejected() {
    let request = SystemFocusWidgetLinkRequest(
      action: .start,
      snapshotGeneratedAt: "2026-08-16T21:00:01.000Z",
      controlToken: token
    )

    XCTAssertFalse(
      SystemFocusWidgetCommandPolicy.isAllowed(
        snapshot: snapshot(activity: "ready"),
        request: request
      )
    )
  }

  func testEnvelopeValidationRejectsUnknownAndMalformedFields() {
    let valid: [String: Any] = [
      "schemaVersion": 1,
      "requestId": UUID().uuidString,
      "action": "start",
      "snapshotGeneratedAt": generatedAt,
    ]
    XCTAssertNotNil(SystemFocusWidgetCommandPolicy.validateEnvelope(valid))

    var unknown = valid
    unknown["task"] = "private"
    var floatingVersion = valid
    floatingVersion["schemaVersion"] = 1.0
    var shortRequest = valid
    shortRequest["requestId"] = "short"
    var badAction = valid
    badAction["action"] = "unknown"

    for value in [unknown, floatingVersion, shortRequest, badAction] {
      XCTAssertNil(SystemFocusWidgetCommandPolicy.validateEnvelope(value))
    }
  }

  func testPendingFreshnessUsesOneBoundedWindow() {
    XCTAssertTrue(
      SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
        createdAt: now.addingTimeInterval(-120),
        now: now
      )
    )
    XCTAssertFalse(
      SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
        createdAt: now.addingTimeInterval(-120.001),
        now: now
      )
    )
    XCTAssertFalse(
      SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
        createdAt: now.addingTimeInterval(1),
        now: now
      )
    )
  }

  func testEnqueueConsumesOnePrivateCapabilityAndTakeConsumesOneCommand() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let currentToken = tryUnwrap(snapshotStore.loadControlToken())
    let url = commandURL(action: .start, token: currentToken)

    XCTAssertTrue(commandStore.enqueue(url: url, now: now))
    XCTAssertFalse(commandStore.enqueue(url: url, now: now))

    let pending = commandStore.peek(now: now)
    XCTAssertEqual(pending?["action"] as? String, "start")
    XCTAssertEqual(pending?["snapshotGeneratedAt"] as? String, generatedAt)
    XCTAssertNotNil(pending?["requestId"] as? String)
    XCTAssertNotNil(commandStore.take(now: now))
    XCTAssertNil(commandStore.take(now: now))
  }

  func testDisallowedActionDoesNotConsumeTheCapability() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let currentToken = tryUnwrap(snapshotStore.loadControlToken())

    XCTAssertFalse(
      commandStore.enqueue(
        url: commandURL(action: .pause, token: currentToken),
        now: now
      )
    )
    XCTAssertEqual(snapshotStore.loadControlToken(), currentToken)
    XCTAssertTrue(
      commandStore.enqueue(
        url: commandURL(action: .start, token: currentToken),
        now: now
      )
    )
  }

  func testNewSnapshotInvalidatesPreviouslyRenderedLinks() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let oldToken = tryUnwrap(snapshotStore.loadControlToken())
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let newToken = tryUnwrap(snapshotStore.loadControlToken())

    XCTAssertNotEqual(oldToken, newToken)
    XCTAssertFalse(
      commandStore.enqueue(
        url: commandURL(action: .start, token: oldToken),
        now: now
      )
    )
    XCTAssertTrue(
      commandStore.enqueue(
        url: commandURL(action: .start, token: newToken),
        now: now
      )
    )
  }

  func testExpiredPendingCommandIsRemoved() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let currentToken = tryUnwrap(snapshotStore.loadControlToken())
    XCTAssertTrue(
      commandStore.enqueue(
        url: commandURL(action: .start, token: currentToken),
        now: now.addingTimeInterval(-121)
      )
    )

    XCTAssertNil(commandStore.peek(now: now))
    XCTAssertNil(commandStore.take(now: now))
  }

  func testSharedURLHandlerQueuesBeforeRequestingWarmDelivery() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let currentToken = tryUnwrap(snapshotStore.loadControlToken())
    var deliveryCount = 0
    let handler = SystemFocusURLCommandHandler(
      pendingCommands: commandStore,
      deliverPendingCommand: { deliveryCount += 1 }
    )

    XCTAssertTrue(
      handler.handle(
        url: commandURL(action: .start, token: currentToken),
        now: now
      )
    )
    XCTAssertEqual(deliveryCount, 1)
    XCTAssertEqual(commandStore.peek(now: now)?["action"] as? String, "start")

    XCTAssertFalse(
      handler.handle(
        url: commandURL(action: .start, token: currentToken),
        now: now
      )
    )
    XCTAssertEqual(deliveryCount, 1)
  }

  func testColdSceneCanQueueBeforeFlutterAdapterDelivery() {
    XCTAssertTrue(snapshotStore.save(snapshot(activity: "ready")))
    let currentToken = tryUnwrap(snapshotStore.loadControlToken())
    var deliveryCount = 0
    let handler = SystemFocusURLCommandHandler(
      pendingCommands: commandStore,
      deliverPendingCommand: { deliveryCount += 1 }
    )

    XCTAssertTrue(
      handler.enqueue(
        url: commandURL(action: .start, token: currentToken),
        now: now
      )
    )
    XCTAssertEqual(deliveryCount, 0)
    XCTAssertEqual(commandStore.peek(now: now)?["action"] as? String, "start")

    handler.deliverIfAvailable()

    XCTAssertEqual(deliveryCount, 1)
    XCTAssertEqual(commandStore.peek(now: now)?["action"] as? String, "start")
  }

  private func snapshot(activity: String) -> [String: Any] {
    let completed = activity == "completed"
    return [
      "schemaVersion": 1,
      "session": "focus",
      "activity": activity,
      "secondsRemaining": completed ? 0 : 300,
      "totalSessionSeconds": 300,
      "generatedAt": generatedAt,
      "endsAt": activity == "running"
        ? "2026-08-16T21:05:00.000Z"
        : NSNull(),
    ]
  }

  private func commandURL(
    action: SystemFocusWidgetAction,
    token: String
  ) -> URL {
    var components = URLComponents()
    components.scheme = "focushaven"
    components.host = "system-focus-command"
    components.queryItems = [
      URLQueryItem(name: "action", value: action.rawValue),
      URLQueryItem(name: "snapshotGeneratedAt", value: generatedAt),
      URLQueryItem(name: "controlToken", value: token),
    ]
    return components.url!
  }

  private func tryUnwrap<T>(_ value: T?) -> T {
    guard let value else {
      XCTFail("Expected a non-null test value")
      fatalError("Missing test value")
    }
    return value
  }
}
