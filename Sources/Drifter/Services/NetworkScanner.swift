import Foundation
import Combine

public final class NetworkScanner: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = NetworkScanner()

    public override init() {
        super.init()
    }

    /// Performs a swift scan of local ARP table after warming the subnet and probes common ports concurrently
    public func scanLocalSubnet() async -> [HostItem] {
        // 1. Warm the kernel ARP cache across the active IPv4 subnet
        if let subnetBase = SubnetSweeper.detectLocalSubnetBase() {
            await SubnetSweeper.warmSubnet(subnetBase: subnetBase)
        }

        // 2. Ensure Bonjour service discovery is active
        await MainActor.run {
            BonjourScanner.shared.startBrowsing()
        }

        let arpResults = parseARPTable()

        // 3. Concurrently probe each discovered host and its ports
        return await withTaskGroup(of: HostItem.self) { group in
            for (ip, mac) in arpResults {
                group.addTask {
                    let openPorts = await self.probeStandardPorts(ip: ip)
                    let hostname = self.resolveHostname(ip: ip)
                    let vendor = VendorLookup.lookup(mac: mac)

                    var mdns = await BonjourScanner.shared.services(forHost: hostname, ip: ip)
                    if mdns.isEmpty {
                        if openPorts.contains(8123) { mdns.append("_home-assistant._tcp") }
                        if openPorts.contains(80) || openPorts.contains(443) { mdns.append("_http._tcp") }
                        if openPorts.contains(22) { mdns.append("_ssh._tcp") }
                    }

                    var category = "unknown"
                    if openPorts.contains(8123) || mdns.contains("_home-assistant._tcp") || mdns.contains("_esphomelib._tcp") || mdns.contains("_matter._tcp") || vendor.contains("Espressif") || vendor.contains("Tuya") || vendor.contains("Philips") || vendor.contains("Sonos") {
                        category = "iot"
                    } else if openPorts.contains(5000) || openPorts.contains(8080) || mdns.contains("_smb._tcp") || vendor.contains("Synology") || vendor.contains("Supermicro") {
                        category = "server"
                    } else if openPorts.contains(53) || vendor.contains("Ubiquiti") || vendor.contains("UniFi") || vendor.contains("MikroTik") || vendor.contains("Netgear") || vendor.contains("TP-Link") {
                        category = "network"
                    } else if !mac.isEmpty {
                        category = "workstation"
                    }

                    return HostItem(
                        ip: ip,
                        mac: mac,
                        hostname: hostname,
                        vendor: vendor,
                        status: "online",
                        lastSeen: Date(),
                        openPorts: openPorts,
                        mdnsServices: mdns,
                        category: category
                    )
                }
            }

            var discovered: [HostItem] = []
            for await host in group {
                discovered.append(host)
            }
            return discovered.sorted { $0.ip.localizedStandardCompare($1.ip) == .orderedAscending }
        }
    }

    private func probeStandardPorts(ip: String) async -> [Int] {
        let portsToProbe = [22, 80, 443, 8123, 53, 5000, 8080]
        var open: [Int] = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in portsToProbe {
                group.addTask {
                    let isOpen = await self.checkPort(ip: ip, port: port, timeout: 0.20)
                    return (port, isOpen)
                }
            }
            for await (port, isOpen) in group {
                if isOpen {
                    open.append(port)
                }
            }
        }
        return open.sorted()
    }

    /// Probes 23 common homelab, infrastructure, and database ports concurrently on a single host
    public func deepScanHost(ip: String) async -> [Int] {
        let deepPorts = [
            21, 22, 23, 53, 80, 443, 445, 1883, 3000, 5000, 5001, 5432,
            6379, 8006, 8080, 8081, 8096, 8123, 8443, 9000, 9090, 9443, 32400
        ]
        var open: [Int] = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in deepPorts {
                group.addTask { [self] in
                    let isOpen = await checkPort(ip: ip, port: port, timeout: 0.35)
                    return (port, isOpen)
                }
            }
            for await (port, isOpen) in group {
                if isOpen {
                    open.append(port)
                }
            }
        }
        return open.sorted()
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
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return ip }
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size), &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
            }
        }
        if res == 0 {
            let len = host.firstIndex(of: 0) ?? host.count
            let resolved = String(decoding: host[..<len].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            return (!resolved.isEmpty && resolved != ip) ? resolved : ip
        }
        return ip
    }
}
