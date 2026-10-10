import Foundation

public final class SubnetSweeper {
    /// Detects the active IPv4 subnet base (e.g. "192.168.86" or "10.0.0") from system network interfaces
    public static func detectLocalSubnetBase() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)

            // Look for non-loopback IPv4 interfaces (en0, en1, etc.)
            if addrFamily == UInt8(AF_INET) && !name.hasPrefix("lo") {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                let len = hostname.firstIndex(of: 0) ?? hostname.count
                let ip = String(decoding: hostname[..<len].map { UInt8(bitPattern: $0) }, as: UTF8.self)
                if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") {
                    let parts = ip.split(separator: ".")
                    if parts.count == 4 {
                        return "\(parts[0]).\(parts[1]).\(parts[2])"
                    }
                }
            }
        }
        return nil
    }

    /// Concurrently warms the kernel ARP cache by probing hosts 1...254 across the /24 subnet.
    /// This causes the Darwin networking stack to send ARP Who-has packets, populating /usr/sbin/arp.
    public static func warmSubnet(subnetBase: String) async {
        await withTaskGroup(of: Void.self) { group in
            for hostNum in 1...254 {
                let targetIp = "\(subnetBase).\(hostNum)"
                group.addTask {
                    sendProbe(to: targetIp)
                }
            }
        }
        // Small pause to allow ARP responses to settle in the kernel cache
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    private static func sendProbe(to ip: String) {
        let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { return }
        defer { close(socketFD) }

        var hints = sockaddr_in()
        hints.sin_family = sa_family_t(AF_INET)
        hints.sin_port = UInt16(7).bigEndian // Echo / Discard port
        inet_pton(AF_INET, ip, &hints.sin_addr)

        let flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)

        var dummy: UInt8 = 0
        withUnsafePointer(to: &hints) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = sendto(socketFD, &dummy, 1, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}
