import AppKit
import SwiftUI
import Combine
import UserNotifications

@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private weak var store: DrifterStore?
    private var cancellables = Set<AnyCancellable>()

    public func setup(store: DrifterStore) {
        self.store = store
        requestNotificationPermissions()
        
        // Subscribe to driftEvents updates from the store
        cancellables.removeAll()
        store.$driftEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)

        guard statusItem == nil else {
            updateMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        updateMenu()
    }

    public func updateMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let titleItem = NSMenuItem(title: "Drifter Network Watchdog", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        if let store {
            let unackEvents = store.driftEvents.filter { !$0.acknowledged }
            let unackCount = unackEvents.count
            updateStatusIcon(unackCount: unackCount)

            let statusText = unackCount > 0 ? "⚠️ \(unackCount) Drift Alert(s) Active" : "✅ Network Baseline Clean"
            let statusMenuItem = NSMenuItem(title: statusText, action: unackCount > 0 ? #selector(openDriftAlertsTab) : nil, keyEquivalent: "")
            if unackCount > 0 {
                statusMenuItem.target = self
            } else {
                statusMenuItem.isEnabled = false
            }
            menu.addItem(statusMenuItem)

            if !unackEvents.isEmpty {
                menu.addItem(NSMenuItem.separator())
                
                let headerItem = NSMenuItem(title: "Active Drift Alerts:", action: #selector(openDriftAlertsTab), keyEquivalent: "")
                headerItem.target = self
                menu.addItem(headerItem)

                for event in unackEvents.prefix(5) {
                    let hostName = event.hostname.isEmpty ? event.hostIp : event.hostname
                    let itemTitle = " • [\(event.type.replacingOccurrences(of: "_", with: " ").capitalized)] \(hostName): \(event.detail)"
                    let alertItem = NSMenuItem(title: itemTitle, action: #selector(openDriftAlertsTab), keyEquivalent: "")
                    alertItem.target = self
                    menu.addItem(alertItem)
                }

                if unackEvents.count > 5 {
                    let moreItem = NSMenuItem(title: " ...and \(unackEvents.count - 5) more alert(s)", action: #selector(openDriftAlertsTab), keyEquivalent: "")
                    moreItem.target = self
                    menu.addItem(moreItem)
                }
            }
        }

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: "o")
        showItem.target = self
        menu.addItem(showItem)

        let scanItem = NSMenuItem(title: "Scan Subnet Now", action: #selector(triggerScan), keyEquivalent: "r")
        scanItem.target = self
        menu.addItem(scanItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Drifter", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openDriftAlertsTab() {
        store?.activeTab = .driftAlerts
        showMainWindow()
    }

    private func updateStatusIcon(unackCount: Int) {
        guard let button = statusItem?.button else { return }
        let imageName = unackCount > 0 ? "exclamationmark.shield.fill" : "waveform.path.ecg"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Drifter Network Watchdog")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        }
        button.toolTip = unackCount > 0 ? "Drifter: \(unackCount) active drift alert(s)" : "Drifter Network Watchdog"
    }

    private var isRunningInTestEnvironment: Bool {
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        (Bundle.main.bundleIdentifier?.lowercased().contains("xctest") ?? false)
    }

    private func requestNotificationPermissions() {
        guard !isRunningInTestEnvironment else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    public func postNotification(for event: DriftEvent) {
        guard store?.settings.notifyOnDrift ?? true else { return }
        guard !isRunningInTestEnvironment else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Drifter Alert: \(event.type.replacingOccurrences(of: "_", with: " ").capitalized)"
        content.subtitle = event.hostname.isEmpty ? event.hostIp : event.hostname
        content.body = event.detail
        content.sound = .default

        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func triggerScan() {
        guard let store else { return }
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
            self.updateMenu()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension MenuBarManager: NSMenuDelegate {
    public func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }
}
