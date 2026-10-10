import Foundation
import Combine

@MainActor
public final class NetworkScanner: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = NetworkScanner()

    public override init() {
        super.init()
    }

    /// Performs a swift scan of local ARP table and probes common ports
    public func scanLocalSubnet() async -> [HostItem] {
        var discoveredHosts: [HostItem] = []
        
        let arpResults = parseARPTable()
        
        for (ip, mac) in arpResults {
            var openPorts: [Int] = []
            let portsToProbe = [22, 80, 443, 8123, 53, 5000, 8080]
            
            for port in portsToProbe {
                if await checkPort(ip: ip, port: port, timeout: 0.30) {
                    openPorts.append(port)
                }
            }

            let hostname = resolveHostname(ip: ip)
            let vendor = lookupVendorOUI(mac: mac)
            var category = "unknown"
            if openPorts.contains(8123) {
                category = "iot"
            } else if openPorts.contains(5000) || openPorts.contains(8080) {
                category = "server"
            } else if openPorts.contains(53) {
                category = "network"
            } else if !mac.isEmpty {
                category = "workstation"
            }

            let host = HostItem(
                ip: ip,
                mac: mac,
                hostname: hostname,
                vendor: vendor,
                status: "online",
                lastSeen: Date(),
                openPorts: openPorts,
                mdnsServices: openPorts.contains(8123) ? ["_home-assistant._tcp", "_http._tcp"] : (openPorts.contains(80) ? ["_http._tcp"] : []),
                category: category
            )
            discoveredHosts.append(host)
        }

        return discoveredHosts
    }

    private func parseARPTable() -> [(ip: String, mac: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-a"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var results: [(ip: String, mac: String)] = []
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("(") && line.contains(")") && line.contains(" at ") {
                    let parts = line.components(separatedBy: " ")
                    if let ipPart = parts.first(where: { $0.hasPrefix("(") && $0.hasSuffix(")") }) {
                        let ip = ipPart.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                        if let atIndex = parts.firstIndex(of: "at"), atIndex + 1 < parts.count {
                            let mac = parts[atIndex + 1]
                            if mac != "(incomplete)" && !ip.hasPrefix("224.") && !ip.hasPrefix("239.") {
                                results.append((ip: ip, mac: mac.uppercased()))
                            }
                        }
                    }
                }
            }
            return results
        } catch {
            print("[NetworkScanner] Failed to run arp: \(error)")
            return []
        }
    }

    private func checkPort(ip: String, port: Int, timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let socketFD = socket(AF_INET, SOCK_STREAM, 0)
                guard socketFD >= 0 else {
                    continuation.resume(returning: false)
                    return
                }
                defer { close(socketFD) }

                var hints = sockaddr_in()
                hints.sin_family = sa_family_t(AF_INET)
                hints.sin_port = UInt16(port).bigEndian
                inet_pton(AF_INET, ip, &hints.sin_addr)

                let flags = fcntl(socketFD, F_GETFL, 0)
                _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)

                _ = withUnsafePointer(to: &hints) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }

                var pollFD = pollfd(fd: socketFD, events: Int16(POLLOUT), revents: 0)
                let result = poll(&pollFD, 1, Int32(timeout * 1000))
                continuation.resume(returning: result > 0 && (pollFD.revents & Int16(POLLOUT)) != 0)
            }
        }
    }

    private func resolveHostname(ip: String) -> String {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ip, nil, &hints, &res) == 0, let info = res else { return ip }
        defer { freeaddrinfo(res) }

        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(info.pointee.ai_addr, info.pointee.ai_addrlen, &host, socklen_t(host.count), nil, 0, 0) == 0 {
            let len = host.firstIndex(of: 0) ?? host.count
            let resolved = String(decoding: host[..<len].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            return resolved != ip ? resolved : ip
        }
        return ip
    }

    private func lookupVendorOUI(mac: String) -> String {
        let prefix = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").prefix(6).uppercased()
        switch prefix {
        case "A483E7", "DCA632", "B827EB", "E45F01":
            return "Raspberry Pi Trading"
        case "A45E60", "B0A737", "001122", "A4B805":
            return "Apple Inc."
        case "001132", "00089B", "909C4A":
            return "Synology Inc."
        case "0024A5", "0418D6", "788A20", "AA8877":
            return "UniFi / Ubiquiti"
        default:
            return "Local Network Device"
        }
    }
}
