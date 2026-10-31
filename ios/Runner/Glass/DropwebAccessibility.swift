import Flutter
import UIKit

/// Настройки доступности iOS, которых нет во Flutter (`dropweb/accessibility`).
/// Reduce Transparency Flutter не отдаёт ни в `MediaQuery`, ни в `AccessibilityFeatures`.
/// Reduce Motion, Increase Contrast и Bold Text приходят из `MediaQuery` без этого канала.
final class DropwebAccessibilityPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private var lastReduceTransparency: Bool
    private var observers: [NSObjectProtocol] = []

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dropweb/accessibility", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(DropwebAccessibilityPlugin(channel: channel), channel: channel)
    }

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        lastReduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        super.init()
        let center = NotificationCenter.default
        let push: (Notification) -> Void = { [weak self] _ in self?.pushReduceTransparency() }
        observers.append(
            center.addObserver(
                forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                object: nil, queue: .main, using: push))
        // Настройку могли переключить, пока приложение было в фоне: не полагаемся только
        // на уведомление, а сверяем значение при каждом возврате на передний план.
        observers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: .main, using: push))
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "reduceTransparency":
            let now = UIAccessibility.isReduceTransparencyEnabled
            lastReduceTransparency = now
            result(now)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Шлёт в Dart только реальное изменение, чтобы не гонять лишние перестроения.
    private func pushReduceTransparency() {
        let now = UIAccessibility.isReduceTransparencyEnabled
        guard now != lastReduceTransparency else { return }
        lastReduceTransparency = now
        channel.invokeMethod("reduceTransparencyChanged", arguments: now)
    }
}
