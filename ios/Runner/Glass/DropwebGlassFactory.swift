import Flutter
import UIKit

/// Фабрика платформенных видов стекла: `viewType` = `dropweb/glass`.
/// Регистрируется в `AppDelegate.didInitializeImplicitFlutterEngine` рядом с `IosTunnelPlugin`.
final class DropwebGlassFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "dropweb/glass"

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
    ) -> FlutterPlatformView {
        DropwebGlassPlatformView(
            frame: frame, viewId: viewId, arguments: args, messenger: messenger)
    }

    /// Параметры создания идут стандартным кодеком (карта с int/double/bool/String).
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
