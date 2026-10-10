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
    func testAuthoritativeBaselinePortDivergence() {
        let existing = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80], baselinePorts: [80])
        ]
        let scanned = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80, 8006])
        ]

        let result = DriftDetector.computeDrift(existingHosts: existing, newHosts: scanned)
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.type, "port_opened")
        XCTAssertTrue(result.events.first?.detail.contains("baseline divergence") == true)
        XCTAssertEqual(result.updatedHosts.first?.status, "drift")
    }

    func testAuthoritativeBaselineUnapprovedHostDetection() {
        let existing = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80], baselinePorts: [80])
        ]
        let scanned = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80]),
            HostItem(id: "h-rogue", ip: "192.168.1.99", mac: "00:11:22:33:44:55", hostname: "unknown-device.local", openPorts: [22])
        ]

        let result = DriftDetector.computeDrift(existingHosts: existing, newHosts: scanned)
        let rogue = result.updatedHosts.first { $0.ip == "192.168.1.99" }
        XCTAssertNotNil(rogue)
        XCTAssertFalse(rogue!.isApprovedHost)
        XCTAssertEqual(rogue!.status, "drift")
        XCTAssertTrue(result.events.first?.detail.contains("unapproved host") == true)
    }

    func testAuditReportGeneratorMarkdownAndJSON() {
        let hosts = [
            HostItem(id: "h1", ip: "192.168.1.10", mac: "AA:BB:CC:11:22:33", hostname: "server.local", openPorts: [80, 443], baselinePorts: [80], isApprovedHost: true),
            HostItem(id: "h2", ip: "192.168.1.99", mac: "11:22:33:44:55:66", hostname: "rogue.local", openPorts: [22], baselinePorts: nil, isApprovedHost: false)
        ]
        let events = [
            DriftEvent(hostId: "h1", hostIp: "192.168.1.10", hostname: "server.local", type: "port_opened", detail: "Port 443 opened")
        ]

        let md = AuditReportGenerator.generateMarkdownReport(hosts: hosts, events: events, baselineLockDate: Date())
        XCTAssertTrue(md.contains("Drifter Network Security & Baseline Audit Report"))
        XCTAssertTrue(md.contains("Unapproved / Rogue Hosts"))
        XCTAssertTrue(md.contains("`192.168.1.99`"))
        XCTAssertTrue(md.contains("+443"))

        let json = AuditReportGenerator.generateJSONReport(hosts: hosts, events: events, baselineLockDate: Date())
        XCTAssertTrue(json.contains("\"hosts\" : ["))
        XCTAssertTrue(json.contains("\"isApprovedHost\" : false"))
    }
}
