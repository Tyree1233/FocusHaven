import XCTest

@testable import Runner

@MainActor
final class HavenSystemAssistantAppleIngressTests: XCTestCase {
  func testRouteAllowlistContainsExactlyFiveTextFreeKinds() {
    XCTAssertEqual(
      HavenSystemAssistantAppleRoute.allCases.map(\.rawValue),
      [
        "readTimerStatus",
        "startFocusTimer",
        "pauseTimer",
        "resumeTimer",
        "openFocusQueue",
      ]
    )
  }

  func testPayloadContainsOnlyVersionOpaqueIDAndKind() throws {
    let request = try XCTUnwrap(
      HavenSystemAssistantAppleRequest(
        invocationID: "apple-request_1",
        kind: .startFocusTimer
      )
    )

    XCTAssertEqual(
      Set(request.dictionary.keys),
      ["schemaVersion", "invocationId", "kind"]
    )
    XCTAssertEqual(request.dictionary["schemaVersion"] as? Int, 1)
    XCTAssertEqual(
      request.dictionary["invocationId"] as? String,
      "apple-request_1"
    )
    XCTAssertEqual(request.dictionary["kind"] as? String, "startFocusTimer")
    XCTAssertNil(request.dictionary["transcript"])
    XCTAssertNil(request.dictionary["utterance"])
    XCTAssertNil(request.dictionary["task"])
    XCTAssertNil(request.dictionary["duration"])
  }

  func testMalformedInvocationIDsAreRejected() {
    let invalidIDs = [
      "",
      " leading-space",
      "contains/slash",
      String(repeating: "a", count: 129),
      "private-🗒️",
    ]
    for invocationID in invalidIDs {
      XCTAssertNil(
        HavenSystemAssistantAppleRequest(
          invocationID: invocationID,
          kind: .readTimerStatus
        )
      )
    }
  }

  func testStoreRejectsStackingAndRequiresExactAcknowledgement() {
    let store = HavenSystemAssistantApplePendingRequestStore()

    XCTAssertTrue(store.submit(kind: .pauseTimer, invocationID: "first"))
    XCTAssertFalse(store.submit(kind: .resumeTimer, invocationID: "second"))
    XCTAssertEqual(store.peek()?.invocationID, "first")
    XCTAssertFalse(store.clearIfMatches(invocationID: "different"))
    XCTAssertEqual(store.peek()?.kind, .pauseTimer)
    XCTAssertTrue(store.clearIfMatches(invocationID: "first"))
    XCTAssertNil(store.peek())
  }
}
