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
    private var scanTimer: Timer?

    public func setup(store: DrifterStore) {
        self.store = store
        requestNotificationPermissions()
        
        cancellables.removeAll()
        store.$driftEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        store.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSettings in
                self?.configureWatchdogTimer()
                self?.configureStatusItem(enabled: newSettings.showMenuBarItem)
            }
            .store(in: &cancellables)

        configureWatchdogTimer()
        configureStatusItem(enabled: store.settings.showMenuBarItem)
    }

    public func configureStatusItem(enabled: Bool = true) {
        guard enabled else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(handleStatusItemClick)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            self.statusItem = item
        }
        updateStatusIcon()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu(sender)
        } else {
            toggleMainWindow()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = buildContextMenu()
        statusItem?.menu = menu
        sender.performClick(nil)
        statusItem?.menu = nil
    }

    public func configureWatchdogTimer() {
        scanTimer?.invalidate()
        scanTimer = nil

        guard let store else { return }
        let intervalMins = store.settings.backgroundScanIntervalMinutes
        guard intervalMins > 0 else { return }

        let seconds = TimeInterval(intervalMins * 60)
        scanTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performWatchdogScan()
            }
        }
    }

    public func performWatchdogScan() {
        guard let store, !store.isScanning else { return }
        Task { @MainActor in
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
            self.updateStatusIcon()
        }
    }

    public func updateMenu() {
        updateStatusIcon()
    }

    public func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Drifter Network Watchdog", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let interval = store?.settings.backgroundScanIntervalMinutes ?? 0
        let watchdogTitle = interval > 0 ? "Watchdog: Active (Every \(interval)m)" : "Watchdog: Manual Only"
        let watchdogItem = NSMenuItem(title: watchdogTitle, action: nil, keyEquivalent: "")
        watchdogItem.isEnabled = false
        menu.addItem(watchdogItem)

        if let store {
            let unackEvents = store.driftEvents.filter { !$0.acknowledged }
            let unackCount = unackEvents.count

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

        let baselineItem = NSMenuItem(title: "Lock Baseline Now", action: #selector(lockBaselineAction), keyEquivalent: "")
        baselineItem.target = self
        menu.addItem(baselineItem)

        let exportItem = NSMenuItem(title: "Export Audit Report...", action: #selector(exportAuditAction), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(NSMenuItem.separator())

        let restartItem = NSMenuItem(title: "Restart", action: #selector(restartApp), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func lockBaselineAction() {
        store?.lockBaseline()
        updateStatusIcon()
    }

    @objc private func exportAuditAction() {
        guard let store else { return }
        let report = AuditReportGenerator.generateMarkdownReport(
            hosts: store.hosts,
            events: store.driftEvents,
            baselineLockDate: store.lastBaselineLockDate
        )
        AuditReportGenerator.exportReportToFile(content: report, defaultName: "drifter_network_audit", fileExtension: "md")
    }

    @objc private func openDriftAlertsTab() {
        store?.activeTab = .driftAlerts
        showMainWindow()
    }

    private func updateStatusIcon() {
        let unackCount = store?.driftEvents.filter { !$0.acknowledged }.count ?? 0
        guard let button = statusItem?.button else { return }
        let imageName = unackCount > 0 ? "exclamationmark.shield.fill" : "waveform.path.ecg"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Drifter Network Watchdog")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        }
        button.toolTip = unackCount > 0 ? "Drifter: \(unackCount) active drift alert(s) (Right-click for options)" : "Drifter Network Watchdog (Right-click for options)"
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

    @objc public func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc public func toggleMainWindow() {
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            if window.isVisible && NSApp.isActive {
                window.orderOut(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
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
            self.updateStatusIcon()
        }
    }

    @objc private func restartApp() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open \"\(path)\""
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]
        task.launch()
        NSApp.terminate(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
