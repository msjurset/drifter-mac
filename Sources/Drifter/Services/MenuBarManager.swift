import AppKit
import SwiftUI

@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private weak var store: DrifterStore?

    public func setup(store: DrifterStore) {
        self.store = store
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Drifter Network Watchdog")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "Drifter Network Watchdog"
        }

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
            let unack = store.driftEvents.filter { !$0.acknowledged }.count
            let statusText = unack > 0 ? "⚠️ \(unack) Drift Alert(s) Active" : "✅ Network Baseline Clean"
            let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            statusMenuItem.isEnabled = false
            menu.addItem(statusMenuItem)
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
