import Foundation

struct SystemFocusWidgetLinkRequest: Equatable {
  let action: SystemFocusWidgetAction
  let snapshotGeneratedAt: String
  let controlToken: String
}

/// Pure native checks performed before an Apple widget command enters the inbox.
enum SystemFocusWidgetCommandPolicy {
  static let maximumPendingAge: TimeInterval = 2 * 60
  private static let expectedEnvelopeKeys: Set<String> = [
    "schemaVersion", "requestId", "action", "snapshotGeneratedAt",
  ]
  private static let boundedTokenPattern = try! NSRegularExpression(
    pattern: "^[A-Za-z0-9_-]{8,64}$"
  )

  static func parseCommandURL(_ url: URL) -> SystemFocusWidgetLinkRequest? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme == "focushaven",
      components.host == "system-focus-command",
      components.path.isEmpty,
      components.user == nil,
      components.password == nil,
      components.port == nil,
      components.fragment == nil,
      let items = components.queryItems,
      items.count == 3
    else {
      return nil
    }

    var values: [String: String] = [:]
    for item in items {
      guard ["action", "snapshotGeneratedAt", "controlToken"].contains(item.name),
        let value = item.value,
        values.updateValue(value, forKey: item.name) == nil
      else {
        return nil
      }
    }
    guard values.count == 3,
      let actionText = values["action"],
      let action = SystemFocusWidgetAction(rawValue: actionText),
      let generatedAt = values["snapshotGeneratedAt"],
      utcDate(generatedAt) != nil,
      let token = values["controlToken"],
      matchesBoundedToken(token, minimumLength: 16)
    else {
      return nil
    }
    return SystemFocusWidgetLinkRequest(
      action: action,
      snapshotGeneratedAt: generatedAt,
      controlToken: token
    )
  }

  static func isAllowed(
    snapshot: [String: Any],
    request: SystemFocusWidgetLinkRequest
  ) -> Bool {
    guard snapshot["generatedAt"] as? String == request.snapshotGeneratedAt,
      utcDate(request.snapshotGeneratedAt) != nil,
      let activityText = snapshot["activity"] as? String,
      let activity = SystemFocusWidgetActivity(rawValue: activityText)
    else {
      return false
    }
    return actions(for: activity).contains(request.action)
  }

  static func validateEnvelope(_ value: [String: Any]) -> [String: Any]? {
    guard Set(value.keys) == expectedEnvelopeKeys,
      integer(value["schemaVersion"]) == 1,
      let requestId = value["requestId"] as? String,
      matchesBoundedToken(requestId, minimumLength: 8),
      let actionText = value["action"] as? String,
      SystemFocusWidgetAction(rawValue: actionText) != nil,
      let generatedAt = value["snapshotGeneratedAt"] as? String,
      utcDate(generatedAt) != nil
    else {
      return nil
    }
    return expectedEnvelopeKeys.reduce(into: [String: Any]()) { result, key in
      result[key] = value[key]
    }
  }

  static func isFreshPendingCommand(createdAt: Date, now: Date) -> Bool {
    let age = now.timeIntervalSince(createdAt)
    return age >= 0 && age <= maximumPendingAge
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

  private static func matchesBoundedToken(
    _ value: String,
    minimumLength: Int
  ) -> Bool {
    guard value.count >= minimumLength else { return false }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return boundedTokenPattern.firstMatch(in: value, range: range) != nil
  }

  private static func integer(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      !CFNumberIsFloatType(number)
    else {
      return nil
    }
    return number.intValue
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
