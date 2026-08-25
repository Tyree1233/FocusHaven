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

enum SystemFocusWidgetAction: String, CaseIterable {
  case start
  case pause
  case resume
  case reset
  case beginNextSession
  case discardPending

  var title: String {
    switch self {
    case .start: return "Start"
    case .pause: return "Pause"
    case .resume: return "Resume"
    case .reset: return "Reset"
    case .beginNextSession: return "Next session"
    case .discardPending: return "Discard"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .start: return "Start FocusHaven timer"
    case .pause: return "Pause FocusHaven timer"
    case .resume: return "Resume FocusHaven timer"
    case .reset: return "Reset FocusHaven timer"
    case .beginNextSession: return "Begin next FocusHaven session"
    case .discardPending: return "Discard paused FocusHaven timer"
    }
  }
}

/// Text-free presentation derived only from a validated system-focus snapshot.
struct SystemFocusWidgetContent: Equatable {
  let session: SystemFocusWidgetSession
  let activity: SystemFocusWidgetActivity
  let secondsRemaining: Int
  let totalSessionSeconds: Int
  let snapshotGeneratedAt: String
  let endsAt: Date?
  let availableActions: Set<SystemFocusWidgetAction>

  var completedSeconds: Int {
    min(max(totalSessionSeconds - secondsRemaining, 0), totalSessionSeconds)
  }

  var progress: Double {
    Double(completedSeconds) / Double(totalSessionSeconds)
  }

  var progressPercent: Int {
    min(max(Int((progress * 100).rounded()), 0), 100)
  }

  var clockText: String {
    Self.clockText(secondsRemaining)
  }

  var compactDurationText: String {
    Self.compactDurationText(secondsRemaining)
  }

  var accessibilitySummary: String {
    let duration = Self.accessibleDuration(secondsRemaining)
    let timing: String
    if activity == .running {
      timing = "Live countdown, \(duration) remaining at last update."
    } else {
      timing = "\(duration) remaining."
    }
    return "\(session.title). \(activity.title). \(timing) \(progressPercent) percent complete."
  }

  static func accessibleDuration(_ seconds: Int) -> String {
    let bounded = max(seconds, 0)
    let hours = bounded / 3_600
    let minutes = (bounded % 3_600) / 60
    let remainder = bounded % 60
    var parts: [String] = []
    if hours > 0 {
      parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
    }
    if minutes > 0 {
      parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
    }
    if remainder > 0 || parts.isEmpty {
      parts.append("\(remainder) \(remainder == 1 ? "second" : "seconds")")
    }
    return parts.joined(separator: ", ")
  }

  static func clockText(_ seconds: Int) -> String {
    let bounded = max(seconds, 0)
    let hours = bounded / 3_600
    let minutes = (bounded % 3_600) / 60
    let remainder = bounded % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%d:%02d", minutes, remainder)
  }

  static func compactDurationText(_ seconds: Int) -> String {
    let bounded = max(seconds, 0)
    if bounded >= 3_600 {
      let hours = bounded / 3_600
      let secondsAfterHour = bounded % 3_600
      let remainingMinutes =
        secondsAfterHour / 60 + (secondsAfterHour % 60 == 0 ? 0 : 1)
      if remainingMinutes == 60 {
        return "\(hours + 1)h"
      }
      if remainingMinutes > 0 {
        return "\(hours)h \(remainingMinutes)m"
      }
      return "\(hours)h"
    }
    if bounded >= 60 {
      let roundedMinutes = bounded / 60 + (bounded % 60 == 0 ? 0 : 1)
      return "\(roundedMinutes)m"
    }
    return "\(bounded)s"
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
      let generatedAtText = snapshot["generatedAt"] as? String,
      utcDate(generatedAtText) != nil,
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
        snapshotGeneratedAt: generatedAtText,
        endsAt: nil,
        availableActions: actions(for: activity)
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
        snapshotGeneratedAt: generatedAtText,
        endsAt: nil,
        availableActions: []
      )
    }

    let liveRemaining = min(max(Int(ceil(deadline.timeIntervalSince(now))), 1), total)
    return SystemFocusWidgetContent(
      session: session,
      activity: .running,
      secondsRemaining: liveRemaining,
      totalSessionSeconds: total,
      snapshotGeneratedAt: generatedAtText,
      endsAt: deadline,
      availableActions: actions(for: .running)
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

  private static func actions(
    for activity: SystemFocusWidgetActivity
  ) -> Set<SystemFocusWidgetAction> {
    switch activity {
    case .ready: return [.start]
    case .running: return [.pause, .reset]
    case .paused: return [.resume, .reset]
    case .completed: return [.beginNextSession]
    case .pendingResume: return [.resume, .discardPending]
    }
  }
}
