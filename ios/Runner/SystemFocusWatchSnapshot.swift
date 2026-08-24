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

enum SystemFocusWatchAction: String, CaseIterable {
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
    case .discardPending: return "Start fresh"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .start: return "Start FocusHaven timer"
    case .pause: return "Pause FocusHaven timer"
    case .resume: return "Resume FocusHaven timer"
    case .reset: return "Reset FocusHaven timer"
    case .beginNextSession: return "Begin next FocusHaven session"
    case .discardPending: return "Start a fresh FocusHaven session"
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

  var generatedAtMilliseconds: Int {
    Self.milliseconds(generatedAt)
  }

  var availableActions: Set<SystemFocusWatchAction> {
    switch activity {
    case .ready: return [.start]
    case .running: return [.pause, .reset]
    case .paused: return [.resume, .reset]
    case .completed: return [.beginNextSession]
    case .pendingResume: return [.resume, .discardPending]
    }
  }

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

  func progressPercent(at date: Date) -> Int {
    min(max(Int((progress(at: date) * 100).rounded()), 0), 100)
  }

  func accessibilitySummary(at date: Date) -> String {
    let currentActivity = activity(at: date)
    let remaining = remainingSeconds(at: date)
    let duration = Self.accessibleDuration(remaining)
    let timing: String
    if currentActivity == .running {
      timing = "Live countdown, \(duration) remaining at last update."
    } else {
      timing = "\(duration) remaining."
    }
    let percent = progressPercent(at: date)
    return "\(session.title). \(currentActivity.title). \(timing) \(percent) percent complete."
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

  fileprivate static func integer(_ value: Any?) -> Int? {
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

/// One bounded, text-free command created by the watch for the exact snapshot
/// its wearer acted on. Both the watch and iPhone parse this same contract.
struct SystemFocusWatchCommand: Equatable {
  static let schemaVersion = 1
  static let maximumAge: TimeInterval = 60

  private static let wireKeys: Set<String> = [
    "schemaVersion",
    "requestId",
    "action",
    "snapshotGeneratedAtMilliseconds",
    "createdAtMilliseconds",
  ]
  private static let requestIdPattern = try! NSRegularExpression(
    pattern: "^[A-Za-z0-9_-]{8,64}$"
  )

  let requestId: String
  let action: SystemFocusWatchAction
  let snapshotGeneratedAtMilliseconds: Int
  let createdAtMilliseconds: Int

  var wireDictionary: [String: Any] {
    [
      "schemaVersion": Self.schemaVersion,
      "requestId": requestId,
      "action": action.rawValue,
      "snapshotGeneratedAtMilliseconds": snapshotGeneratedAtMilliseconds,
      "createdAtMilliseconds": createdAtMilliseconds,
    ]
  }

  var applicationEnvelope: [String: Any] {
    [
      "schemaVersion": Self.schemaVersion,
      "requestId": requestId,
      "action": action.rawValue,
      "snapshotGeneratedAt": Self.utcString(
        Self.date(milliseconds: snapshotGeneratedAtMilliseconds)
      ),
    ]
  }

  func isFresh(at date: Date) -> Bool {
    let age = date.timeIntervalSince(Self.date(milliseconds: createdAtMilliseconds))
    return age >= 0 && age <= Self.maximumAge
  }

  static func create(
    action: SystemFocusWatchAction,
    snapshot: SystemFocusWatchSnapshot,
    now: Date = Date(),
    requestId: String = UUID().uuidString
  ) -> Self? {
    fromWireDictionary([
      "schemaVersion": schemaVersion,
      "requestId": requestId,
      "action": action.rawValue,
      "snapshotGeneratedAtMilliseconds": snapshot.generatedAtMilliseconds,
      "createdAtMilliseconds": milliseconds(now),
    ])
  }

  static func fromWireDictionary(_ value: [String: Any]?) -> Self? {
    guard let value, Set(value.keys) == wireKeys,
      SystemFocusWatchSnapshot.integer(value["schemaVersion"]) == schemaVersion,
      let requestId = value["requestId"] as? String,
      matchesRequestId(requestId),
      let actionText = value["action"] as? String,
      let action = SystemFocusWatchAction(rawValue: actionText),
      let snapshotGeneratedAtMilliseconds = SystemFocusWatchSnapshot.integer(
        value["snapshotGeneratedAtMilliseconds"]
      ),
      let createdAtMilliseconds = SystemFocusWatchSnapshot.integer(
        value["createdAtMilliseconds"]
      ),
      snapshotGeneratedAtMilliseconds > 0,
      createdAtMilliseconds > 0
    else {
      return nil
    }
    return Self(
      requestId: requestId,
      action: action,
      snapshotGeneratedAtMilliseconds: snapshotGeneratedAtMilliseconds,
      createdAtMilliseconds: createdAtMilliseconds
    )
  }

  fileprivate static func matchesRequestId(_ value: String) -> Bool {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return requestIdPattern.firstMatch(in: value, range: range) != nil
  }

  private static func milliseconds(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1_000).rounded())
  }

  private static func date(milliseconds: Int) -> Date {
    Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
  }

  private static func utcString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

struct SystemFocusWatchCommandResult: Equatable {
  private static let wireKeys: Set<String> = [
    "schemaVersion", "requestId", "accepted",
  ]

  let requestId: String
  let accepted: Bool

  var wireDictionary: [String: Any] {
    [
      "schemaVersion": SystemFocusWatchCommand.schemaVersion,
      "requestId": requestId,
      "accepted": accepted,
    ]
  }

  static func fromWireDictionary(_ value: [String: Any]?) -> Self? {
    guard let value, Set(value.keys) == wireKeys,
      SystemFocusWatchSnapshot.integer(value["schemaVersion"])
        == SystemFocusWatchCommand.schemaVersion,
      let requestId = value["requestId"] as? String,
      SystemFocusWatchCommand.matchesRequestId(requestId),
      let acceptedNumber = value["accepted"] as? NSNumber,
      CFGetTypeID(acceptedNumber) == CFBooleanGetTypeID()
    else {
      return nil
    }
    return Self(requestId: requestId, accepted: acceptedNumber.boolValue)
  }
}
