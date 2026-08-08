import XCTest
@testable import Drifter

final class DriftDetectorTests: XCTestCase {
    func testDriftComputationPortOpened() {
        let existing = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80])
        ]
        let scanned = [
            HostItem(id: "h1-new", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80, 22])
        ]

        let result = DriftDetector.computeDrift(existingHosts: existing, newHosts: scanned)
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.type, "port_opened")
        XCTAssertTrue(result.events.first?.detail.contains("Port 22") == true)
    }

    func testDriftComputationNewHost() {
        let existing = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80])
        ]
        let scanned = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80]),
            HostItem(id: "h2", ip: "192.168.1.20", mac: "DD:EE:FF:44:55:66", hostname: "pi.local", openPorts: [53])
        ]

        let result = DriftDetector.computeDrift(existingHosts: existing, newHosts: scanned)
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.type, "new_host")
        XCTAssertEqual(result.updatedHosts.count, 2)
    }
}
