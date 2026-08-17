import Foundation

/// Validates and stores the bounded, text-free timer state used by Apple surfaces.
final class SystemFocusSnapshotStore {
  static let channelName = "com.focushaven/system_focus"
  static let publishMethod = "publishSnapshot"
  static let takePendingCommandMethod = "takePendingCommand"
  static let appGroupSuiteName = "group.com.example.focushaven"
  static let widgetKind = "FocusHavenFocusWidget"

  private static let schemaVersion = 1
  private static let maximumSessionSeconds = 24 * 60 * 60
  private static let controlTokenKey = "focus_haven_system_focus_control_token_v1"
  private static let controlTokenPattern = try! NSRegularExpression(
    pattern: "^[A-Za-z0-9_-]{16,64}$"
  )
  private static let storageLock = NSLock()
  private static let expectedKeys: Set<String> = [
    "schemaVersion",
    "session",
    "activity",
    "secondsRemaining",
    "totalSessionSeconds",
    "generatedAt",
    "endsAt",
  ]
  private static let supportedSessions: Set<String> = [
    "focus",
    "shortBreak",
    "longBreak",
  ]
  private static let supportedActivities: Set<String> = [
    "ready",
    "running",
    "paused",
    "completed",
    "pendingResume",
  ]

  private let defaults: UserDefaults?
  private let storageKey: String

  init(
    defaults: UserDefaults? = UserDefaults(suiteName: appGroupSuiteName),
    storageKey: String = "focus_haven_system_focus_snapshot_v1"
  ) {
    self.defaults = defaults
    self.storageKey = storageKey
  }

  func validate(_ value: Any?) -> [String: Any]? {
    guard let source = value as? [String: Any], Set(source.keys) == Self.expectedKeys,
      Self.integer(source["schemaVersion"]) == Self.schemaVersion,
      let session = source["session"] as? String,
      Self.supportedSessions.contains(session),
      let activity = source["activity"] as? String,
      Self.supportedActivities.contains(activity),
      let secondsRemaining = Self.integer(source["secondsRemaining"]),
      let totalSessionSeconds = Self.integer(source["totalSessionSeconds"]),
      (1...Self.maximumSessionSeconds).contains(totalSessionSeconds),
      (0...totalSessionSeconds).contains(secondsRemaining),
      let generatedAtText = source["generatedAt"] as? String,
      let generatedAt = Self.utcDate(generatedAtText)
    else {
      return nil
    }

    if (activity == "completed") != (secondsRemaining == 0) {
      return nil
    }

    let endsAtValue = source["endsAt"]
    if activity == "running" {
      guard let endsAtText = endsAtValue as? String,
        let endsAt = Self.utcDate(endsAtText),
        endsAt > generatedAt
      else {
        return nil
      }
      let deadlineSeconds = Int(endsAt.timeIntervalSince(generatedAt))
      guard abs(deadlineSeconds - secondsRemaining) <= 1 else {
        return nil
      }
    } else if !(endsAtValue is NSNull) {
      return nil
    }

    return Self.expectedKeys.reduce(into: [String: Any]()) { result, key in
      result[key] = source[key]
    }
  }

  @discardableResult
  func save(_ value: Any?) -> Bool {
    guard let defaults,
      let snapshot = validate(value),
      JSONSerialization.isValidJSONObject(snapshot),
      let data = try? JSONSerialization.data(withJSONObject: snapshot)
    else {
      return false
    }
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    defaults.set(data, forKey: storageKey)
    defaults.set(Self.createControlToken(), forKey: Self.controlTokenKey)
    return true
  }

  func load() -> [String: Any]? {
    guard let defaults else { return nil }
    Self.storageLock.lock()
    let data = defaults.data(forKey: storageKey)
    Self.storageLock.unlock()
    guard let data,
      let decoded = try? JSONSerialization.jsonObject(with: data)
    else {
      return nil
    }
    return validate(decoded)
  }

  func loadControlToken() -> String? {
    guard let defaults else { return nil }
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    guard let token = defaults.string(forKey: Self.controlTokenKey),
      Self.isValidControlToken(token)
    else {
      return nil
    }
    return token
  }

  /// Consumes one private widget capability before a command enters the inbox.
  func consumeControlToken(_ token: String?) -> Bool {
    guard let defaults, let token, Self.isValidControlToken(token) else {
      return false
    }
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    guard defaults.string(forKey: Self.controlTokenKey) == token else {
      return false
    }
    defaults.set(Self.createControlToken(), forKey: Self.controlTokenKey)
    return true
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

  private static func createControlToken() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "")
  }

  private static func isValidControlToken(_ value: String) -> Bool {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return controlTokenPattern.firstMatch(in: value, range: range) != nil
  }
}
