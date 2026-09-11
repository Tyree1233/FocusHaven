import Foundation

/// Stable keys for the completely reviewed Apple-native System Assistant copy.
///
/// This type provides localized text only. It does not declare an App Intent,
/// publish an App Shortcut, submit a request, or execute a Haven Action.
enum HavenSystemAssistantAppleNativeCopyKey: String, CaseIterable {
  case collectionTitle = "appleSystemAssistantNativeCollectionTitle"
  case discoveryDescription = "appleSystemAssistantNativeDiscoveryDescription"
  case privacySummary = "appleSystemAssistantNativePrivacySummary"
  case noParametersSummary = "appleSystemAssistantNativeNoParametersSummary"
  case reviewInstruction = "appleSystemAssistantNativeReviewInstruction"

  case readTimerStatusTitle = "appleSystemAssistantNativeReadTimerStatusTitle"
  case readTimerStatusDescription = "appleSystemAssistantNativeReadTimerStatusDescription"
  case readTimerStatusPhrase = "appleSystemAssistantNativeReadTimerStatusPhrase"
  case startFocusTimerTitle = "appleSystemAssistantNativeStartFocusTimerTitle"
  case startFocusTimerDescription = "appleSystemAssistantNativeStartFocusTimerDescription"
  case startFocusTimerPhrase = "appleSystemAssistantNativeStartFocusTimerPhrase"
  case pauseTimerTitle = "appleSystemAssistantNativePauseTimerTitle"
  case pauseTimerDescription = "appleSystemAssistantNativePauseTimerDescription"
  case pauseTimerPhrase = "appleSystemAssistantNativePauseTimerPhrase"
  case resumeTimerTitle = "appleSystemAssistantNativeResumeTimerTitle"
  case resumeTimerDescription = "appleSystemAssistantNativeResumeTimerDescription"
  case resumeTimerPhrase = "appleSystemAssistantNativeResumeTimerPhrase"
  case openFocusQueueTitle = "appleSystemAssistantNativeOpenFocusQueueTitle"
  case openFocusQueueDescription = "appleSystemAssistantNativeOpenFocusQueueDescription"
  case openFocusQueuePhrase = "appleSystemAssistantNativeOpenFocusQueuePhrase"

  case reviewRequiredResult = "appleSystemAssistantNativeReviewRequiredResult"
  case pendingRequestResult = "appleSystemAssistantNativePendingRequestResult"
  case unavailableResult = "appleSystemAssistantNativeUnavailableResult"
  case cancelledResult = "appleSystemAssistantNativeCancelledResult"
  case expiredResult = "appleSystemAssistantNativeExpiredResult"
  case rejectedResult = "appleSystemAssistantNativeRejectedResult"
  case reviewRequiredAccessibilityLabel =
    "appleSystemAssistantNativeReviewRequiredAccessibilityLabel"
  case pendingRequestAccessibilityLabel =
    "appleSystemAssistantNativePendingRequestAccessibilityLabel"

  var requiresApplicationName: Bool {
    switch self {
    case .readTimerStatusPhrase,
         .startFocusTimerPhrase,
         .pauseTimerPhrase,
         .resumeTimerPhrase,
         .openFocusQueuePhrase:
      true
    default:
      false
    }
  }
}

/// Exact title, description, and invocation-phrase keys for one allowed route.
struct HavenSystemAssistantAppleNativeRouteCopyKeys: Equatable {
  let title: HavenSystemAssistantAppleNativeCopyKey
  let description: HavenSystemAssistantAppleNativeCopyKey
  let phrase: HavenSystemAssistantAppleNativeCopyKey
}

extension HavenSystemAssistantAppleRoute {
  var nativeCopyKeys: HavenSystemAssistantAppleNativeRouteCopyKeys {
    switch self {
    case .readTimerStatus:
      HavenSystemAssistantAppleNativeRouteCopyKeys(
        title: .readTimerStatusTitle,
        description: .readTimerStatusDescription,
        phrase: .readTimerStatusPhrase
      )
    case .startFocusTimer:
      HavenSystemAssistantAppleNativeRouteCopyKeys(
        title: .startFocusTimerTitle,
        description: .startFocusTimerDescription,
        phrase: .startFocusTimerPhrase
      )
    case .pauseTimer:
      HavenSystemAssistantAppleNativeRouteCopyKeys(
        title: .pauseTimerTitle,
        description: .pauseTimerDescription,
        phrase: .pauseTimerPhrase
      )
    case .resumeTimer:
      HavenSystemAssistantAppleNativeRouteCopyKeys(
        title: .resumeTimerTitle,
        description: .resumeTimerDescription,
        phrase: .resumeTimerPhrase
      )
    case .openFocusQueue:
      HavenSystemAssistantAppleNativeRouteCopyKeys(
        title: .openFocusQueueTitle,
        description: .openFocusQueueDescription,
        phrase: .openFocusQueuePhrase
      )
    }
  }
}

/// Fail-closed access to the reviewed Runner-local String Catalog.
struct HavenSystemAssistantAppleNativeCopy {
  static let tableName = "AppleSystemAssistantNativeCopy"
  static let maximumApplicationNameUTF8Length = 128

  private let formatLookup: (String) -> String?

  init(bundle: Bundle = .main) {
    formatLookup = { key in
      let missingValue = "__focushaven_missing_\(key)__"
      let value = bundle.localizedString(
        forKey: key,
        value: missingValue,
        table: Self.tableName
      )
      return value == missingValue ? nil : value
    }
  }

  init(formatLookup: @escaping (String) -> String?) {
    self.formatLookup = formatLookup
  }

  func text(
    for key: HavenSystemAssistantAppleNativeCopyKey,
    applicationName: String = "FocusHaven"
  ) -> String? {
    guard let format = formatLookup(key.rawValue),
      Self.isValid(format: format, for: key)
    else {
      return nil
    }
    guard key.requiresApplicationName else { return format }
    guard Self.isValid(applicationName: applicationName) else { return nil }
    return String(format: format, applicationName)
  }

  static func isValid(
    format: String,
    for key: HavenSystemAssistantAppleNativeCopyKey
  ) -> Bool {
    guard !format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !format.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    else {
      return false
    }
    let expectedPlaceholderCount = key.requiresApplicationName ? 1 : 0
    let placeholderCount = format.components(separatedBy: "%@").count - 1
    guard placeholderCount == expectedPlaceholderCount else { return false }
    return format.replacingOccurrences(of: "%@", with: "").contains("%") == false
  }

  private static func isValid(applicationName: String) -> Bool {
    let trimmed = applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed == applicationName &&
      !trimmed.isEmpty &&
      trimmed.utf8.count <= maximumApplicationNameUTF8Length &&
      !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
  }
}
