import Foundation

public final class WoLLauncher {
    public enum WoLError: LocalizedError {
        case invalidMACAddress(String)
        case socketCreationFailed
        case sendFailed

        public var errorDescription: String? {
            switch self {
            case .invalidMACAddress(let mac):
                return "Invalid MAC address format: '\(mac)'. Expected 6 hex pairs (e.g. 00:11:22:33:44:55)."
            case .socketCreationFailed:
                return "Failed to create UDP broadcast socket."
            case .sendFailed:
                return "Failed to transmit Wake-on-LAN magic packet over UDP broadcast."
            }
        }
    }

    /// Parses a MAC address string into 6 bytes
    public static func parseMAC(_ macStr: String) -> [UInt8]? {
        let clean = macStr
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard clean.count == 12 else { return nil }

        var bytes: [UInt8] = []
        var index = clean.startIndex
        for _ in 0..<6 {
            let nextIndex = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }

    /// Creates the 102-byte Wake-on-LAN magic packet payload (6x 0xFF followed by 16x MAC)
    public static func createMagicPacket(for macBytes: [UInt8]) -> [UInt8] {
        var packet: [UInt8] = Array(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }

    /// Transmits Wake-on-LAN magic packet to broadcast address on port 9 and port 7
    public static func wake(mac: String, broadcastIp: String = "255.255.255.255") throws {
        guard let macBytes = parseMAC(mac) else {
            throw WoLError.invalidMACAddress(mac)
        }

        let packet = createMagicPacket(for: macBytes)

        let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else {
            throw WoLError.socketCreationFailed
        }
        defer { close(socketFD) }

        var broadcastEnable: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

        for port in [9, 7] {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(port).bigEndian
            inet_pton(AF_INET, broadcastIp, &addr.sin_addr)

            _ = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socketFD, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
