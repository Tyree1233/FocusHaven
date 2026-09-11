import Foundation

extension Notification.Name {
  static let havenSystemAssistantAppleRequestSubmitted = Notification.Name(
    "HavenSystemAssistantAppleRequestSubmitted"
  )
}

/// The complete Apple-side mirror of the Phase 217A text-free route allowlist.
enum HavenSystemAssistantAppleRoute: String, CaseIterable {
  case readTimerStatus
  case startFocusTimer
  case pauseTimer
  case resumeTimer
  case openFocusQueue
}

/// One exact native request that may cross into the Flutter review host.
struct HavenSystemAssistantAppleRequest: Equatable {
  static let schemaVersion = 1
  static let maximumInvocationIDLength = 128

  let invocationID: String
  let kind: HavenSystemAssistantAppleRoute

  init?(invocationID: String, kind: HavenSystemAssistantAppleRoute) {
    guard Self.isValidInvocationID(invocationID) else { return nil }
    self.invocationID = invocationID
    self.kind = kind
  }

  var dictionary: [String: Any] {
    [
      "schemaVersion": Self.schemaVersion,
      "invocationId": invocationID,
      "kind": kind.rawValue,
    ]
  }

  private static func isValidInvocationID(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard !bytes.isEmpty, bytes.count <= maximumInvocationIDLength,
      isAsciiLetterOrDigit(bytes[0])
    else {
      return false
    }
    return bytes.dropFirst().allSatisfy { byte in
      isAsciiLetterOrDigit(byte) || byte == 46 || byte == 95 || byte == 45
    }
  }

  private static func isAsciiLetterOrDigit(_ byte: UInt8) -> Bool {
    (48...57).contains(byte) ||
      (65...90).contains(byte) ||
      (97...122).contains(byte)
  }
}

/// Single-slot, process-memory-only handoff for a future reviewed App Intent.
///
/// This store writes no defaults, file, keychain, cloud value, transcript, or
/// utterance. It rejects a second request and clears the first only after the
/// Flutter inbox explicitly acknowledges that exact invocation ID.
@MainActor
final class HavenSystemAssistantApplePendingRequestStore {
  static let shared = HavenSystemAssistantApplePendingRequestStore()

  private var pendingRequest: HavenSystemAssistantAppleRequest?

  var hasPendingRequest: Bool { pendingRequest != nil }

  @discardableResult
  func submit(
    kind: HavenSystemAssistantAppleRoute,
    invocationID: String = UUID().uuidString
  ) -> Bool {
    guard pendingRequest == nil,
      let request = HavenSystemAssistantAppleRequest(
        invocationID: invocationID,
        kind: kind
      )
    else {
      return false
    }
    pendingRequest = request
    return true
  }

  func peek() -> HavenSystemAssistantAppleRequest? { pendingRequest }

  @discardableResult
  func clearIfMatches(invocationID: String) -> Bool {
    guard pendingRequest?.invocationID == invocationID else { return false }
    pendingRequest = nil
    return true
  }
}
