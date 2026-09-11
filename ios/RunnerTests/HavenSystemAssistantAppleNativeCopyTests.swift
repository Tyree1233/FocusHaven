import XCTest

@testable import Runner

final class HavenSystemAssistantAppleNativeCopyTests: XCTestCase {
  func testCopyAllowlistContainsExactlyTwentyEightReviewedKeys() {
    XCTAssertEqual(HavenSystemAssistantAppleNativeCopyKey.allCases.count, 28)
    XCTAssertEqual(
      Set(HavenSystemAssistantAppleNativeCopyKey.allCases.map(\.rawValue)).count,
      28
    )
    XCTAssertTrue(
      HavenSystemAssistantAppleNativeCopyKey.allCases.allSatisfy {
        $0.rawValue.hasPrefix("appleSystemAssistantNative")
      }
    )
  }

  func testExactlyFiveRoutePhrasesRequireApplicationName() {
    XCTAssertEqual(
      HavenSystemAssistantAppleNativeCopyKey.allCases
        .filter(\.requiresApplicationName),
      [
        .readTimerStatusPhrase,
        .startFocusTimerPhrase,
        .pauseTimerPhrase,
        .resumeTimerPhrase,
        .openFocusQueuePhrase,
      ]
    )
  }

  func testEveryTextFreeRouteMapsToOneTitleDescriptionAndPhrase() {
    let mappings = HavenSystemAssistantAppleRoute.allCases.map(\.nativeCopyKeys)

    XCTAssertEqual(mappings.count, 5)
    XCTAssertEqual(Set(mappings.map(\.title)).count, 5)
    XCTAssertEqual(Set(mappings.map(\.description)).count, 5)
    XCTAssertEqual(Set(mappings.map(\.phrase)).count, 5)
    XCTAssertTrue(mappings.allSatisfy { !$0.title.requiresApplicationName })
    XCTAssertTrue(mappings.allSatisfy { !$0.description.requiresApplicationName })
    XCTAssertTrue(mappings.allSatisfy { $0.phrase.requiresApplicationName })
  }

  func testReviewedFormatSubstitutesOnlyTheApplicationName() {
    let copy = HavenSystemAssistantAppleNativeCopy { key in
      key == HavenSystemAssistantAppleNativeCopyKey.startFocusTimerPhrase.rawValue
        ? "Review starting a Focus timer in %@"
        : nil
    }

    XCTAssertEqual(
      copy.text(for: .startFocusTimerPhrase, applicationName: "FocusHaven"),
      "Review starting a Focus timer in FocusHaven"
    )
    XCTAssertNil(copy.text(for: .collectionTitle))
  }

  func testMalformedFormatsAndApplicationNamesFailClosed() {
    XCTAssertFalse(
      HavenSystemAssistantAppleNativeCopy.isValid(
        format: "Review in %@ %@",
        for: .readTimerStatusPhrase
      )
    )
    XCTAssertFalse(
      HavenSystemAssistantAppleNativeCopy.isValid(
        format: "Review in %d",
        for: .readTimerStatusPhrase
      )
    )
    XCTAssertFalse(
      HavenSystemAssistantAppleNativeCopy.isValid(
        format: "Unexpected %@",
        for: .collectionTitle
      )
    )
    XCTAssertFalse(
      HavenSystemAssistantAppleNativeCopy.isValid(
        format: "\n",
        for: .collectionTitle
      )
    )

    let copy = HavenSystemAssistantAppleNativeCopy { _ in "Review in %@" }
    XCTAssertNil(copy.text(for: .readTimerStatusPhrase, applicationName: ""))
    XCTAssertNil(copy.text(for: .readTimerStatusPhrase, applicationName: " FocusHaven"))
    XCTAssertNil(
      copy.text(
        for: .readTimerStatusPhrase,
        applicationName: String(repeating: "a", count: 129)
      )
    )
  }

  func testAccessorOwnsCopyOnlyAndCannotSubmitARequest() {
    let source = try? String(
      contentsOf: URL(
        fileURLWithPath: #filePath
      )
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Runner/HavenSystemAssistantAppleNativeCopy.swift")
    )

    XCTAssertNotNil(source)
    XCTAssertFalse(source?.contains("import AppIntents") ?? true)
    XCTAssertFalse(source?.contains("AppIntent") ?? true)
    XCTAssertFalse(source?.contains("AppShortcutsProvider") ?? true)
    XCTAssertFalse(source?.contains(".submit(") ?? true)
    XCTAssertFalse(source?.contains("FlutterMethodChannel") ?? true)
  }
}
