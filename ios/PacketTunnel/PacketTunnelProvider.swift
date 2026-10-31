import Foundation
import NetworkExtension

/// Hosts the Go core (libclash.a). No Swift Concurrency here: on iOS 13–14 it
/// needs the back-deployed runtime, and the extension has a 15 MB budget.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let appGroup = "group.app.dropweb"
    /// Measured on iPhone 8 / iOS 14.8.1: 12.9 MB idle with this limit.
    private static let liteMemoryLimit: Int64 = 8 << 20
    private static let liteGCPercent: Int32 = 20

    private let coreQueue = DispatchQueue(label: "app.dropweb.tunnel.core")
    private let invokeQueue = DispatchQueue(
        label: "app.dropweb.tunnel.invoke", attributes: .concurrent)
    /// Только DEBUG: периодический замер памяти для диагностики.
    private var memoryTimer: DispatchSourceTimer?
    /// Строка в лог только при реальном давлении памяти, без опроса.
    private var memoryPressure: DispatchSourceMemoryPressure?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        coreQueue.async {
            Self.logMemory("launch")
            let settings: NEPacketTunnelNetworkSettings
            do {
                try self.startCore()
                Self.logMemory("core")
                settings = try Self.networkSettings(json: Self.take(iosTunSettings()))
            } catch {
                completionHandler(error)
                return
            }
            self.setTunnelNetworkSettings(settings) { error in
                if let error = error {
                    completionHandler(error)
                    return
                }
                self.coreQueue.async {
                    let failure = Self.take(iosStartTun())
                    guard failure.isEmpty else {
                        completionHandler(TunnelError(failure))
                        return
                    }
                    Self.logMemory("tun")
                    self.startMemoryLog()
                    completionHandler(nil)
                }
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        coreQueue.async {
            self.memoryTimer?.cancel()
            self.memoryTimer = nil
            self.memoryPressure?.cancel()
            self.memoryPressure = nil
            iosStopTun()
            completionHandler()
        }
    }

    override func handleAppMessage(
        _ messageData: Data, completionHandler: ((Data?) -> Void)?
    ) {
        invokeQueue.async {
            let params = String(decoding: messageData, as: UTF8.self)
            let reply = params.withCString {
                Self.take(iosInvokeAction(UnsafeMutablePointer(mutating: $0)))
            }
            completionHandler?(Data(reply.utf8))
        }
    }

    private func startCore() throws {
        guard let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroup)
        else { throw TunnelError("app group container unavailable") }
        let dir = group.appendingPathComponent("tunnel", isDirectory: true)
        func read(_ name: String) throws -> String {
            try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
        }
        let initJSON = try read("init.json")
        let setupJSON = try read("setup.json")
        let stateJSON = try read("state.json")
        // Before iosQuickStart: the config parse is the allocation peak.
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 15 {
            iosSetMemoryLimit(Self.liteMemoryLimit, Self.liteGCPercent)
        }
        let failure = initJSON.withCString { i in
            setupJSON.withCString { s in
                stateJSON.withCString { st in
                    Self.take(iosQuickStart(
                        UnsafeMutablePointer(mutating: i),
                        UnsafeMutablePointer(mutating: s),
                        UnsafeMutablePointer(mutating: st)))
                }
            }
        }
        guard failure.isEmpty else { throw TunnelError(failure) }
    }

    private static func networkSettings(json: String) throws -> NEPacketTunnelNetworkSettings {
        guard let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let ipv4 = object["ipv4"] as? String,
              let dns = object["dns"] as? String,
              let mtu = object["mtu"] as? Int
        else { throw TunnelError("bad tun settings: \(json)") }
        let (address, mask) = try cidr(ipv4)
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let v4 = NEIPv4Settings(addresses: [address], subnetMasks: [mask])
        v4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = v4
        // The core's TUN stack listens on the IPv6 address when the app enables
        // IPv6, so the interface must carry it; it also keeps IPv6 traffic
        // from bypassing the tunnel.
        if let ipv6 = object["ipv6"] as? String, !ipv6.isEmpty {
            let parts = ipv6.split(separator: "/")
            guard parts.count == 2, let prefix = Int(parts[1]), (0...128).contains(prefix)
            else { throw TunnelError("bad ipv6 cidr \(ipv6)") }
            let v6 = NEIPv6Settings(addresses: [String(parts[0])],
                                    networkPrefixLengths: [NSNumber(value: prefix)])
            v6.includedRoutes = [NEIPv6Route.default()]
            settings.ipv6Settings = v6
        }
        let dnsSettings = NEDNSSettings(servers: [dns])
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings
        settings.mtu = NSNumber(value: mtu)
        return settings
    }

    private static func cidr(_ value: String) throws -> (String, String) {
        let parts = value.split(separator: "/")
        guard parts.count == 2, let bits = UInt32(parts[1]), bits <= 32
        else { throw TunnelError("bad cidr \(value)") }
        let maskBits: UInt32 = bits == 0 ? 0 : UInt32.max << (32 - bits)
        let mask = [24, 16, 8, 0]
            .map { String((maskBits >> UInt32($0)) & 0xff) }
            .joined(separator: ".")
        return (String(parts[0]), mask)
    }

    /// В релизе нет периодического замера: каждые 5 с `iosMemStats` делает
    /// stop-the-world `runtime.ReadMemStats` в Go и NSLog — всё время, пока
    /// поднят VPN, в том числе с выключенным экраном, и будит CPU впустую.
    /// Вместо этого — источник давления памяти: он молчит, пока iOS не начнёт
    /// поджимать расширение, и тогда даёт одну строку `dropweb-mem`.
    /// Разовые строки этапов (launch/core/tun) остаются.
    private func startMemoryLog() {
        memoryPressure?.cancel()
        let pressure = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical], queue: coreQueue)
        pressure.setEventHandler { [weak pressure] in
            guard let event = pressure?.data else { return }
            Self.logMemory(event.contains(.critical)
                ? "pressure-critical" : "pressure-warning")
        }
        pressure.resume()
        memoryPressure = pressure
        #if DEBUG
        // Диагностика: что считает jetsam (phys_footprint), каждые 5 с —
        // `idevicesyslog | grep dropweb-mem`.
        memoryTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: coreQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(5))
        timer.setEventHandler { Self.logMemory("tick") }
        timer.resume()
        memoryTimer = timer
        #endif
    }

    private static func logMemory(_ stage: String) {
        NSLog("dropweb-mem stage=%@ footprint=%.2fMB go=%@", stage, footprintMB(), take(iosMemStats()))
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    private static func take(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer = pointer else { return "" }
        defer { freeCString(pointer) }
        return String(cString: pointer)
    }
}

struct TunnelError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
