import Foundation
import Combine
import SwiftUI

public enum TerminalApp: String, CaseIterable, Identifiable, Codable, Sendable {
    case ghostty = "Ghostty"
    case terminal = "Apple Terminal"
    case iterm = "iTerm2"
    case custom = "Custom Command"

    public var id: String { rawValue }
}

public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case ollama = "Ollama (Local)"
    case gemini = "Google Gemini"
    case anthropic = "Anthropic Claude"
    case openai = "OpenAI"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .ollama: return "llama3.2"
        case .gemini: return "gemini-2.5-flash"
        case .anthropic: return "claude-3-5-haiku-latest"
        case .openai: return "gpt-4o-mini"
        }
    }

    public var requiresAPIKey: Bool {
        self != .ollama
    }
}

public struct AISettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var provider: AIProvider
    public var apiKey: String
    public var endpointURL: String
    public var customModelName: String
    public var deepReasoning: Bool

    enum CodingKeys: String, CodingKey {
        case enabled, provider, apiKey, endpointURL, customModelName, deepReasoning
    }

    public init(enabled: Bool = false,
                provider: AIProvider = .ollama,
                apiKey: String = "",
                endpointURL: String = "http://localhost:11434",
                customModelName: String = "",
                deepReasoning: Bool = false) {
        self.enabled = enabled
        self.provider = provider
        self.apiKey = apiKey
        self.endpointURL = endpointURL
        self.customModelName = customModelName
        self.deepReasoning = deepReasoning
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        provider = try container.decodeIfPresent(AIProvider.self, forKey: .provider) ?? .ollama
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        endpointURL = try container.decodeIfPresent(String.self, forKey: .endpointURL) ?? "http://localhost:11434"
        customModelName = try container.decodeIfPresent(String.self, forKey: .customModelName) ?? ""
        deepReasoning = try container.decodeIfPresent(Bool.self, forKey: .deepReasoning) ?? false
    }

    public var activeModel: String {
        let trimmed = customModelName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var preferredTerminal: TerminalApp
    public var defaultSSHUser: String
    public var customTerminalCommand: String
    public var notifyOnDrift: Bool
    public var enableRunbookIntegration: Bool
    public var runbookURLTemplate: String
    public var backgroundScanIntervalMinutes: Int
    public var showMenuBarItem: Bool
    public var aiSettings: AISettings

    enum CodingKeys: String, CodingKey {
        case preferredTerminal, defaultSSHUser, customTerminalCommand, notifyOnDrift, enableRunbookIntegration, runbookURLTemplate, backgroundScanIntervalMinutes, showMenuBarItem, aiSettings
    }

    public init(preferredTerminal: TerminalApp = .ghostty,
                defaultSSHUser: String = "",
                customTerminalCommand: String = "ghostty -e ssh {ip}",
                notifyOnDrift: Bool = true,
                enableRunbookIntegration: Bool = true,
                runbookURLTemplate: String = "runbook://execute?template=security-audit&host={ip}",
                backgroundScanIntervalMinutes: Int = 0,
                showMenuBarItem: Bool = true,
                aiSettings: AISettings = AISettings()) {
        self.preferredTerminal = preferredTerminal
        self.defaultSSHUser = defaultSSHUser
        self.customTerminalCommand = customTerminalCommand
        self.notifyOnDrift = notifyOnDrift
        self.enableRunbookIntegration = enableRunbookIntegration
        self.runbookURLTemplate = runbookURLTemplate
        self.backgroundScanIntervalMinutes = backgroundScanIntervalMinutes
        self.showMenuBarItem = showMenuBarItem
        self.aiSettings = aiSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredTerminal = try container.decodeIfPresent(TerminalApp.self, forKey: .preferredTerminal) ?? .ghostty
        defaultSSHUser = try container.decodeIfPresent(String.self, forKey: .defaultSSHUser) ?? ""
        customTerminalCommand = try container.decodeIfPresent(String.self, forKey: .customTerminalCommand) ?? "ghostty -e ssh {ip}"
        notifyOnDrift = try container.decodeIfPresent(Bool.self, forKey: .notifyOnDrift) ?? true
        enableRunbookIntegration = try container.decodeIfPresent(Bool.self, forKey: .enableRunbookIntegration) ?? true
        runbookURLTemplate = try container.decodeIfPresent(String.self, forKey: .runbookURLTemplate) ?? "runbook://execute?template=security-audit&host={ip}"
        backgroundScanIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .backgroundScanIntervalMinutes) ?? 0
        showMenuBarItem = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarItem) ?? true
        aiSettings = try container.decodeIfPresent(AISettings.self, forKey: .aiSettings) ?? AISettings()
    }
}

