import Foundation
import AppKit
import UniformTypeIdentifiers

public final class AuditReportGenerator {
    @MainActor
    public static func exportReportToFile(content: String, defaultName: String, fileExtension: String) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(defaultName).\(fileExtension)"
        if let type = UTType(filenameExtension: fileExtension) {
            savePanel.allowedContentTypes = [type]
        }
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    @MainActor
    public static func copyReportToClipboard(content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    public static func generateMarkdownReport(
        hosts: [HostItem],
        events: [DriftEvent],
        baselineLockDate: Date?
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let nowStr = formatter.string(from: Date())
        let baselineStr = baselineLockDate != nil ? formatter.string(from: baselineLockDate!) : "None (Rolling audit mode)"

        let totalHosts = hosts.count
        let approvedCount = hosts.filter { $0.isApprovedHost }.count
        let unapprovedCount = totalHosts - approvedCount
        let driftCount = hosts.filter { $0.status == "drift" }.count
        let unackEvents = events.filter { !$0.acknowledged }.count

        var md = """
        # Drifter Network Security & Baseline Audit Report

        **Generated:** \(nowStr)  
        **Authoritative Baseline:** \(baselineStr)  

        ---

        ## 1. Executive Summary

        | Metric | Value | Status |
        | :--- | :--- | :--- |
        | **Monitored Hosts** | \(totalHosts) | Active |
        | **Approved Hosts** | \(approvedCount) | \(unapprovedCount == 0 ? "🟢 100% Compliant" : "🟡 Review Pending") |
        | **Unapproved / Rogue Hosts** | \(unapprovedCount) | \(unapprovedCount > 0 ? "🔴 Action Required" : "🟢 Clean") |
        | **Hosts with Active Drift** | \(driftCount) | \(driftCount > 0 ? "⚠️ Port Divergence" : "🟢 Baseline Aligned") |
        | **Unacknowledged Alerts** | \(unackEvents) | \(unackEvents > 0 ? "⚠️ Open" : "🟢 Acknowledged") |

        ---

        ## 2. Host Baseline Inventory Matrix

        | Status | IP Address | Hostname | MAC Address | Vendor | Open Ports | Baseline Ports | Divergence |
        | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |

        """

        for host in hosts.sorted(by: { $0.ip < $1.ip }) {
            let statusIcon: String
            if !host.isApprovedHost {
                statusIcon = "🔴 Rogue/Unapproved"
            } else if host.status == "drift" {
                statusIcon = "🟡 Port Drift"
            } else {
                statusIcon = "🟢 Approved"
            }

            let openPortsStr = host.openPorts.isEmpty ? "None" : host.openPorts.map(String.init).joined(separator: ", ")
            let baselinePortsStr = host.baselinePorts == nil ? "Not Locked" : (host.baselinePorts!.isEmpty ? "None" : host.baselinePorts!.map(String.init).joined(separator: ", "))

            var divergence = "None"
            if let base = host.baselinePorts {
                let opened = Set(host.openPorts).subtracting(Set(base))
                let closed = Set(base).subtracting(Set(host.openPorts))
                var parts: [String] = []
                if !opened.isEmpty { parts.append("+\(opened.sorted().map(String.init).joined(separator: ","))") }
                if !closed.isEmpty { parts.append("-\(closed.sorted().map(String.init).joined(separator: ","))") }
                if !parts.isEmpty { divergence = parts.joined(separator: " ") }
            }

            let hostname = host.hostname.isEmpty ? "-" : host.hostname
            let mac = host.mac.isEmpty ? "-" : host.mac
            let vendor = host.vendor.isEmpty ? "-" : host.vendor

            md += "| \(statusIcon) | `\(host.ip)` | \(hostname) | `\(mac)` | \(vendor) | \(openPortsStr) | \(baselinePortsStr) | `\(divergence)` |\n"
        }

        md += "\n---\n\n## 3. Active Drift & Security Events\n\n"

        if events.isEmpty {
            md += "*No drift events logged.*\n"
        } else {
            md += "| Timestamp | Type | Host | Details | Acknowledged |\n"
            md += "| :--- | :--- | :--- | :--- | :--- |\n"
            for ev in events {
                let timeStr = formatter.string(from: ev.timestamp)
                let hostDisplay = ev.hostname.isEmpty ? ev.hostIp : "\(ev.hostname) (`\(ev.hostIp)`)"
                let ackStr = ev.acknowledged ? "Yes" : "🔴 No"
                md += "| \(timeStr) | `\(ev.type)` | \(hostDisplay) | \(ev.detail) | \(ackStr) |\n"
            }
        }

        md += "\n---\n\n*Report generated natively by Drifter Mac Network Watchdog.*\n"
        return md
    }

    public static func generateJSONReport(
        hosts: [HostItem],
        events: [DriftEvent],
        baselineLockDate: Date?
    ) -> String {
        struct ExportPayload: Codable {
            let generatedAt: Date
            let baselineLockDate: Date?
            let hosts: [HostItem]
            let driftEvents: [DriftEvent]
        }

        let payload = ExportPayload(
            generatedAt: Date(),
            baselineLockDate: baselineLockDate,
            hosts: hosts,
            driftEvents: events
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonStr
    }
}
