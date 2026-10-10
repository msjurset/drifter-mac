import XCTest
@testable import Drifter

final class DiagnosticsTests: XCTestCase {
    func testWoLMACParsing() {
        let mac1 = "AA:BB:CC:11:22:33"
        let parsed1 = WoLLauncher.parseMAC(mac1)
        XCTAssertEqual(parsed1, [0xAA, 0xBB, 0xCC, 0x11, 0x22, 0x33])

        let mac2 = "aa-bb-cc-dd-ee-ff"
        let parsed2 = WoLLauncher.parseMAC(mac2)
        XCTAssertEqual(parsed2, [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])

        let invalid = "invalid-mac"
        XCTAssertNil(WoLLauncher.parseMAC(invalid))
    }

    func testWoLMagicPacketStructure() {
        let macBytes: [UInt8] = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]
        let packet = WoLLauncher.createMagicPacket(for: macBytes)

        XCTAssertEqual(packet.count, 102)
        for i in 0..<6 {
            XCTAssertEqual(packet[i], 0xFF)
        }
        for rep in 0..<16 {
            let offset = 6 + (rep * 6)
            XCTAssertEqual(Array(packet[offset..<(offset + 6)]), macBytes)
        }
    }

    func testHomelabServiceDetection() {
        let ports = [8006, 8123, 9443, 32400, 22]
        let services = HomelabService.detectServices(openPorts: ports)

        let names = services.map(\.name)
        XCTAssertTrue(names.contains("Proxmox VE"))
        XCTAssertTrue(names.contains("Home Assistant"))
        XCTAssertTrue(names.contains("Portainer"))
        XCTAssertTrue(names.contains("Plex Media Server"))

        let proxmox = services.first { $0.id == "proxmox" }
        XCTAssertEqual(proxmox?.url(for: "192.168.1.10")?.absoluteString, "https://192.168.1.10:8006")

        let plex = services.first { $0.id == "plex" }
        XCTAssertEqual(plex?.url(for: "192.168.1.10")?.absoluteString, "http://192.168.1.10:32400/web")
    }
}
