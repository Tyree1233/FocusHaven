import Flutter
import Foundation

/// Dedicated Flutter transport for the consent-first iOS calendar adapter.
@MainActor
final class HavenWindowPlatformAdapter {
  static let channelName = "com.focushaven/haven_window"
  private static let readAvailabilityMethod = "readAvailability"
  private static let requestReadOnlyAccessMethod = "requestReadOnlyAccess"

  private let controller: HavenWindowNativeController
  private var channel: FlutterMethodChannel?

  init(controller: HavenWindowNativeController? = nil) {
    self.controller = controller ?? HavenWindowNativeController()
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
            code: "haven-window-adapter-unavailable",
            message: "The Haven Window adapter is unavailable.",
            details: nil
          )
        )
        return
      }
      guard self.isValidRequest(call.arguments) else {
        result(self.invalidRequestError)
        return
      }
      switch call.method {
      case Self.readAvailabilityMethod:
        do {
          result(try self.controller.readAvailability().dictionary)
        } catch {
          result(self.readFailureError)
        }
      case Self.requestReadOnlyAccessMethod:
        Task { @MainActor in
          do {
            result(try await self.controller.requestReadOnlyAccess().dictionary)
          } catch {
            result(self.readFailureError)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  private func isValidRequest(_ value: Any?) -> Bool {
    guard let request = value as? [String: Any], request.count == 1 else {
      return false
    }
    return request["schemaVersion"] as? Int == 1
  }

  private var invalidRequestError: FlutterError {
    FlutterError(
      code: "invalid-haven-window-request",
      message: "The Haven Window request was rejected.",
      details: nil
    )
  }

  private var readFailureError: FlutterError {
    FlutterError(
      code: "haven-window-read-failed",
      message: "Private calendar availability could not be read.",
      details: nil
    )
  }
}
