import Flutter
import Foundation

/// Private Flutter transport for one future reviewed Apple App Intent request.
///
/// Phase 217E intentionally declares no public intent or shortcut provider.
/// This adapter can only deliver an already-bounded in-process request, and it
/// clears that request only after Flutter acknowledges the exact three-field
/// payload. It cannot prepare, confirm, or execute a Haven Action.
@MainActor
final class HavenSystemAssistantApplePlatformAdapter {
  static let channelName = "com.focushaven/system_assistant_apple"
  private static let requestPendingDeliveryMethod = "requestPendingDelivery"
  private static let deliverRequestMethod = "deliverRequest"

  private let store: HavenSystemAssistantApplePendingRequestStore
  private var channel: FlutterMethodChannel?
  private var deliveryInFlight = false

  init(store: HavenSystemAssistantApplePendingRequestStore? = nil) {
    self.store = store ?? .shared
  }

  func install(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "system-assistant-apple-adapter-unavailable",
            message: "The Apple system-assistant adapter is unavailable.",
            details: nil
          )
        )
        return
      }
      guard call.method == Self.requestPendingDeliveryMethod else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard self.isValidDeliveryRequest(call.arguments) else {
        result(
          FlutterError(
            code: "invalid-system-assistant-apple-request",
            message: "The Apple system-assistant request was rejected.",
            details: nil
          )
        )
        return
      }
      let hasPendingRequest = self.store.hasPendingRequest
      result(hasPendingRequest)
      if hasPendingRequest {
        DispatchQueue.main.async { [weak self] in
          self?.deliverPendingRequest()
        }
      }
    }
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
    deliveryInFlight = false
  }

  func deliverPendingRequest() {
    guard !deliveryInFlight, let channel, let request = store.peek() else {
      return
    }
    deliveryInFlight = true
    channel.invokeMethod(
      Self.deliverRequestMethod,
      arguments: request.dictionary
    ) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        self.deliveryInFlight = false
        if result as? Bool == true {
          self.store.clearIfMatches(invocationID: request.invocationID)
        }
      }
    }
  }

  private func isValidDeliveryRequest(_ value: Any?) -> Bool {
    guard let request = value as? [String: Any], request.count == 1 else {
      return false
    }
    return request["schemaVersion"] as? Int == 1
  }
}
