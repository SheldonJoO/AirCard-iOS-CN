import Foundation
import Darwin

/// 检测网络接口（回环隧道、Wi-Fi en0）。
/// 移植自 SideInstaller —— 用于为 `tunnel_create_rppairing_multihost` 挑选合适的主机候选。
/// `tunnel_create_rppairing_multihost`.
enum NetworkStatus {

    struct Interface {
        let name: String
        let ipv4: String
        let netmask: String?
    }

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            guard let ipv4 = numericHost(addr) else { continue }
            result.append(Interface(name: name, ipv4: ipv4,
                                    netmask: cur.pointee.ifa_netmask.flatMap(numericHost)))
        }
        return result
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
        else { return nil }
        return String(cString: host)
    }

    /// 返回 (vpnUp, wifiUp, detail)，供界面显示状态。
    static func summarize(deviceIP: String) -> (vpn: Bool, wifi: Bool, detail: String) {
        let ifs = interfaces()
        let vpn = isLoopbackTunnelUp(in: ifs, deviceIP: deviceIP)
        let wifi = ifs.contains { $0.name == "en0" }
        let detail = ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", ")
        return (vpn, wifi, detail)
    }

    static func loopbackTunnelUp(deviceIP: String) -> Bool {
        isLoopbackTunnelUp(in: interfaces(), deviceIP: deviceIP)
    }

    private static func isLoopbackTunnelUp(in ifs: [Interface], deviceIP: String) -> Bool {
        if ifs.contains(where: { isTunnelInterface($0.name) }) {
            return true
        }
        guard let target = ipv4Value(deviceIP) else {
            return false
        }
        if tunnelCarriesRoute(to: deviceIP, in: ifs) == true { return true }
        return ifs.contains { isTunnelInterface($0.name) && subnet($0, contains: target) }
    }

    private static func tunnelCarriesRoute(to deviceIP: String, in ifs: [Interface]) -> Bool? {
        guard let source = routeSource(to: deviceIP),
              let iface = ifs.first(where: { $0.ipv4 == source })
        else { return nil }
        guard isTunnelInterface(iface.name) else { return false }
        return routeSource(to: defaultRouteProbe) != source
    }

    private static let defaultRouteProbe = "203.0.113.1"

    private static func routeSource(to ip: String) -> String? {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(UInt16(9).bigEndian)
        guard ip.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1 else { return nil }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        let dialled = withUnsafePointer(to: remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard dialled == 0 else { return nil }

        var local = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0, local.sin_addr.s_addr != 0 else { return nil }
        return withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, numericHost)
        }
    }

    static func isOwnAddress(_ deviceIP: String) -> Bool {
        interfaces().contains { $0.ipv4 == deviceIP }
    }

    /// 当隧道监听只给出端口、未给出主机时，尝试使用的本地接口地址。
    /// 优先使用 Wi-Fi（en0），排除隧道与回环地址。
    static func tunnelHostCandidates() -> [String] {
        let ifs = interfaces().filter {
            !isTunnelInterface($0.name) && !$0.ipv4.hasPrefix("127.")
        }
        return (ifs.filter { $0.name == "en0" } + ifs.filter { $0.name != "en0" })
            .map(\.ipv4)
    }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    private static func subnet(_ interface: Interface, contains target: UInt32) -> Bool {
        guard let address = ipv4Value(interface.ipv4) else { return false }
        guard let mask = interface.netmask.flatMap(ipv4Value), mask != 0 else {
            return (address & 0xFFFF_FF00) == (target & 0xFFFF_FF00)
        }
        return (address & mask) == (target & mask)
    }

    static func host(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slash = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[..<slash]).trimmingCharacters(in: .whitespaces)
    }

    private static func ipv4Value(_ ip: String) -> UInt32? {
        let octets = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        var value: UInt32 = 0
        for octet in octets {
            guard let byte = UInt8(octet) else { return nil }
            value = (value << 8) | UInt32(byte)
        }
        return value
    }
}
