import SwiftUI

public struct MainView: View {
    @ObservedObject var store: DrifterStore
    @State private var filterText: String
    private let autoScanOnEmpty: Bool

    @AppStorage("drifter_sidebarWidth") private var sidebarWidth: Double = 220
    @AppStorage("drifter_hostListWidth") private var hostListWidth: Double = 280

    public init(store: DrifterStore = DrifterStore(), initialFilter: String = "", autoScanOnEmpty: Bool = true) {
        self.store = store
        self._filterText = State(initialValue: initialFilter)
        self.autoScanOnEmpty = autoScanOnEmpty
    }

    private var sidebarWidthBinding: Binding<CGFloat> {
        Binding<CGFloat>(
            get: { CGFloat(sidebarWidth) },
            set: { sidebarWidth = Double($0) }
        )
    }

    private var hostListWidthBinding: Binding<CGFloat> {
        Binding<CGFloat>(
            get: { CGFloat(hostListWidth) },
            set: { hostListWidth = Double($0) }
        )
    }

    var selectedHost: HostItem? {
        store.hosts.first(where: { $0.id == store.selectedHostId })
    }

    var serverCount: Int {
        store.hosts.filter { $0.category == "server" }.count
    }

    var iotCount: Int {
        store.hosts.filter { $0.category == "iot" }.count
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $store.activeTab) {
                    Section("Network Dashboard") {
                        Label("All Hosts (\(store.hosts.count))", systemImage: "network")
                            .tag(SidebarTab.allHosts)

                        Label("Drift Alerts (\(store.driftEvents.filter { !$0.acknowledged }.count))", systemImage: "exclamationmark.shield")
                            .tag(SidebarTab.driftAlerts)
                    }

                    Section("Device Categories") {
                        Label("Servers & Storage (\(serverCount))", systemImage: "server.rack")
                            .tag(SidebarTab.servers)

                        Label("IoT & Microservices (\(iotCount))", systemImage: "cpu")
                            .tag(SidebarTab.iotDevices)
                    }

                    Section("Configuration") {
                        Label("Settings", systemImage: "gear")
                            .tag(SidebarTab.settings)

                        Label("User Guide & Help", systemImage: "book.pages")
                            .tag(SidebarTab.help)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Button {
                            Task {
                                store.isScanning = true
                                let scanned = await NetworkScanner.shared.scanLocalSubnet()
                                let drift = DriftDetector.computeDrift(existingHosts: store.hosts, newHosts: scanned)
                                for updated in drift.updatedHosts {
                                    store.updateHost(updated)
                                }
                                for event in drift.events {
                                    store.addDriftEvent(event)
                                }
                                store.lastScanDate = Date()
                                store.isScanning = false
                                MenuBarManager.shared.updateMenu()
                            }
                        } label: {
                            HStack {
                                if store.isScanning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(store.isScanning ? "Scanning Subnet..." : "Scan Local Network")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isScanning)
                        .focusable(false)

                        if let lastScan = store.lastScanDate {
                            Text("Last scan: \(lastScan.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if store.lastBaselineLockDate != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("Baseline: Locked")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .frame(width: max(200, CGFloat(sidebarWidth)), alignment: .leading)

            DraggableDivider(
                width: sidebarWidthBinding,
                minWidth: 200,
                maxWidth: 360,
                defaultWidth: 220
            )

            if store.activeTab == .driftAlerts {
                DriftAlertsView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.activeTab == .settings {
                SettingsView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.activeTab == .help {
                HelpView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    HostListView(
                        store: store,
                        activeTab: store.activeTab,
                        selectedHostId: $store.selectedHostId,
                        filterText: $filterText
                    )
                    .frame(width: max(240, CGFloat(hostListWidth)), alignment: .leading)

                    DraggableDivider(
                        width: hostListWidthBinding,
                        minWidth: 240,
                        maxWidth: 450,
                        defaultWidth: 280
                    )

                    if let selectedHost {
                        HostDetailView(host: selectedHost, store: store)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Drifter Network Watchdog")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Select a host from the list to view profile, ports, and drift events.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 920, minHeight: 580)
        .onAppear {
            guard autoScanOnEmpty else { return }
            MenuBarManager.shared.setup(store: store)
            if store.hosts.isEmpty {
                Task {
                    store.isScanning = true
                    let scanned = await NetworkScanner.shared.scanLocalSubnet()
                    let drift = DriftDetector.computeDrift(existingHosts: store.hosts, newHosts: scanned)
                    for updated in drift.updatedHosts {
                        store.updateHost(updated)
                    }
                    for event in drift.events {
                        store.addDriftEvent(event)
                    }
                    store.lastScanDate = Date()
                    store.isScanning = false
                    MenuBarManager.shared.updateMenu()
                }
            }
        }
    }
}
