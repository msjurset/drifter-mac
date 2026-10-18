import XCTest
import SwiftUI
import AppKit
@testable import Drifter

struct DocCallout: Identifiable {
    let number: Int
    let title: String
    let subtitle: String
    let targetRect: CGRect
    let badgeCenter: CGPoint
    let color: Color

    var id: Int { number }

    var estimatedBadgeRect: CGRect {
        let charCount = max(title.count, subtitle.count)
        let width = max(185.0, min(265.0, CGFloat(charCount) * 6.5 + 56.0))
        let height: CGFloat = 46.0
        return CGRect(
            x: badgeCenter.x - width / 2.0,
            y: badgeCenter.y - height / 2.0,
            width: width,
            height: height
        )
    }

    var targetAnchorPoint: CGPoint {
        let clampedX = min(max(badgeCenter.x, targetRect.minX), targetRect.maxX)
        let clampedY = min(max(badgeCenter.y, targetRect.minY), targetRect.maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }
}

struct AnnotatedScreenshotCanvas<Content: View>: View {
    let content: Content
    let callouts: [DocCallout]
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .frame(width: size.width, height: size.height)

            Canvas { context, _ in
                for callout in callouts {
                    let start = callout.badgeCenter
                    let end = callout.targetAnchorPoint

                    var glowPath = Path()
                    glowPath.move(to: start)
                    glowPath.addLine(to: end)
                    context.stroke(
                        glowPath,
                        with: .color(.black.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )

                    var linePath = Path()
                    linePath.move(to: start)
                    linePath.addLine(to: end)
                    context.stroke(
                        linePath,
                        with: .color(callout.color),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [6, 4])
                    )

                    let dotRect = CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: dotRect), with: .color(callout.color))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.8)
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            ForEach(callouts) { callout in
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.black.opacity(0.65), lineWidth: 4.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(callout.color, lineWidth: 2.2)
                    )
                    .frame(width: callout.targetRect.width, height: callout.targetRect.height)
                    .position(x: callout.targetRect.midX, y: callout.targetRect.midY)
            }

            ForEach(callouts) { callout in
                HStack(spacing: 8) {
                    Text("\(callout.number)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(callout.color))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(callout.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(callout.subtitle)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(callout.color, lineWidth: 1.6)
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
                .position(x: callout.badgeCenter.x, y: callout.badgeCenter.y)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

final class DrifterDocsScreenshotTests: XCTestCase {
    @MainActor
    private func makeSyntheticStore() -> DrifterStore {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("drifter-docs-\(UUID().uuidString).json")
        let store = DrifterStore(storageFileURL: tempURL)

        let now = Date()
        let hosts: [HostItem] = [
            HostItem(
                id: "host-proxmox",
                ip: "10.0.20.10",
                mac: "BC:24:11:4A:80:01",
                hostname: "pve-cluster-01.lan",
                vendor: "Proxmox Server Solutions",
                status: "online",
                lastSeen: now,
                openPorts: [22, 80, 443, 8006, 9090],
                mdnsServices: ["_ssh._tcp.local (pve-cluster-01)", "_https._tcp.local (pve-web)"],
                category: "server",
                notes: "Primary virtualization hypervisor",
                baselinePorts: [22, 80, 443, 8006, 9090],
                isApprovedHost: true
            ),
            HostItem(
                id: "host-synology",
                ip: "10.0.20.15",
                mac: "00:11:32:9C:41:22",
                hostname: "nas-vault-01.lan",
                vendor: "Synology Incorporated",
                status: "drift",
                lastSeen: now,
                openPorts: [22, 80, 443, 445, 5000, 5001, 9443],
                mdnsServices: ["_smb._tcp.local (nas-vault-01)", "_http._tcp.local (Synology DSM)"],
                category: "server",
                notes: "ZFS & SMB storage array",
                baselinePorts: [22, 80, 443, 445, 5000, 5001],
                isApprovedHost: true
            ),
            HostItem(
                id: "host-homeassistant",
                ip: "10.0.20.24",
                mac: "DC:A6:32:7E:19:50",
                hostname: "home-automation.lan",
                vendor: "Raspberry Pi Trading",
                status: "online",
                lastSeen: now,
                openPorts: [22, 1883, 8123],
                mdnsServices: ["_home-assistant._tcp.local (Home Assistant)", "_matter._tcp.local"],
                category: "iot",
                notes: "Zigbee/Matter automation coordinator",
                baselinePorts: [22, 1883, 8123],
                isApprovedHost: true
            ),
            HostItem(
                id: "host-pihole",
                ip: "10.0.20.53",
                mac: "E4:5F:01:33:8B:12",
                hostname: "dns-sinkhole-01.lan",
                vendor: "Raspberry Pi Trading",
                status: "online",
                lastSeen: now,
                openPorts: [22, 53, 80, 443],
                mdnsServices: ["_http._tcp.local (Pi-hole DNS)"],
                category: "server",
                notes: "Primary internal DNS resolver",
                baselinePorts: [22, 53, 80, 443],
                isApprovedHost: true
            ),
            HostItem(
                id: "host-esp-env",
                ip: "10.0.20.118",
                mac: "30:AE:A4:88:21:09",
                hostname: "esphome-rack-sensor.lan",
                vendor: "Espressif Inc.",
                status: "online",
                lastSeen: now,
                openPorts: [80],
                mdnsServices: ["_esphomelib._tcp.local (esphome-rack-sensor)"],
                category: "iot",
                notes: "Server closet temperature & humidity sensor",
                baselinePorts: [80],
                isApprovedHost: true
            ),
            HostItem(
                id: "host-rogue-cam",
                ip: "10.0.20.184",
                mac: "7C:D9:5C:14:90:E2",
                hostname: "iot-cam-garage.lan",
                vendor: "Espressif Inc.",
                status: "drift",
                lastSeen: now,
                openPorts: [22, 80, 8080],
                mdnsServices: ["_http._tcp.local (iot-cam-garage)"],
                category: "iot",
                notes: "Unapproved IoT camera joined subnet",
                baselinePorts: nil,
                isApprovedHost: false
            )
        ]

        let events: [DriftEvent] = [
            DriftEvent(
                id: "evt-1",
                hostId: "host-synology",
                hostIp: "10.0.20.15",
                hostname: "nas-vault-01.lan",
                type: "port_opened",
                detail: "Port 9443 (Portainer HTTPS) opened on nas-vault-01.lan (baseline: 22, 80, 443, 445, 5000, 5001)",
                timestamp: now.addingTimeInterval(-420),
                acknowledged: false
            ),
            DriftEvent(
                id: "evt-2",
                hostId: "host-rogue-cam",
                hostIp: "10.0.20.184",
                hostname: "iot-cam-garage.lan",
                type: "new_host",
                detail: "Unapproved host discovered at 10.0.20.184 (MAC: 7C:D9:5C:14:90:E2, Vendor: Espressif Inc.)",
                timestamp: now.addingTimeInterval(-1380),
                acknowledged: false
            ),
            DriftEvent(
                id: "evt-3",
                hostId: "host-proxmox",
                hostIp: "10.0.20.10",
                hostname: "pve-cluster-01.lan",
                type: "port_closed",
                detail: "Port 3000 closed on pve-cluster-01.lan after maintenance window",
                timestamp: now.addingTimeInterval(-5400),
                acknowledged: true
            )
        ]

        let settings = AppSettings(
            preferredTerminal: .ghostty,
            defaultSSHUser: "admin",
            customTerminalCommand: "ghostty -e ssh {ip}",
            notifyOnDrift: true,
            enableRunbookIntegration: true,
            runbookURLTemplate: "runbook://execute?template=security-audit&host={ip}",
            backgroundScanIntervalMinutes: 15,
            showMenuBarItem: true,
            aiSettings: AISettings(
                enabled: true,
                provider: .ollama,
                apiKey: "",
                endpointURL: "http://localhost:11434",
                customModelName: "llama3.2",
                deepReasoning: true
            )
        )

        store.seedSyntheticState(
            hosts: hosts,
            driftEvents: events,
            settings: settings,
            activeTab: .allHosts,
            selectedHostId: "host-synology",
            lastScanDate: now,
            lastBaselineLockDate: now.addingTimeInterval(-86400)
        )
        return store
    }

    @MainActor
    private func assertNoCalloutOverlaps(callouts: [DocCallout], size: CGSize, path: String) {
        let canvasBounds = CGRect(origin: .zero, size: size)
        for i in 0..<callouts.count {
            let b1 = callouts[i].estimatedBadgeRect
            XCTAssertTrue(
                canvasBounds.contains(b1),
                "Callout #\(callouts[i].number) badge \(b1) clips outside canvas \(canvasBounds) in \(path)"
            )
            for j in (i + 1)..<callouts.count {
                let b2 = callouts[j].estimatedBadgeRect
                XCTAssertFalse(
                    b1.intersects(b2),
                    "Callout #\(callouts[i].number) badge overlaps Callout #\(callouts[j].number) badge in \(path)"
                )
            }
            for target in callouts {
                XCTAssertFalse(
                    b1.intersects(target.targetRect),
                    "Callout #\(callouts[i].number) badge overlaps target highlight #\(target.number) in \(path)"
                )
            }
        }
    }

    @MainActor
    private func renderAnnotatedSnapshot<V: View>(
        _ view: V,
        callouts: [DocCallout],
        size: CGSize,
        to paths: [String]
    ) throws {
        assertNoCalloutOverlaps(callouts: callouts, size: size, path: paths.first ?? "snapshot")

        let annotated = AnnotatedScreenshotCanvas(content: view, callouts: callouts, size: size)
            .environment(\.colorScheme, .dark)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        let hostingView = NSHostingView(rootView: annotated)
        hostingView.frame = NSRect(origin: .zero, size: size)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to allocate bitmapImageRep")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG")
            return
        }

        for path in paths {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try pngData.write(to: url)
        }
    }

    @MainActor
    func testGenerateAnnotatedDocumentationScreenshots() throws {
        let size = CGSize(width: 1280, height: 820)
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetsDir = repoRoot.appendingPathComponent("docs/assets")
        let imagesDir = repoRoot.appendingPathComponent("docs/images")

        // 1. All Hosts Dashboard & Host Inspector
        let dashboardStore = makeSyntheticStore()
        dashboardStore.activeTab = .allHosts
        dashboardStore.selectedHostId = "host-synology"
        let dashboardCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Sidebar & Baseline Status",
                subtitle: "Switch views & trigger subnet sweeps",
                targetRect: CGRect(x: 8, y: 24, width: 204, height: 265),
                badgeCenter: CGPoint(x: 145, y: 350),
                color: .blue
            ),
            DocCallout(
                number: 2,
                title: "Tokenized Host Filter",
                subtitle: "Filter by ip:, status:drift, or port:",
                targetRect: CGRect(x: 228, y: 10, width: 264, height: 42),
                badgeCenter: CGPoint(x: 360, y: 540),
                color: .cyan
            ),
            DocCallout(
                number: 3,
                title: "1-Click Operational Actions",
                subtitle: "SSH, Web, Wake, Deep Scan & Runbook",
                targetRect: CGRect(x: 524, y: 98, width: 690, height: 44),
                badgeCenter: CGPoint(x: 1030, y: 52),
                color: .orange
            ),
            DocCallout(
                number: 4,
                title: "Homelab Service Launchers",
                subtitle: "Auto-detected DSM, Portainer & Web UIs",
                targetRect: CGRect(x: 514, y: 380, width: 750, height: 96),
                badgeCenter: CGPoint(x: 1030, y: 325),
                color: .purple
            ),
            DocCallout(
                number: 5,
                title: "Open Ports & mDNS Discovery",
                subtitle: "Click any TCP port for security explainer",
                targetRect: CGRect(x: 514, y: 498, width: 750, height: 162),
                badgeCenter: CGPoint(x: 1030, y: 745),
                color: .green
            )
        ]
        try renderAnnotatedSnapshot(
            MainView(store: dashboardStore, autoScanOnEmpty: false),
            callouts: dashboardCallouts,
            size: size,
            to: [
                assetsDir.appendingPathComponent("network_dashboard.png").path,
                imagesDir.appendingPathComponent("dashboard.png").path
            ]
        )

        // 2. Drift & Security Alerts
        let alertsStore = makeSyntheticStore()
        alertsStore.activeTab = .driftAlerts
        let alertsCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Authoritative Baseline Badge",
                subtitle: "Shows Locked vs Rolling baseline state",
                targetRect: CGRect(x: 235, y: 14, width: 410, height: 52),
                badgeCenter: CGPoint(x: 430, y: 410),
                color: .green
            ),
            DocCallout(
                number: 2,
                title: "AI Triage & Audit Export",
                subtitle: "Synthesize alerts or export MD/JSON",
                targetRect: CGRect(x: 755, y: 16, width: 510, height: 44),
                badgeCenter: CGPoint(x: 1010, y: 410),
                color: .purple
            ),
            DocCallout(
                number: 3,
                title: "Drift Event & Port Explainer",
                subtitle: "Click badge for port risk & remediation",
                targetRect: CGRect(x: 235, y: 82, width: 760, height: 195),
                badgeCenter: CGPoint(x: 560, y: 510),
                color: .orange
            ),
            DocCallout(
                number: 4,
                title: "Runbook, Approve & Ack",
                subtitle: "Merge into baseline or trigger playbook",
                targetRect: CGRect(x: 1020, y: 82, width: 245, height: 195),
                badgeCenter: CGPoint(x: 1040, y: 510),
                color: .blue
            )
        ]
        try renderAnnotatedSnapshot(
            MainView(store: alertsStore, autoScanOnEmpty: false),
            callouts: alertsCallouts,
            size: size,
            to: [
                assetsDir.appendingPathComponent("drift_alerts.png").path,
                imagesDir.appendingPathComponent("alerts.png").path
            ]
        )

        // 3. Device Categories & IoT Discovery
        let categoriesStore = makeSyntheticStore()
        categoriesStore.activeTab = .iotDevices
        categoriesStore.selectedHostId = "host-homeassistant"
        let categoriesCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Device Category Filters",
                subtitle: "Slice inventory into Servers vs IoT",
                targetRect: CGRect(x: 8, y: 112, width: 204, height: 84),
                badgeCenter: CGPoint(x: 145, y: 340),
                color: .cyan
            ),
            DocCallout(
                number: 2,
                title: "Filtered IoT & Smart Home List",
                subtitle: "Displays matching category devices",
                targetRect: CGRect(x: 228, y: 62, width: 264, height: 195),
                badgeCenter: CGPoint(x: 360, y: 430),
                color: .green
            ),
            DocCallout(
                number: 3,
                title: "Interactive Category Assignment",
                subtitle: "Reassign device profile classification",
                targetRect: CGRect(x: 514, y: 175, width: 390, height: 190),
                badgeCenter: CGPoint(x: 1085, y: 265),
                color: .orange
            ),
            DocCallout(
                number: 4,
                title: "Bonjour / mDNS Broadcasts",
                subtitle: "Discovers _home-assistant & _matter",
                targetRect: CGRect(x: 514, y: 622, width: 750, height: 106),
                badgeCenter: CGPoint(x: 1030, y: 565),
                color: .purple
            )
        ]
        try renderAnnotatedSnapshot(
            MainView(store: categoriesStore, autoScanOnEmpty: false),
            callouts: categoriesCallouts,
            size: size,
            to: [
                assetsDir.appendingPathComponent("device_categories.png").path,
                imagesDir.appendingPathComponent("categories.png").path
            ]
        )

        // 4. Settings, Watchdog & AI Security Advisor
        let settingsStore = makeSyntheticStore()
        settingsStore.activeTab = .settings
        let settingsCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Terminal & SSH Dispatch",
                subtitle: "Ghostty, Terminal, iTerm2 & 1Password",
                targetRect: CGRect(x: 236, y: 102, width: 680, height: 255),
                badgeCenter: CGPoint(x: 1085, y: 220),
                color: .blue
            ),
            DocCallout(
                number: 2,
                title: "Runbook Deep-Link Template",
                subtitle: "Parameterized runbook:// URI dispatch",
                targetRect: CGRect(x: 236, y: 375, width: 680, height: 145),
                badgeCenter: CGPoint(x: 1085, y: 445),
                color: .purple
            ),
            DocCallout(
                number: 3,
                title: "Watchdog & Menu Bar Polling",
                subtitle: "Configure automatic subnet sweep intervals",
                targetRect: CGRect(x: 236, y: 540, width: 680, height: 165),
                badgeCenter: CGPoint(x: 1085, y: 620),
                color: .orange
            ),
            DocCallout(
                number: 4,
                title: "Authoritative Baseline Controls",
                subtitle: "Lock gold-master state or export reports",
                targetRect: CGRect(x: 236, y: 722, width: 680, height: 92),
                badgeCenter: CGPoint(x: 1085, y: 765),
                color: .green
            )
        ]
        try renderAnnotatedSnapshot(
            MainView(store: settingsStore, autoScanOnEmpty: false),
            callouts: settingsCallouts,
            size: size,
            to: [
                assetsDir.appendingPathComponent("settings_scanner.png").path,
                imagesDir.appendingPathComponent("settings.png").path
            ]
        )
    }
}
