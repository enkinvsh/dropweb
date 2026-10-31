import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IosTunnelPlugin") {
      IosTunnelPlugin.register(with: registrar)
    }
    // Нативное стекло редизайна и канал Reduce Transparency: по одному registrar на плагин.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DropwebGlass") {
      registrar.register(
        DropwebGlassFactory(messenger: registrar.messenger()), withId: DropwebGlassFactory.viewType)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DropwebAccessibility") {
      DropwebAccessibilityPlugin.register(with: registrar)
    }
  }
}
