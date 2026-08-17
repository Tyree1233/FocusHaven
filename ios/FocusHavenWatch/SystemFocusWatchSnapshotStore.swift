import Foundation

/// Persists only the latest validated wire snapshot on the watch itself.
final class SystemFocusWatchSnapshotStore {
  private let defaults: UserDefaults
  private let storageKey: String

  init(
    defaults: UserDefaults = .standard,
    storageKey: String = "focus_haven_watch_snapshot_v1"
  ) {
    self.defaults = defaults
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
    guard let data = defaults.data(forKey: storageKey),
      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return SystemFocusWatchSnapshot.fromWireDictionary(value)
  }
}
