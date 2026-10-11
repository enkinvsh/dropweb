import Flutter
import NetworkExtension

/// Dart <-> NETunnelProviderManager over the "dropweb/ios_tunnel" channel.
final class IosTunnelPlugin: NSObject, FlutterPlugin {
    static let appGroup = "group.app.dropweb"
    static let providerBundleId = "app.dropweb.PacketTunnel"

    private let channel: FlutterMethodChannel
    private var statusObserver: NSObjectProtocol?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dropweb/ios_tunnel", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(IosTunnelPlugin(channel: channel), channel: channel)
    }

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] note in
            guard let connection = note.object as? NEVPNConnection else { return }
            self?.channel.invokeMethod("status", arguments: connection.status.rawValue)
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "groupPath":
            result(groupURL()?.path)
        case "start":
            guard let args = call.arguments as? [String: String] else {
                result(FlutterError(code: "args", message: "init/setup/state expected", details: nil))
                return
            }
            start(args, result: result)
        case "stop":
            loadManager { manager in
                manager?.connection.stopVPNTunnel()
                result(nil)
            }
        case "status":
            loadManager { manager in
                result((manager?.connection.status ?? .invalid).rawValue)
            }
        case "send":
            guard let message = call.arguments as? String else {
                result(nil)
                return
            }
            send(message, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func groupURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    }

    private func start(_ args: [String: String], result: @escaping FlutterResult) {
        do {
            guard let group = groupURL() else { throw TunnelSetupError("app group container unavailable") }
            let dir = group.appendingPathComponent("tunnel", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for key in ["init", "setup", "state"] {
                guard let value = args[key] else { throw TunnelSetupError("missing \(key)") }
                try value.write(to: dir.appendingPathComponent("\(key).json"),
                                atomically: true, encoding: .utf8)
            }
        } catch {
            result(FlutterError(code: "files", message: error.localizedDescription, details: nil))
            return
        }
        loadManager { existing in
            let manager = existing ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.providerBundleId
            proto.serverAddress = "dropweb"
            manager.protocolConfiguration = proto
            manager.localizedDescription = "dropweb"
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error = error {
                    result(FlutterError(code: "save", message: error.localizedDescription, details: nil))
                    return
                }
                manager.loadFromPreferences { error in
                    if let error = error {
                        result(FlutterError(code: "load", message: error.localizedDescription, details: nil))
                        return
                    }
                    do {
                        try manager.connection.startVPNTunnel()
                        result(true)
                    } catch {
                        result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
                    }
                }
            }
        }
    }

    private func send(_ message: String, result: @escaping FlutterResult) {
        loadManager { manager in
            guard let session = manager?.connection as? NETunnelProviderSession,
                  session.status == .connected
            else {
                result(nil)
                return
            }
            do {
                try session.sendProviderMessage(Data(message.utf8)) { reply in
                    DispatchQueue.main.async {
                        result(reply.map { String(decoding: $0, as: UTF8.self) })
                    }
                }
            } catch {
                result(FlutterError(code: "send", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func loadManager(_ done: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            DispatchQueue.main.async { done(managers?.first) }
        }
    }
}

struct TunnelSetupError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
