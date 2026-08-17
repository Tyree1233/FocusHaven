import Flutter
import Foundation
import WidgetKit

/// Narrow Flutter transport for Apple system-focus surfaces.
final class SystemFocusPlatformAdapter {
  private let store: SystemFocusSnapshotStore
  private let pendingCommands: SystemFocusPendingCommandStore
  private let watchPublisher: SystemFocusWatchPublishing
  private var channel: FlutterMethodChannel?

  init(
    store: SystemFocusSnapshotStore = SystemFocusSnapshotStore(),
    pendingCommands: SystemFocusPendingCommandStore = SystemFocusPendingCommandStore(),
    watchPublisher: SystemFocusWatchPublishing = SystemFocusWatchConnectivityBridge()
  ) {
    self.store = store
    self.pendingCommands = pendingCommands
    self.watchPublisher = watchPublisher
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
        if let snapshot = self.store.load() {
          self.watchPublisher.publish(snapshot: snapshot)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SystemFocusSnapshotStore.widgetKind)
        result(nil)
      case SystemFocusSnapshotStore.takePendingCommandMethod:
        result(self.pendingCommands.take())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  func deliverWarmPendingCommand() {
    guard let channel,
      let command = pendingCommands.peek(),
      let requestId = command["requestId"] as? String
    else {
      return
    }
    channel.invokeMethod("executeCommand", arguments: command) { [weak self] result in
      if result is Bool {
        self?.pendingCommands.clearIfMatches(requestId: requestId)
      }
    }
  }
}
