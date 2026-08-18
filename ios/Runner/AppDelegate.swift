import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var systemFocusAdapter: SystemFocusPlatformAdapter?
  private var focusShieldAdapter: FocusShieldPlatformAdapter?
  private var havenWindowAdapter: HavenWindowPlatformAdapter?

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

    if let focusShieldRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "FocusHavenFocusShieldAdapter"
    ) {
      let focusShieldAdapter = FocusShieldPlatformAdapter()
      focusShieldAdapter.install(binaryMessenger: focusShieldRegistrar.messenger())
      self.focusShieldAdapter = focusShieldAdapter
    }

    if let havenWindowRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "FocusHavenHavenWindowAdapter"
    ) {
      let havenWindowAdapter = HavenWindowPlatformAdapter()
      havenWindowAdapter.install(binaryMessenger: havenWindowRegistrar.messenger())
      self.havenWindowAdapter = havenWindowAdapter
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    focusShieldAdapter?.refreshAfterActivation()
  }

  func deliverSystemFocusPendingCommand() {
    systemFocusAdapter?.deliverWarmPendingCommand()
  }
}
