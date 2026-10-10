import XCTest
@testable import Drifter

final class DrifterStoreTests: XCTestCase {
    @MainActor
    func testHostManagement() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("test_store.json")

        let store = DrifterStore(storageFileURL: fileURL)

        let newHost = HostItem(ip: "10.0.0.1", mac: "FE:ED:FA:CE:00:01", hostname: "test-node.local", category: "server")
        store.updateHost(newHost)

        XCTAssertTrue(store.hosts.contains(where: { $0.ip == "10.0.0.1" }))

        store.removeHost(id: newHost.id)
        XCTAssertFalse(store.hosts.contains(where: { $0.id == newHost.id }))
    }

    @MainActor
    func testDriftEventTracking() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("test_store.json")

        let store = DrifterStore(storageFileURL: fileURL)
        let initialEventCount = store.driftEvents.count

        let event = DriftEvent(hostId: "host-1", hostIp: "192.168.1.50", hostname: "ha.local", type: "port_opened", detail: "Port 22 opened")
        store.addDriftEvent(event)

        XCTAssertEqual(store.driftEvents.count, initialEventCount + 1)
        XCTAssertEqual(store.driftEvents.first?.type, "port_opened")

        store.acknowledgeEvent(id: event.id)
        XCTAssertTrue(store.driftEvents.first?.acknowledged == true)
    }

    @MainActor
    func testSettingsPersistence() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("test_store.json")

        let store = DrifterStore(storageFileURL: fileURL)
        XCTAssertEqual(store.settings.preferredTerminal, .ghostty)

        var newSettings = store.settings
        newSettings.preferredTerminal = .ghostty
        newSettings.defaultSSHUser = "admin"
        store.updateSettings(newSettings)

        // Reload store from file to verify atomic JSON persistence
        let reloadedStore = DrifterStore(storageFileURL: fileURL)
        XCTAssertEqual(reloadedStore.settings.preferredTerminal, .ghostty)
        XCTAssertEqual(reloadedStore.settings.defaultSSHUser, "admin")
    }

    @MainActor
    func testBaselineLockAndEvolution() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("test_store.json")

        let store = DrifterStore(storageFileURL: fileURL)
        let host = HostItem(id: "h1", ip: "192.168.1.50", mac: "AA:BB:CC:DD:EE:FF", hostname: "server.lan", openPorts: [80])
        store.updateHost(host)

        XCTAssertNil(store.hosts.first?.baselinePorts)
        XCTAssertNil(store.lastBaselineLockDate)

        // 1. Lock baseline
        store.lockBaseline()
        XCTAssertEqual(store.hosts.first?.baselinePorts, [80])
        XCTAssertNotNil(store.lastBaselineLockDate)

        // 2. Simulate drift: port 8006 opened
        var driftedHost = store.hosts.first!
        driftedHost.openPorts = [80, 8006]
        driftedHost.status = "drift"
        store.updateHost(driftedHost)

        let driftEvent = DriftEvent(hostId: "h1", hostIp: "192.168.1.50", hostname: "server.lan", type: "port_opened", detail: "Port 8006 newly opened")
        store.addDriftEvent(driftEvent)

        // 3. Evolve baseline: Approve drift
        store.approveDrift(for: driftEvent)
        let updatedHost = store.hosts.first!
        XCTAssertTrue(updatedHost.baselinePorts?.contains(8006) == true)
        XCTAssertEqual(updatedHost.status, "online")
        XCTAssertTrue(store.driftEvents.first?.acknowledged == true)

        // 4. Reload store to ensure persistence
        let reloaded = DrifterStore(storageFileURL: fileURL)
        XCTAssertEqual(reloaded.hosts.first?.baselinePorts, [80, 8006])
        XCTAssertNotNil(reloaded.lastBaselineLockDate)
    }
}
