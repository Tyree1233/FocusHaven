import Flutter
import Foundation
import UIKit

/// Dedicated Flutter transport for the iOS Family Controls adapter.
@MainActor
final class FocusShieldPlatformAdapter {
  static let channelName = "com.focushaven/focus_shield"
  private static let readCapabilityMethod = "readCapability"
  private static let performActionMethod = "performAction"
  private static let setProtectionRequestedMethod = "setProtectionRequested"
  private static let capabilityChangedMethod = "capabilityChanged"

  private let controller: FocusShieldNativeController
  private var channel: FlutterMethodChannel?

  init(controller: FocusShieldNativeController? = nil) {
    self.controller = controller ?? FocusShieldNativeController()
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
            code: "focus-shield-adapter-unavailable",
            message: "The Focus Shield adapter is unavailable.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case Self.readCapabilityMethod:
        result(self.controller.refreshAfterActivation().dictionary)
      case Self.setProtectionRequestedMethod:
        guard let requested = call.arguments as? Bool else {
          result(self.invalidRequestError)
          return
        }
        result(self.controller.setProtectionRequested(requested).dictionary)
      case Self.performActionMethod:
        guard let action = call.arguments as? String else {
          result(self.invalidRequestError)
          return
        }
        Task { @MainActor in
          let capability = await self.controller.perform(
            action: action,
            presentingViewController: self.topViewController()
          )
          result(capability.dictionary)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func refreshAfterActivation() {
    guard let channel else { return }
    let capability = controller.refreshAfterActivation()
    channel.invokeMethod(Self.capabilityChangedMethod, arguments: capability.dictionary)
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  private var invalidRequestError: FlutterError {
    FlutterError(
      code: "invalid-focus-shield-request",
      message: "The Focus Shield request was rejected.",
      details: nil
    )
  }

  private func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}
