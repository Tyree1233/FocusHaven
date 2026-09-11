import XCTest

@testable import Runner

@MainActor
final class HavenSystemAssistantAppleAppIntentsTests: XCTestCase {
  private static let completeCopy = HavenSystemAssistantAppleNativeCopy { key in
    switch HavenSystemAssistantAppleNativeCopyKey(rawValue: key) {
    case .readTimerStatusTitle:
      "Check Focus timer status"
    case .readTimerStatusDescription:
      "Prepare a request to review the current Focus timer status in FocusHaven."
    case .readTimerStatusPhrase:
      "Review my Focus timer status in %@"
    case .startFocusTimerTitle:
      "Start Focus timer"
    case .startFocusTimerDescription:
      "Prepare a request to review starting the ready Focus session in FocusHaven."
    case .startFocusTimerPhrase:
      "Review starting a Focus timer in %@"
    case .pauseTimerTitle:
      "Pause Focus timer"
    case .pauseTimerDescription:
      "Prepare a request to review pausing the current Focus timer in FocusHaven."
    case .pauseTimerPhrase:
      "Review pausing my Focus timer in %@"
    case .resumeTimerTitle:
      "Resume Focus timer"
    case .resumeTimerDescription:
      "Prepare a request to review resuming the paused Focus timer in FocusHaven."
    case .resumeTimerPhrase:
      "Review resuming my Focus timer in %@"
    case .openFocusQueueTitle:
      "Open Focus Queue"
    case .openFocusQueueDescription:
      "Prepare a request to review opening Focus Queue in FocusHaven."
    case .openFocusQueuePhrase:
      "Review opening Focus Queue in %@"
    case .reviewRequiredResult:
      "Open FocusHaven to review this request. Nothing has happened yet."
    case .pendingRequestResult:
      "FocusHaven already has a request waiting. Open the app to review or dismiss it before trying again."
    case .unavailableResult:
      "This FocusHaven request is unavailable. Nothing changed."
    default:
      nil
    }
  }

  func testEveryRouteSubmitsOnlyTheExactThreeFieldRequest() throws {
    for (index, route) in HavenSystemAssistantAppleRoute.allCases.enumerated() {
      let store = HavenSystemAssistantApplePendingRequestStore()
      let invocationID = "app-intent-\(index)"
      let submitted = expectation(
        forNotification: .havenSystemAssistantAppleRequestSubmitted,
        object: nil
      )

      XCTAssertEqual(
        HavenSystemAssistantAppleIntentSubmission.submit(
          route: route,
          invocationID: invocationID,
          store: store,
          copy: Self.completeCopy
        ),
        .readyForReview
      )
      wait(for: [submitted], timeout: 0.1)
      let request = try XCTUnwrap(store.peek())
      XCTAssertEqual(request.invocationID, invocationID)
      XCTAssertEqual(request.kind, route)
      XCTAssertEqual(
        Set(request.dictionary.keys),
        ["schemaVersion", "invocationId", "kind"]
      )
      XCTAssertNil(request.dictionary["transcript"])
      XCTAssertNil(request.dictionary["utterance"])
      XCTAssertNil(request.dictionary["duration"])
      XCTAssertNil(request.dictionary["task"])
    }
  }

  func testOccupiedSlotIsPreservedAndReportedAsPending() throws {
    let store = HavenSystemAssistantApplePendingRequestStore()
    XCTAssertTrue(
      store.submit(kind: .pauseTimer, invocationID: "existing-request")
    )

    XCTAssertEqual(
      HavenSystemAssistantAppleIntentSubmission.submit(
        route: .resumeTimer,
        invocationID: "new-request",
        store: store,
        copy: Self.completeCopy
      ),
      .pendingRequest
    )
    let request = try XCTUnwrap(store.peek())
    XCTAssertEqual(request.invocationID, "existing-request")
    XCTAssertEqual(request.kind, .pauseTimer)
  }

  func testMissingReviewedCopyFailsBeforeSubmission() {
    let store = HavenSystemAssistantApplePendingRequestStore()
    let incompleteCopy = HavenSystemAssistantAppleNativeCopy { key in
      key == HavenSystemAssistantAppleNativeCopyKey.pauseTimerTitle.rawValue
        ? "Pause Focus timer"
        : nil
    }

    XCTAssertEqual(
      HavenSystemAssistantAppleIntentSubmission.submit(
        route: .pauseTimer,
        invocationID: "must-not-submit",
        store: store,
        copy: incompleteCopy
      ),
      .unavailable
    )
    XCTAssertFalse(store.hasPendingRequest)
  }

  func testInvalidInvocationIDFailsWithoutChangingTheSlot() {
    let store = HavenSystemAssistantApplePendingRequestStore()

    XCTAssertEqual(
      HavenSystemAssistantAppleIntentSubmission.submit(
        route: .openFocusQueue,
        invocationID: "invalid/request",
        store: store,
        copy: Self.completeCopy
      ),
      .unavailable
    )
    XCTAssertFalse(store.hasPendingRequest)
  }

  func testRegistrationMetadataContainsExactlyFiveParameterFreeRoutes() {
    if #available(iOS 16.0, *) {
      XCTAssertEqual(HavenSystemAssistantAppleShortcuts.appShortcuts.count, 5)
      XCTAssertTrue(HavenReadTimerStatusAppIntent.openAppWhenRun)
      XCTAssertTrue(HavenStartFocusTimerAppIntent.openAppWhenRun)
      XCTAssertTrue(HavenPauseTimerAppIntent.openAppWhenRun)
      XCTAssertTrue(HavenResumeTimerAppIntent.openAppWhenRun)
      XCTAssertTrue(HavenOpenFocusQueueAppIntent.openAppWhenRun)
    }
  }
}
