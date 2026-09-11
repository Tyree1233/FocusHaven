import AppIntents
import Foundation

/// The only outcomes an Apple system surface may report before in-app review.
enum HavenSystemAssistantAppleSubmissionOutcome: Equatable {
  case readyForReview
  case pendingRequest
  case unavailable

  @available(iOS 16.0, *)
  var dialog: IntentDialog {
    switch self {
    case .readyForReview:
      IntentDialog(
        LocalizedStringResource(
          "appleSystemAssistantNativeReviewRequiredResult",
          defaultValue:
            "Open FocusHaven to review this request. Nothing has happened yet.",
          table: HavenSystemAssistantAppleNativeCopy.tableName
        )
      )
    case .pendingRequest:
      IntentDialog(
        LocalizedStringResource(
          "appleSystemAssistantNativePendingRequestResult",
          defaultValue:
            "FocusHaven already has a request waiting. Open the app to review or dismiss it before trying again.",
          table: HavenSystemAssistantAppleNativeCopy.tableName
        )
      )
    case .unavailable:
      IntentDialog(
        LocalizedStringResource(
          "appleSystemAssistantNativeUnavailableResult",
          defaultValue: "This FocusHaven request is unavailable. Nothing changed.",
          table: HavenSystemAssistantAppleNativeCopy.tableName
        )
      )
    }
  }
}

/// A narrow registration seam that can enqueue only the existing text-free
/// Phase 217E request. It cannot read timer or queue state, prepare a review,
/// confirm a proposal, or execute a Haven Action.
@MainActor
enum HavenSystemAssistantAppleIntentSubmission {
  static func submit(
    route: HavenSystemAssistantAppleRoute,
    invocationID: String = UUID().uuidString,
    store: HavenSystemAssistantApplePendingRequestStore? = nil,
    copy: HavenSystemAssistantAppleNativeCopy = HavenSystemAssistantAppleNativeCopy()
  ) -> HavenSystemAssistantAppleSubmissionOutcome {
    let routeCopy = route.nativeCopyKeys
    let requiredKeys = [
      routeCopy.title,
      routeCopy.description,
      routeCopy.phrase,
      .reviewRequiredResult,
      .pendingRequestResult,
      .unavailableResult,
    ]
    guard requiredKeys.allSatisfy({ copy.text(for: $0) != nil }) else {
      return .unavailable
    }
    guard
      HavenSystemAssistantAppleRequest(
        invocationID: invocationID,
        kind: route
      ) != nil
    else {
      return .unavailable
    }
    guard
      (store ?? .shared).submit(kind: route, invocationID: invocationID)
    else {
      return .pendingRequest
    }
    NotificationCenter.default.post(
      name: .havenSystemAssistantAppleRequestSubmitted,
      object: nil
    )
    return .readyForReview
  }
}

@available(iOS 16.0, *)
struct HavenReadTimerStatusAppIntent: AppIntent {
  static let title = LocalizedStringResource(
    "appleSystemAssistantNativeReadTimerStatusTitle",
    defaultValue: "Check Focus timer status",
    table: HavenSystemAssistantAppleNativeCopy.tableName
  )
  static let description = IntentDescription(
    LocalizedStringResource(
      "appleSystemAssistantNativeReadTimerStatusDescription",
      defaultValue:
        "Prepare a request to review the current Focus timer status in FocusHaven.",
      table: HavenSystemAssistantAppleNativeCopy.tableName
    )
  )
  static let openAppWhenRun = true
  static let authenticationPolicy: IntentAuthenticationPolicy =
    .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(
      dialog: HavenSystemAssistantAppleIntentSubmission.submit(
        route: .readTimerStatus
      ).dialog
    )
  }
}

@available(iOS 16.0, *)
struct HavenStartFocusTimerAppIntent: AppIntent {
  static let title = LocalizedStringResource(
    "appleSystemAssistantNativeStartFocusTimerTitle",
    defaultValue: "Start Focus timer",
    table: HavenSystemAssistantAppleNativeCopy.tableName
  )
  static let description = IntentDescription(
    LocalizedStringResource(
      "appleSystemAssistantNativeStartFocusTimerDescription",
      defaultValue:
        "Prepare a request to review starting the ready Focus session in FocusHaven.",
      table: HavenSystemAssistantAppleNativeCopy.tableName
    )
  )
  static let openAppWhenRun = true
  static let authenticationPolicy: IntentAuthenticationPolicy =
    .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(
      dialog: HavenSystemAssistantAppleIntentSubmission.submit(
        route: .startFocusTimer
      ).dialog
    )
  }
}

