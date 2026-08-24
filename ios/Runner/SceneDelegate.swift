import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    var enqueuedSystemFocusCommand = false
    if connectionOptions.urlContexts.count == 1,
      let url = connectionOptions.urlContexts.first?.url,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    {
      enqueuedSystemFocusCommand = appDelegate.enqueueSystemFocusCommand(url: url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if enqueuedSystemFocusCommand {
      (UIApplication.shared.delegate as? AppDelegate)?
        .deliverSystemFocusPendingCommand()
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard URLContexts.count == 1,
      let url = URLContexts.first?.url,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      appDelegate.enqueueSystemFocusCommand(url: url)
    else {
      super.scene(scene, openURLContexts: URLContexts)
      return
    }
    appDelegate.deliverSystemFocusPendingCommand()
  }
}
