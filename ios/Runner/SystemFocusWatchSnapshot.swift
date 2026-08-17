import Foundation

enum SystemFocusWatchSession: String, CaseIterable {
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

enum SystemFocusWatchActivity: String, CaseIterable {
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

/// The complete property-list-safe contract sent from the iPhone to its watch.
///
/// It is intentionally unable to represent tasks, reflections, moods, history,
/// coaching content, account identifiers, or commands.
struct SystemFocusWatchSnapshot: Equatable {
  static let schemaVersion = 1
  static let maximumSessionSeconds = 24 * 60 * 60

  private static let applicationKeys: Set<String> = [
    "schemaVersion",
    "session",
    "activity",
    "secondsRemaining",
    "totalSessionSeconds",
    "generatedAt",
    "endsAt",
  ]
  private static let wireKeys: Set<String> = [
    "schemaVersion",
    "session",
    "activity",
    "secondsRemaining",
    "totalSessionSeconds",
    "generatedAtMilliseconds",
    "endsAtMilliseconds",
  ]

  let session: SystemFocusWatchSession
  let activity: SystemFocusWatchActivity
  let secondsRemaining: Int
  let totalSessionSeconds: Int
  let generatedAt: Date
  let endsAt: Date?

  var wireDictionary: [String: Any] {
    [
      "schemaVersion": Self.schemaVersion,
      "session": session.rawValue,
      "activity": activity.rawValue,
      "secondsRemaining": secondsRemaining,
      "totalSessionSeconds": totalSessionSeconds,
      "generatedAtMilliseconds": Self.milliseconds(generatedAt),
      "endsAtMilliseconds": endsAt.map(Self.milliseconds) ?? 0,
    ]
  }

  var completedSeconds: Int {
    min(max(totalSessionSeconds - secondsRemaining, 0), totalSessionSeconds)
  }

  func activity(at date: Date) -> SystemFocusWatchActivity {
    guard activity == .running, let endsAt, endsAt <= date else {
      return activity
    }
    return .completed
  }

  func remainingSeconds(at date: Date) -> Int {
    guard activity == .running, let endsAt else {
      return secondsRemaining
    }
    return min(max(Int(ceil(endsAt.timeIntervalSince(date))), 0), totalSessionSeconds)
  }

  func progress(at date: Date) -> Double {
    let remaining = remainingSeconds(at: date)
    return Double(totalSessionSeconds - remaining) / Double(totalSessionSeconds)
  }

  static func fromApplicationSnapshot(_ value: [String: Any]?) -> Self? {
    guard let value, Set(value.keys) == applicationKeys,
      integer(value["schemaVersion"]) == schemaVersion,
      let sessionText = value["session"] as? String,
      let session = SystemFocusWatchSession(rawValue: sessionText),
      let activityText = value["activity"] as? String,
      let activity = SystemFocusWatchActivity(rawValue: activityText),
      let secondsRemaining = integer(value["secondsRemaining"]),
      let totalSessionSeconds = integer(value["totalSessionSeconds"]),
      let generatedAtText = value["generatedAt"] as? String,
      let generatedAt = utcDate(generatedAtText)
    else {
      return nil
    }

    let endsAt: Date?
    if activity == .running {
      guard let endsAtText = value["endsAt"] as? String,
        let parsedEndsAt = utcDate(endsAtText)
      else {
        return nil
      }
      endsAt = parsedEndsAt
    } else {
      guard value["endsAt"] is NSNull else { return nil }
      endsAt = nil
    }

    return validated(
      session: session,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: generatedAt,
      endsAt: endsAt
    )
  }

  static func fromWireDictionary(_ value: [String: Any]?) -> Self? {
    guard let value, Set(value.keys) == wireKeys,
      integer(value["schemaVersion"]) == schemaVersion,
      let sessionText = value["session"] as? String,
      let session = SystemFocusWatchSession(rawValue: sessionText),
      let activityText = value["activity"] as? String,
      let activity = SystemFocusWatchActivity(rawValue: activityText),
      let secondsRemaining = integer(value["secondsRemaining"]),
      let totalSessionSeconds = integer(value["totalSessionSeconds"]),
      let generatedAtMilliseconds = integer(value["generatedAtMilliseconds"]),
      let endsAtMilliseconds = integer(value["endsAtMilliseconds"]),
      generatedAtMilliseconds > 0,
      endsAtMilliseconds >= 0
    else {
      return nil
    }

    return validated(
      session: session,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: date(milliseconds: generatedAtMilliseconds),
      endsAt: endsAtMilliseconds == 0 ? nil : date(milliseconds: endsAtMilliseconds)
    )
  }

  private static func validated(
    session: SystemFocusWatchSession,
    activity: SystemFocusWatchActivity,
    secondsRemaining: Int,
    totalSessionSeconds: Int,
    generatedAt: Date,
    endsAt: Date?
  ) -> Self? {
    guard (1...maximumSessionSeconds).contains(totalSessionSeconds),
      (0...totalSessionSeconds).contains(secondsRemaining),
      (activity == .completed) == (secondsRemaining == 0)
    else {
      return nil
    }

    if activity == .running {
      guard let endsAt, endsAt > generatedAt else { return nil }
      let deadlineSeconds = Int(endsAt.timeIntervalSince(generatedAt))
      guard abs(deadlineSeconds - secondsRemaining) <= 1 else { return nil }
    } else if endsAt != nil {
      return nil
    }

    return Self(
      session: session,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: generatedAt,
      endsAt: endsAt
    )
  }

  private static func integer(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      !CFNumberIsFloatType(number),
      number.int64Value >= Int64(Int.min),
      number.int64Value <= Int64(Int.max)
    else {
      return nil
    }
    return Int(number.int64Value)
  }

  private static func milliseconds(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1_000).rounded())
  }

  private static func date(milliseconds: Int) -> Date {
    Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
  }

  private static func utcDate(_ value: String) -> Date? {
    guard value.hasSuffix("Z") else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = formatter.date(from: value) { return parsed }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}
