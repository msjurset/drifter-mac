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

    func testExpandedVendorAndCategoryDetection() {
        XCTAssertEqual(VendorLookup.lookup(mac: "00:04:20:AA:BB:CC"), "Logitech")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:0D:4B:11:22:33"), "Roku Inc.")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:07:AB:44:55:66"), "Samsung Electronics")
        XCTAssertEqual(VendorLookup.lookup(mac: "40:22:D8:12:34:56"), "Shelly / Allterco")
        XCTAssertEqual(VendorLookup.lookup(mac: "00:01:42:77:88:99"), "Cisco Systems")

        let harmonyCategory = NetworkScanner.categorizeHost(
            vendor: "Logitech",
            hostname: "HarmonyHub",
            openPorts: [5222],
            mdnsServices: []
        )
        XCTAssertEqual(harmonyCategory, "iot")

        let rokuCategory = NetworkScanner.categorizeHost(
            vendor: "Roku Inc.",
            hostname: "livingroom-roku",
            openPorts: [8060],
            mdnsServices: []
        )
        XCTAssertEqual(rokuCategory, "iot")

        let appleTVCategory = NetworkScanner.categorizeHost(
            vendor: "Apple Inc.",
            hostname: "Apple-TV-4K",
            openPorts: [7000],
            mdnsServices: ["_airplay._tcp"]
        )
        XCTAssertEqual(appleTVCategory, "iot")

        let macbookCategory = NetworkScanner.categorizeHost(
            vendor: "Apple Inc.",
            hostname: "Marks-MacBook-Pro",
            openPorts: [22],
            mdnsServices: []
        )
        XCTAssertEqual(macbookCategory, "workstation")

        let synologyCategory = NetworkScanner.categorizeHost(
            vendor: "Synology Inc.",
            hostname: "DiskStation",
            openPorts: [5000],
            mdnsServices: ["_smb._tcp"]
        )
        XCTAssertEqual(synologyCategory, "server")

        let unifiCategory = NetworkScanner.categorizeHost(
            vendor: "UniFi / Ubiquiti",
            hostname: "UDM-Pro",
            openPorts: [53],
            mdnsServices: []
        )
        XCTAssertEqual(unifiCategory, "network")
    }
}
