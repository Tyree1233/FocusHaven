import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let pendingCommands = SystemFocusPendingCommandStore()

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if connectionOptions.urlContexts.count == 1,
      let url = connectionOptions.urlContexts.first?.url
    {
      _ = pendingCommands.enqueue(url: url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard URLContexts.count == 1,
      let url = URLContexts.first?.url,
      pendingCommands.enqueue(url: url)
    else {
      super.scene(scene, openURLContexts: URLContexts)
      return
    }
    (UIApplication.shared.delegate as? AppDelegate)?
      .deliverSystemFocusPendingCommand()
  }
}
