import Foundation

/// One app-group-private, text-free command waiting for Flutter authorization.
final class SystemFocusPendingCommandStore {
  private static let commandKey = "focus_haven_system_focus_pending_command_v1"
  private static let createdAtKey = "focus_haven_system_focus_pending_created_at_v1"
  private static let storageLock = NSLock()

  private let defaults: UserDefaults?
  private let snapshotStore: SystemFocusSnapshotStore

  init(defaults: UserDefaults? = UserDefaults(suiteName: SystemFocusSnapshotStore.appGroupSuiteName)) {
    self.defaults = defaults
    snapshotStore = SystemFocusSnapshotStore(defaults: defaults)
  }

  @discardableResult
  func enqueue(url: URL, now: Date = Date()) -> Bool {
    guard let defaults,
      let request = SystemFocusWidgetCommandPolicy.parseCommandURL(url),
      let snapshot = snapshotStore.load(),
      SystemFocusWidgetCommandPolicy.isAllowed(snapshot: snapshot, request: request),
      snapshotStore.consumeControlToken(request.controlToken)
    else {
      return false
    }
    let command: [String: Any] = [
      "schemaVersion": 1,
      "requestId": UUID().uuidString,
      "action": request.action.rawValue,
      "snapshotGeneratedAt": request.snapshotGeneratedAt,
    ]
    guard let validated = SystemFocusWidgetCommandPolicy.validateEnvelope(command),
      JSONSerialization.isValidJSONObject(validated),
      let data = try? JSONSerialization.data(withJSONObject: validated)
    else {
      return false
    }

    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    defaults.set(data, forKey: Self.commandKey)
    defaults.set(now.timeIntervalSince1970, forKey: Self.createdAtKey)
    return true
  }

  func take(now: Date = Date()) -> [String: Any]? {
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    guard let command = peekLocked(now: now) else { return nil }
    clearLocked()
    return command
  }

  func peek(now: Date = Date()) -> [String: Any]? {
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    return peekLocked(now: now)
  }

  func clearIfMatches(requestId: String) {
    Self.storageLock.lock()
    defer { Self.storageLock.unlock() }
    guard let current = peekLocked(now: Date()),
      current["requestId"] as? String == requestId
    else {
      return
    }
    clearLocked()
  }

  private func peekLocked(now: Date) -> [String: Any]? {
    guard let defaults,
      let data = defaults.data(forKey: Self.commandKey),
      let createdAtNumber = defaults.object(forKey: Self.createdAtKey) as? NSNumber,
      CFGetTypeID(createdAtNumber) != CFBooleanGetTypeID(),
      let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let command = SystemFocusWidgetCommandPolicy.validateEnvelope(decoded),
      SystemFocusWidgetCommandPolicy.isFreshPendingCommand(
        createdAt: Date(timeIntervalSince1970: createdAtNumber.doubleValue),
        now: now
      )
    else {
      clearLocked()
      return nil
    }
    return command
  }

  private func clearLocked() {
    defaults?.removeObject(forKey: Self.commandKey)
    defaults?.removeObject(forKey: Self.createdAtKey)
  }
}
