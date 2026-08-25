import Foundation

/// Persists only the latest validated wire snapshot on the watch itself.
final class SystemFocusWatchSnapshotStore {
  static let appGroupIdentifier = "group.com.focushaven.app"

  private let defaults: UserDefaults
  private let legacyDefaults: UserDefaults
  private let storageKey: String

  init(
    defaults: UserDefaults? = nil,
    legacyDefaults: UserDefaults = .standard,
    storageKey: String = "focus_haven_watch_snapshot_v1"
  ) {
    self.defaults =
      defaults
      ?? UserDefaults(suiteName: Self.appGroupIdentifier)
      ?? legacyDefaults
    self.legacyDefaults = legacyDefaults
    self.storageKey = storageKey
  }

  @discardableResult
  func save(_ value: [String: Any]) -> Bool {
    guard let snapshot = SystemFocusWatchSnapshot.fromWireDictionary(value),
      JSONSerialization.isValidJSONObject(snapshot.wireDictionary),
      let data = try? JSONSerialization.data(withJSONObject: snapshot.wireDictionary)
    else {
      return false
    }
    defaults.set(data, forKey: storageKey)
    return true
  }

  func load() -> SystemFocusWatchSnapshot? {
    if let snapshot = decode(defaults) {
      return snapshot
    }
    guard let legacySnapshot = decode(legacyDefaults) else {
      return nil
    }
    // One-way migration keeps an already-synced timer visible after the Watch
    // app and its WidgetKit extension begin sharing the app-group container.
    _ = save(legacySnapshot.wireDictionary)
    return legacySnapshot
  }

  private func decode(_ source: UserDefaults) -> SystemFocusWatchSnapshot? {
    guard let data = source.data(forKey: storageKey),
      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return SystemFocusWatchSnapshot.fromWireDictionary(value)
  }
}
