import Foundation
import Combine
import SwiftUI

public enum TerminalApp: String, CaseIterable, Identifiable, Codable {
    case ghostty = "Ghostty"
    case terminal = "Apple Terminal"
    case iterm = "iTerm2"
    case custom = "Custom Command"

    public var id: String { rawValue }
}

public struct AppSettings: Codable, Equatable {
    public var preferredTerminal: TerminalApp
    public var defaultSSHUser: String
    public var customTerminalCommand: String
    public var notifyOnDrift: Bool
    public var enableRunbookIntegration: Bool
    public var runbookURLTemplate: String

    public init(preferredTerminal: TerminalApp = .ghostty,
                defaultSSHUser: String = "",
                customTerminalCommand: String = "ghostty -e ssh {ip}",
                notifyOnDrift: Bool = true,
                enableRunbookIntegration: Bool = true,
                runbookURLTemplate: String = "runbook://execute?template=security-audit&host={ip}") {
        self.preferredTerminal = preferredTerminal
        self.defaultSSHUser = defaultSSHUser
        self.customTerminalCommand = customTerminalCommand
        self.notifyOnDrift = notifyOnDrift
        self.enableRunbookIntegration = enableRunbookIntegration
        self.runbookURLTemplate = runbookURLTemplate
    }
}

public struct HostItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var ip: String
    public var mac: String
    public var hostname: String
    public var vendor: String
    public var status: String // "online", "offline", "drift"
    public var lastSeen: Date
    public var openPorts: [Int]
    public var mdnsServices: [String]
    public var category: String // "server", "iot", "workstation", "network", "unknown"
    public var notes: String

    public init(id: String = UUID().uuidString,
                ip: String,
                mac: String = "",
                hostname: String = "",
                vendor: String = "",
                status: String = "online",
                lastSeen: Date = Date(),
                openPorts: [Int] = [],
                mdnsServices: [String] = [],
                category: String = "unknown",
                notes: String = "") {
        self.id = id
        self.ip = ip
        self.mac = mac
        self.hostname = hostname
        self.vendor = vendor
        self.status = status
        self.lastSeen = lastSeen
        self.openPorts = openPorts
        self.mdnsServices = mdnsServices
        self.category = category
        self.notes = notes
    }
}

public struct DriftEvent: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var hostId: String
    public var hostIp: String
    public var hostname: String
    public var type: String // "new_host", "port_opened", "port_closed", "ip_changed", "offline"
    public var detail: String
    public var timestamp: Date
    public var acknowledged: Bool

    public init(id: String = UUID().uuidString,
                hostId: String,
                hostIp: String,
                hostname: String,
                type: String,
                detail: String,
                timestamp: Date = Date(),
                acknowledged: Bool = false) {
        self.id = id
        self.hostId = hostId
        self.hostIp = hostIp
        self.hostname = hostname
        self.type = type
        self.detail = detail
        self.timestamp = timestamp
        self.acknowledged = acknowledged
    }
}

public enum SidebarTab: Hashable, Codable {
    case allHosts
    case driftAlerts
    case servers
    case iotDevices
    case settings
}

@MainActor
public final class DrifterStore: ObservableObject {
    @Published public var activeTab: SidebarTab = .allHosts
    @Published public var selectedHostId: String? = nil
    @Published public private(set) var hosts: [HostItem] = []
    @Published public private(set) var driftEvents: [DriftEvent] = []
    @Published public var settings: AppSettings = AppSettings()
    @Published public var isScanning: Bool = false
    @Published public var lastScanDate: Date? = nil

    private let storageFileURL: URL

    public init(storageFileURL: URL? = nil) {
        if let storageFileURL {
            self.storageFileURL = storageFileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("DrifterMac", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageFileURL = dir.appendingPathComponent("drifter_store.json")
        }
        loadStore()
        purgeSampleHostsIfNeeded()
    }

    private func loadStore() {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(StoreData.self, from: data)
            self.hosts = decoded.hosts
            self.driftEvents = decoded.driftEvents
            self.settings = decoded.settings ?? AppSettings()
        } catch {
            print("[DrifterStore] Error loading store: \(error)")
        }
    }

    private func purgeSampleHostsIfNeeded() {
        // Purge initial hardcoded 192.168.1.* sample items if user is on a different subnet
        if hosts.contains(where: { $0.ip == "192.168.1.140" || $0.ip == "192.168.1.50" }) {
            hosts.removeAll { $0.ip.hasPrefix("192.168.1.") }
            driftEvents.removeAll { $0.hostIp.hasPrefix("192.168.1.") }
            saveStore()
        }
    }

    public func saveStore() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(StoreData(hosts: hosts, driftEvents: driftEvents, settings: settings))
            try data.write(to: storageFileURL, options: .atomic)
        } catch {
            print("[DrifterStore] Error saving store: \(error)")
        }
    }

    public func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        saveStore()
    }

    public func updateHost(_ host: HostItem) {
        if let idx = hosts.firstIndex(where: { $0.id == host.id || ($0.mac.lowercased() == host.mac.lowercased() && !$0.mac.isEmpty) }) {
            hosts[idx] = host
        } else {
            hosts.append(host)
        }
        saveStore()
    }

    public func removeHost(id: String) {
        hosts.removeAll { $0.id == id }
        saveStore()
    }

    public func addDriftEvent(_ event: DriftEvent) {
        driftEvents.insert(event, at: 0)
        saveStore()
        MenuBarManager.shared.postNotification(for: event)
    }

    public func acknowledgeEvent(id: String) {
        if let idx = driftEvents.firstIndex(where: { $0.id == id }) {
            driftEvents[idx].acknowledged = true
            saveStore()
        }
    }

    public func clearDriftEvents() {
        driftEvents.removeAll()
        saveStore()
    }

    private struct StoreData: Codable {
        let hosts: [HostItem]
        let driftEvents: [DriftEvent]
        let settings: AppSettings?
    }
}
