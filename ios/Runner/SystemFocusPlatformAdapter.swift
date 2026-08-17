import Flutter
import Foundation

/// Narrow Flutter transport for Apple system-focus surfaces.
final class SystemFocusPlatformAdapter {
  private let store: SystemFocusSnapshotStore
  private var channel: FlutterMethodChannel?

  init(store: SystemFocusSnapshotStore = SystemFocusSnapshotStore()) {
    self.store = store
  }

  func install(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: SystemFocusSnapshotStore.channelName,
      binaryMessenger: binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "system-focus-adapter-unavailable",
            message: "The system focus adapter is unavailable.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case SystemFocusSnapshotStore.publishMethod:
        guard self.store.save(call.arguments) else {
          result(
            FlutterError(
              code: "invalid-system-focus-snapshot",
              message: "The system focus snapshot was rejected.",
              details: nil
            )
          )
          return
        }
        result(nil)
      case SystemFocusSnapshotStore.takePendingCommandMethod:
        // Apple controls remain disabled until their private command inbox is installed.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }
}