@available(iOS 16.0, *)
struct HavenPauseTimerAppIntent: AppIntent {
  static let title = LocalizedStringResource(
    "appleSystemAssistantNativePauseTimerTitle",
    defaultValue: "Pause Focus timer",
    table: HavenSystemAssistantAppleNativeCopy.tableName
  )
  static let description = IntentDescription(
    LocalizedStringResource(
      "appleSystemAssistantNativePauseTimerDescription",
      defaultValue:
        "Prepare a request to review pausing the current Focus timer in FocusHaven.",
      table: HavenSystemAssistantAppleNativeCopy.tableName
    )
  )
  static let openAppWhenRun = true
  static let authenticationPolicy: IntentAuthenticationPolicy =
    .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(
      dialog: HavenSystemAssistantAppleIntentSubmission.submit(
        route: .pauseTimer
      ).dialog
    )
  }
}

@available(iOS 16.0, *)
struct HavenResumeTimerAppIntent: AppIntent {
  static let title = LocalizedStringResource(
    "appleSystemAssistantNativeResumeTimerTitle",
    defaultValue: "Resume Focus timer",
    table: HavenSystemAssistantAppleNativeCopy.tableName
  )
  static let description = IntentDescription(
    LocalizedStringResource(
      "appleSystemAssistantNativeResumeTimerDescription",
      defaultValue:
        "Prepare a request to review resuming the paused Focus timer in FocusHaven.",
      table: HavenSystemAssistantAppleNativeCopy.tableName
    )
  )
  static let openAppWhenRun = true
  static let authenticationPolicy: IntentAuthenticationPolicy =
    .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(
      dialog: HavenSystemAssistantAppleIntentSubmission.submit(
        route: .resumeTimer
      ).dialog
    )
  }
}

@available(iOS 16.0, *)
struct HavenOpenFocusQueueAppIntent: AppIntent {
  static let title = LocalizedStringResource(
    "appleSystemAssistantNativeOpenFocusQueueTitle",
    defaultValue: "Open Focus Queue",
    table: HavenSystemAssistantAppleNativeCopy.tableName
  )
  static let description = IntentDescription(
    LocalizedStringResource(
      "appleSystemAssistantNativeOpenFocusQueueDescription",
      defaultValue:
        "Prepare a request to review opening Focus Queue in FocusHaven.",
      table: HavenSystemAssistantAppleNativeCopy.tableName
    )
  )
  static let openAppWhenRun = true
  static let authenticationPolicy: IntentAuthenticationPolicy =
    .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(
      dialog: HavenSystemAssistantAppleIntentSubmission.submit(
        route: .openFocusQueue
      ).dialog
    )
  }
}

/// Five parameter-free shortcuts backed only by the reviewed Phase 217F copy.
@available(iOS 16.0, *)
struct HavenSystemAssistantAppleShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: HavenReadTimerStatusAppIntent(),
      phrases: ["Review my Focus timer status in \(.applicationName)"],
      shortTitle: LocalizedStringResource(
        "appleSystemAssistantNativeReadTimerStatusTitle",
        defaultValue: "Check Focus timer status",
        table: "AppleSystemAssistantNativeCopy"
      ),
      systemImageName: "timer"
    )
    AppShortcut(
      intent: HavenStartFocusTimerAppIntent(),
      phrases: ["Review starting a Focus timer in \(.applicationName)"],
      shortTitle: LocalizedStringResource(
        "appleSystemAssistantNativeStartFocusTimerTitle",
        defaultValue: "Start Focus timer",
        table: "AppleSystemAssistantNativeCopy"
      ),
      systemImageName: "play.circle"
    )
    AppShortcut(
      intent: HavenPauseTimerAppIntent(),
      phrases: ["Review pausing my Focus timer in \(.applicationName)"],
      shortTitle: LocalizedStringResource(
        "appleSystemAssistantNativePauseTimerTitle",
        defaultValue: "Pause Focus timer",
        table: "AppleSystemAssistantNativeCopy"
      ),
      systemImageName: "pause.circle"
    )
    AppShortcut(
      intent: HavenResumeTimerAppIntent(),
      phrases: ["Review resuming my Focus timer in \(.applicationName)"],
      shortTitle: LocalizedStringResource(
        "appleSystemAssistantNativeResumeTimerTitle",
        defaultValue: "Resume Focus timer",
        table: "AppleSystemAssistantNativeCopy"
      ),
      systemImageName: "play.circle"
    )
    AppShortcut(
      intent: HavenOpenFocusQueueAppIntent(),
      phrases: ["Review opening Focus Queue in \(.applicationName)"],
      shortTitle: LocalizedStringResource(
        "appleSystemAssistantNativeOpenFocusQueueTitle",
        defaultValue: "Open Focus Queue",
        table: "AppleSystemAssistantNativeCopy"
      ),
      systemImageName: "list.bullet"
    )
  }

  static var shortcutTileColor: ShortcutTileColor { .teal }
}

@available(iOS 16.0, *)
enum HavenSystemAssistantAppleAppShortcutRegistration {
  static func updateParameters() {
    HavenSystemAssistantAppleShortcuts.updateAppShortcutParameters()
  }
}
