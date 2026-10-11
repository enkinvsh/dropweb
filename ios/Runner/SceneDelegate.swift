import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  // app_links 6.4.1 only implements UIApplicationDelegate URL callbacks, which
  // iOS does not call for scene-based apps, so dropweb:// links never reached
  // Dart. Forward the scene URL events to it explicitly.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      AppLinks.shared.handleLink(url: context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      AppLinks.shared.handleLink(url: context.url)
    }
  }
}
