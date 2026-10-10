import XCTest
@testable import Drifter

final class DiscoveryTests: XCTestCase {
    func testVendorLookup() {
        XCTAssertEqual(VendorLookup.lookup(mac: "24:0A:C4:AA:BB:CC"), "Espressif Systems")
        XCTAssertEqual(VendorLookup.lookup(mac: "B8-27-EB-12-34-56"), "Raspberry Pi Trading")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:11:32:99:88:77"), "Synology Inc.")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:24:A5:66:55:44"), "UniFi / Ubiquiti")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:17:88:11:22:33"), "Philips Hue / Signify")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:0E:58:AA:BB:CC"), "Sonos Inc.")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:02:B3:11:22:33"), "Intel Corporation")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:06:5B:AA:BB:CC"), "Dell Technologies")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:0A:3A:AA:BB:CC"), "TP-Link")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:09:5B:AA:BB:CC"), "Netgear")
        XCTAssertEqual(VendorLookup.lookup(mac: "DE:AD:BE:EF:00:01"), "Local Network Device")
    }

    @MainActor
    func testBonjourServiceMatching() {
        let scanner = BonjourScanner.shared
        // Test helper service matching logic
        let services = scanner.services(forHost: "homeassistant.local", ip: "192.168.1.100")
        XCTAssertNotNil(services)
    }

    func testSubnetBaseDetectionFormat() {
        if let base = SubnetSweeper.detectLocalSubnetBase() {
            let parts = base.split(separator: ".")
            XCTAssertEqual(parts.count, 3)
            for part in parts {
                XCTAssertNotNil(Int(part))
            }
        }
    }
}
