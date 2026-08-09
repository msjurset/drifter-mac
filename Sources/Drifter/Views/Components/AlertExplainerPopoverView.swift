import SwiftUI

public struct ExplainerInfo {
    public let title: String
    public let severity: Severity
    public let iconName: String
    public let iconColor: Color
    public let summary: String
    public let serviceContext: String?
    public let significance: String
    public let triageSteps: [String]
    
    public enum Severity {
        case low, medium, high
        
        public var title: String {
            switch self {
            case .low: return "Low Risk"
            case .medium: return "Medium Risk"
            case .high: return "High Severity"
            }
        }
        
        public var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

public enum AlertExplainerAnalyzer {
    public static func analyze(event: DriftEvent) -> ExplainerInfo {
        let text = event.detail
        let type = event.type
        
        var detectedPort: Int? = nil
        if let range = text.range(of: #"Port (\d+)"#, options: .regularExpression) {
            let digits = text[range].replacingOccurrences(of: "Port ", with: "")
            detectedPort = Int(digits)
        }
        
        let port = detectedPort ?? 0
        let service = serviceName(for: port)
        
        switch type {
        case "port_opened":
            let severity: ExplainerInfo.Severity = (port == 22 || port == 23 || port == 3389 || port == 80) ? .high : .medium
            return ExplainerInfo(
                title: "New Port Opened (\(port > 0 ? "Port \(port)" : "Unknown Port"))",
                severity: severity,
                iconName: "exclamationmark.triangle.fill",
                iconColor: .orange,
                summary: "Port \(port > 0 ? "\(port) (\(service))" : "listening service") was detected newly open on \(event.hostname.isEmpty ? event.hostIp : event.hostname).",
                serviceContext: port > 0 ? "Known Service: \(service)" : nil,
                significance: "A newly exposed port indicates a background daemon started, a Docker container published a port binding, or host firewall rules were relaxed. Unintended open ports expand the host attack surface.",
                triageSteps: [
                    "SSH into host and check listening process: lsof -i :\(port > 0 ? "\(port)" : "<port>") or netstat -tulpn",
                    "Verify if this service is intended for host profile \(event.hostname.isEmpty ? event.hostIp : event.hostname)",
                    "Run automated Runbook Security Audit to inspect firewall & active logins"
                ]
            )
            
        case "port_closed":
            return ExplainerInfo(
                title: "Port Closed (\(port > 0 ? "Port \(port)" : "Unknown Port"))",
                severity: .low,
                iconName: "lock.fill",
                iconColor: .blue,
                summary: "Port \(port > 0 ? "\(port) (\(service))" : "service port") is no longer responding on \(event.hostname.isEmpty ? event.hostIp : event.hostname).",
                serviceContext: port > 0 ? "Known Service: \(service)" : nil,
                significance: "Port closure means the underlying service daemon stopped, crashed, or was blocked by a host firewall. For network infrastructure nodes (Synology DSM, Home Assistant, Pi-hole), this can signal an outage.",
                triageSteps: [
                    "Check host reachability via Ping",
                    "SSH into host to inspect systemd service status: systemctl status <service>",
                    "Inspect system logs: journalctl -u <service> -n 50"
                ]
            )
            
        case "new_host":
            return ExplainerInfo(
                title: "New Network Host Discovered",
                severity: .medium,
                iconName: "plus.circle.fill",
                iconColor: .green,
                summary: "A new IP/MAC binding (\(event.hostIp)) appeared on your local subnet.",
                serviceContext: nil,
                significance: "New host alerts trigger whenever a device connects to Wi-Fi/Ethernet or receives a fresh DHCP lease. Unrecognized hosts could be unauthorized devices on your home lab network.",
                triageSteps: [
                    "Verify MAC address vendor identity in Host Details card",
                    "Check router DHCP lease logs to confirm device ownership",
                    "Probe common infrastructure ports to identify running microservices"
                ]
            )
            
        case "ip_changed":
            return ExplainerInfo(
                title: "Host IP Address Changed",
                severity: .low,
                iconName: "arrow.triangle.2.circlepath",
                iconColor: .purple,
                summary: "Host \(event.hostname.isEmpty ? event.hostIp : event.hostname) changed IP lease assignment.",
                serviceContext: nil,
                significance: "IP drift occurs when DHCP leases expire without static IP reservation. This can break hardcoded IP SSH connections or local DNS records.",
                triageSteps: [
                    "Set a static DHCP reservation in your network router settings",
                    "Update local ~/.ssh/config Host entry if using hardcoded IP bindings"
                ]
            )
            
        default:
            return ExplainerInfo(
                title: "Network Drift Alert",
                severity: .low,
                iconName: "bell.fill",
                iconColor: .gray,
                summary: event.detail,
                serviceContext: nil,
                significance: "Structural change observed on host \(event.hostname.isEmpty ? event.hostIp : event.hostname).",
                triageSteps: [
                    "Review recent host administrative changes",
                    "Trigger Runbook Triage"
                ]
            )
        }
    }
    
    private static func serviceName(for port: Int) -> String {
        switch port {
        case 22: return "SSH Secure Shell"
        case 23: return "Telnet (Unencrypted)"
        case 53: return "DNS Name Resolution (Pi-hole / Unbound)"
        case 80: return "HTTP Web Server"
        case 443: return "HTTPS Encrypted Web Server"
        case 5000: return "Synology DSM UI / AirPlay / Flask Alt"
        case 5432: return "PostgreSQL Database"
        case 8080: return "HTTP Alternate / Tomcat / Proxy"
        case 8123: return "Home Assistant Web UI"
        case 27017: return "MongoDB Database"
        case 3389: return "RDP Remote Desktop"
        default: return "Service Port \(port)"
        }
    }
}

public struct AlertExplainerPopoverView: View {
    let event: DriftEvent
    @ObservedObject var store: DrifterStore
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        let info = AlertExplainerAnalyzer.analyze(event: event)
        
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: info.iconName)
                    .font(.title2)
                    .foregroundStyle(info.iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(event.timestamp.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Text(info.severity.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(info.severity.color.opacity(0.18))
                    .foregroundStyle(info.severity.color)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("SUMMARY")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text(info.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let ctx = info.serviceContext {
                    Text(ctx)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Significance
            VStack(alignment: .leading, spacing: 4) {
                Text("WHAT THIS MEANS & SIGNIFICANCE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text(info.significance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Suggested Triage Steps
            VStack(alignment: .leading, spacing: 6) {
                Text("SUGGESTED TRIAGE STEPS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                ForEach(Array(info.triageSteps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack {
                Button {
                    TerminalLauncher.launchSSH(ip: event.hostIp, hostname: event.hostname, store: store)
                    dismiss()
                } label: {
                    Label("SSH Host", systemImage: "terminal.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
                
                if store.settings.enableRunbookIntegration {
                    Button {
                        if let host = store.hosts.first(where: { $0.id == event.hostId || $0.ip == event.hostIp }) {
                            RunbookLauncher.launchRunbook(host: host, event: event, store: store)
                        } else {
                            let tempHost = HostItem(ip: event.hostIp, hostname: event.hostname)
                            RunbookLauncher.launchRunbook(host: tempHost, event: event, store: store)
                        }
                        dismiss()
                    } label: {
                        Label("Runbook Triage", systemImage: "book.closed.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .focusable(false)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .focusable(false)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
