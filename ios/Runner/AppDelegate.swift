import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var systemFocusAdapter: SystemFocusPlatformAdapter?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "FocusHavenSystemFocusAdapter"
      )
    else {
      return
    }
    let adapter = SystemFocusPlatformAdapter()
    adapter.install(binaryMessenger: registrar.messenger())
    systemFocusAdapter = adapter
  }

  func deliverSystemFocusPendingCommand() {
    systemFocusAdapter?.deliverWarmPendingCommand()
  }
}