public struct HostItem: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    public var baselinePorts: [Int]?
    public var isApprovedHost: Bool

    enum CodingKeys: String, CodingKey {
        case id, ip, mac, hostname, vendor, status, lastSeen, openPorts, mdnsServices, category, notes, baselinePorts, isApprovedHost
    }

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
                notes: String = "",
                baselinePorts: [Int]? = nil,
                isApprovedHost: Bool = true) {
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
        self.baselinePorts = baselinePorts
        self.isApprovedHost = isApprovedHost
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ip = try container.decode(String.self, forKey: .ip)
        mac = try container.decodeIfPresent(String.self, forKey: .mac) ?? ""
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "online"
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        openPorts = try container.decodeIfPresent([Int].self, forKey: .openPorts) ?? []
        mdnsServices = try container.decodeIfPresent([String].self, forKey: .mdnsServices) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "unknown"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        baselinePorts = try container.decodeIfPresent([Int].self, forKey: .baselinePorts)
        isApprovedHost = try container.decodeIfPresent(Bool.self, forKey: .isApprovedHost) ?? true
    }
}

public struct DriftEvent: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    case help
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
    @Published public var lastBaselineLockDate: Date? = nil

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
        autoCategorizeHostsIfNeeded()
    }

    public func seedSyntheticState(
        hosts: [HostItem],
        driftEvents: [DriftEvent],
        settings: AppSettings = AppSettings(),
        activeTab: SidebarTab = .allHosts,
        selectedHostId: String? = nil,
        lastScanDate: Date? = Date(),
        lastBaselineLockDate: Date? = nil
    ) {
        self.hosts = hosts
        self.driftEvents = driftEvents
        self.settings = settings
        self.activeTab = activeTab
        self.selectedHostId = selectedHostId ?? hosts.first?.id
        self.lastScanDate = lastScanDate
        self.lastBaselineLockDate = lastBaselineLockDate
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
            self.lastBaselineLockDate = decoded.lastBaselineLockDate
        } catch {
            print("[DrifterStore] Error loading store: \(error)")
        }
    }

    private func purgeSampleHostsIfNeeded() {
        // Purge old mock sample items if present
        if hosts.contains(where: { $0.id.hasPrefix("sample-") }) {
            hosts.removeAll { $0.id.hasPrefix("sample-") }
            driftEvents.removeAll { $0.hostId.hasPrefix("sample-") }
            saveStore()
        }
    }

    private func autoCategorizeHostsIfNeeded() {
        var didChange = false
        for idx in hosts.indices {
            let host = hosts[idx]
            let currentVendor = host.vendor
            let updatedVendor = (currentVendor.isEmpty || currentVendor == "Local Network Device")
                ? VendorLookup.lookup(mac: host.mac)
                : currentVendor

            if updatedVendor != currentVendor && !updatedVendor.isEmpty && updatedVendor != "Local Network Device" {
                hosts[idx].vendor = updatedVendor
                didChange = true
            }

            if host.category == "workstation" || host.category == "unknown" {
                let recomputed = NetworkScanner.categorizeHost(
                    vendor: hosts[idx].vendor,
                    hostname: host.hostname,
                    openPorts: host.openPorts,
                    mdnsServices: host.mdnsServices,
                    mac: host.mac
                )
                if recomputed != host.category && recomputed != "unknown" {
                    hosts[idx].category = recomputed
                    didChange = true
                }
            }
        }
        if didChange {
            saveStore()
        }
    }

    public func saveStore() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(StoreData(hosts: hosts, driftEvents: driftEvents, settings: settings, lastBaselineLockDate: lastBaselineLockDate))
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

    public func removeDriftEvent(id: String) {
        driftEvents.removeAll(where: { $0.id == id })
        saveStore()
    }

    /// Acknowledges all drift events currently recorded
    public func acknowledgeAllAlerts() {
        for idx in driftEvents.indices {
            driftEvents[idx].acknowledged = true
        }
        saveStore()
    }

    /// Locks the current network state (all known hosts and their current open ports) as the authoritative baseline.
    public func lockBaseline(acknowledgeActiveAlerts: Bool = false) {
        for idx in hosts.indices {
            hosts[idx].baselinePorts = hosts[idx].openPorts
            hosts[idx].isApprovedHost = true
            if hosts[idx].status == "drift" {
                hosts[idx].status = "online"
            }
        }
        if acknowledgeActiveAlerts {
            for idx in driftEvents.indices {
                driftEvents[idx].acknowledged = true
            }
        }
        self.lastBaselineLockDate = Date()
        saveStore()
    }

    /// Blesses all known hosts into baseline and acknowledges all active drift alerts in one step.
    public func blessAllIntoBaseline() {
        lockBaseline(acknowledgeActiveAlerts: true)
    }

    /// Updates the category for an individual host ("server", "iot", "workstation", "network", "unknown")
    public func updateHostCategory(id: String, category: String) {
        if let idx = hosts.firstIndex(where: { $0.id == id }) {
            hosts[idx].category = category.lowercased()
            saveStore()
        }
    }

    /// Re-evaluates categories for all existing hosts using updated vendor, mDNS, and port heuristics
    public func autoCategorizeHosts() {
        for idx in hosts.indices {
            let host = hosts[idx]
            let vendor = VendorLookup.lookup(mac: host.mac)
            if !vendor.isEmpty && vendor != "Local Network Device" {
                hosts[idx].vendor = vendor
            }
            hosts[idx].category = NetworkScanner.categorizeHost(
                vendor: hosts[idx].vendor,
                hostname: host.hostname,
                openPorts: host.openPorts,
                mdnsServices: host.mdnsServices,
                mac: host.mac
            )
        }
        saveStore()
    }

    /// Approves a specific drift event and merges the change into the target host's authoritative baseline.
    public func approveDrift(for event: DriftEvent) {
        if let idx = hosts.firstIndex(where: { $0.id == event.hostId || $0.ip == event.hostIp }) {
            var host = hosts[idx]
            host.isApprovedHost = true

            var approved = Set(host.baselinePorts ?? host.openPorts)
            if event.type == "port_opened" {
                for p in host.openPorts {
                    approved.insert(p)
                }
            } else if event.type == "port_closed" {
                approved = Set(host.openPorts)
            }
            host.baselinePorts = Array(approved).sorted()
            if Set(host.openPorts) == approved {
                host.status = "online"
            }
            hosts[idx] = host
            saveStore()
        }
        acknowledgeEvent(id: event.id)
    }

    /// Toggles approval status for an individual host
    public func toggleHostApproval(id: String) {
        if let idx = hosts.firstIndex(where: { $0.id == id }) {
            hosts[idx].isApprovedHost.toggle()
            if hosts[idx].isApprovedHost && hosts[idx].baselinePorts == nil {
                hosts[idx].baselinePorts = hosts[idx].openPorts
            }
            saveStore()
        }
    }

    private struct StoreData: Codable {
        let hosts: [HostItem]
        let driftEvents: [DriftEvent]
        let settings: AppSettings?
        let lastBaselineLockDate: Date?

        enum CodingKeys: String, CodingKey {
            case hosts, driftEvents, settings, lastBaselineLockDate
        }

        init(hosts: [HostItem], driftEvents: [DriftEvent], settings: AppSettings?, lastBaselineLockDate: Date? = nil) {
            self.hosts = hosts
            self.driftEvents = driftEvents
            self.settings = settings
            self.lastBaselineLockDate = lastBaselineLockDate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            hosts = try container.decodeIfPresent([HostItem].self, forKey: .hosts) ?? []
            driftEvents = try container.decodeIfPresent([DriftEvent].self, forKey: .driftEvents) ?? []
            settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings)
            lastBaselineLockDate = try container.decodeIfPresent(Date.self, forKey: .lastBaselineLockDate)
        }
    }
}
