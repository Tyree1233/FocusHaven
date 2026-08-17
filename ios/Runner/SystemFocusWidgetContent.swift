import Foundation

enum SystemFocusWidgetSession: String, CaseIterable {
  case focus
  case shortBreak
  case longBreak

  var title: String {
    switch self {
    case .focus: return "Focus"
    case .shortBreak: return "Short break"
    case .longBreak: return "Long break"
    }
  }
}

enum SystemFocusWidgetActivity: String, CaseIterable {
  case ready
  case running
  case paused
  case completed
  case pendingResume

  var title: String {
    switch self {
    case .ready: return "Ready when you are"
    case .running: return "Steady focus"
    case .paused: return "Paused"
    case .completed: return "Session complete"
    case .pendingResume: return "Ready to continue"
    }
  }
}

/// Text-free presentation derived only from a validated system-focus snapshot.
struct SystemFocusWidgetContent: Equatable {
  let session: SystemFocusWidgetSession
  let activity: SystemFocusWidgetActivity
  let secondsRemaining: Int
  let totalSessionSeconds: Int
  let endsAt: Date?

  var completedSeconds: Int {
    min(max(totalSessionSeconds - secondsRemaining, 0), totalSessionSeconds)
  }

  var progress: Double {
    Double(completedSeconds) / Double(totalSessionSeconds)
  }

  static func fromSnapshot(
    _ snapshot: [String: Any]?,
    now: Date = Date()
  ) -> SystemFocusWidgetContent? {
    guard let snapshot,
      let sessionText = snapshot["session"] as? String,
      let session = SystemFocusWidgetSession(rawValue: sessionText),
      let activityText = snapshot["activity"] as? String,
      let activity = SystemFocusWidgetActivity(rawValue: activityText),
      let remainingNumber = snapshot["secondsRemaining"] as? NSNumber,
      let totalNumber = snapshot["totalSessionSeconds"] as? NSNumber,
      CFGetTypeID(remainingNumber) != CFBooleanGetTypeID(),
      CFGetTypeID(totalNumber) != CFBooleanGetTypeID(),
      !CFNumberIsFloatType(remainingNumber),
      !CFNumberIsFloatType(totalNumber)
    else {
      return nil
    }

    let storedRemaining = remainingNumber.intValue
    let total = totalNumber.intValue
    guard total > 0, storedRemaining >= 0, storedRemaining <= total else {
      return nil
    }

    if activity != .running {
      guard snapshot["endsAt"] is NSNull else { return nil }
      return SystemFocusWidgetContent(
        session: session,
        activity: activity,
        secondsRemaining: storedRemaining,
        totalSessionSeconds: total,
        endsAt: nil
      )
    }

    guard let deadlineText = snapshot["endsAt"] as? String,
      let deadline = utcDate(deadlineText)
    else {
      return nil
    }
    if deadline <= now {
      return SystemFocusWidgetContent(
        session: session,
        activity: .completed,
        secondsRemaining: 0,
        totalSessionSeconds: total,
        endsAt: nil
      )
    }

    let liveRemaining = min(max(Int(ceil(deadline.timeIntervalSince(now))), 1), total)
    return SystemFocusWidgetContent(
      session: session,
      activity: .running,
      secondsRemaining: liveRemaining,
      totalSessionSeconds: total,
      endsAt: deadline
    )
  }

  private static func utcDate(_ value: String) -> Date? {
    guard value.hasSuffix("Z") else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = formatter.date(from: value) {
      return parsed
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}
