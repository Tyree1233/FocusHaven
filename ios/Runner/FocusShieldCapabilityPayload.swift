import Foundation

/// The complete text-free contract returned to Flutter by Focus Shield.
struct FocusShieldCapabilityPayload: Equatable {
  static let schemaVersion = 1
  static let keys: Set<String> = [
    "schemaVersion",
    "isEnabled",
    "nativeSupportAvailable",
    "authorization",
    "hasSelection",
    "temporarilyPaused",
    "nativeStatus",
  ]

  let isEnabled: Bool
  let nativeSupportAvailable: Bool
  let authorization: String
  let hasSelection: Bool
  let temporarilyPaused: Bool
  let nativeStatus: String

  var dictionary: [String: Any] {
    [
      "schemaVersion": Self.schemaVersion,
      "isEnabled": isEnabled,
      "nativeSupportAvailable": nativeSupportAvailable,
      "authorization": authorization,
      "hasSelection": hasSelection,
      "temporarilyPaused": temporarilyPaused,
      "nativeStatus": nativeStatus,
    ]
  }
}
