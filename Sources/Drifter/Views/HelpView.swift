import SwiftUI

public struct HelpSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let category: String
    public let summary: String
    public let blocks: [HelpBlock]
}

public enum HelpBlock: Sendable {
    case paragraph(String)
    case bullets([String])
    case code(String)
    case callout(title: String, text: String, icon: String)
}

public struct HelpView: View {
    @State private var searchQuery: String = ""
    @State private var selectedSectionID: String = "overview"

    public init() {}

    private var filteredSections: [HelpSection] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return Self.sections }
        return Self.sections.filter { section in
            if section.title.lowercased().contains(trimmed) || section.summary.lowercased().contains(trimmed) {
                return true
            }
            for block in section.blocks {
                switch block {
                case .paragraph(let text):
                    if text.lowercased().contains(trimmed) { return true }
                case .bullets(let items):
                    if items.contains(where: { $0.lowercased().contains(trimmed) }) { return true }
                case .code(let snippet):
                    if snippet.lowercased().contains(trimmed) { return true }
                case .callout(let title, let text, _):
                    if title.lowercased().contains(trimmed) || text.lowercased().contains(trimmed) { return true }
                }
            }
            return false
        }
    }

    private var activeSection: HelpSection {
        filteredSections.first(where: { $0.id == selectedSectionID })
            ?? filteredSections.first
            ?? Self.sections[0]
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    FilterField(
                        placeholder: "Search User Guide & Cookbook...",
                        text: $searchQuery,
                        style: .plain
                    )
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(10)

                Divider()

                List(selection: $selectedSectionID) {
                    ForEach(["User Guide", "Cookbook Recipes"], id: \.self) { category in
                        let items = filteredSections.filter { $0.category == category }
                        if !items.isEmpty {
                            Section(category) {
                                ForEach(items) { section in
                                    Label(section.title, systemImage: section.icon)
                                        .tag(section.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            .frame(width: 250)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: activeSection.icon)
                            .font(.title)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeSection.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(activeSection.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    ForEach(Array(activeSection.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .paragraph(let text):
                            Text(text)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        case .bullets(let items):
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .fontWeight(.bold)
                                            .foregroundStyle(.blue)
                                        Text(item)
                                            .font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.leading, 4)
                        case .code(let snippet):
                            Text(snippet)
                                .font(.system(.callout, design: .monospaced))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .callout(let title, let text, let icon):
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: icon)
                                    .foregroundStyle(.blue)
                                    .font(.headline)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(text)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    public static let sections: [HelpSection] = [
        HelpSection(
            id: "overview",
            title: "Overview & Architecture",
            icon: "waveform.path.ecg",
            category: "User Guide",
            summary: "Zero-trust local subnet inventory, port drift detection, and homelab service discovery.",
            blocks: [
                .paragraph("Drifter continuously monitors your active IPv4 subnet to maintain an authoritative inventory of hosts, hardware vendors, open TCP services, and mDNS/Bonjour broadcasts—100% locally with zero cloud dependencies."),
                .bullets([
                    "Concurrent UDP ARP cache warming followed by kernel ARP table inspection (/usr/sbin/arp -a).",
                    "High-speed TCP port probing across common infrastructure ports (22, 53, 80, 443, 8080, 8123, 5000) and on-demand 23-port Deep Scans.",
                    "Native Bonjour (NWBrowser) service discovery for Home Assistant, ESPHome, Matter, SMB, AirPlay, and network printers.",
                    "Authoritative baseline locking with instant Drift Alerts for rogue hosts, newly opened ports, and IP lease changes."
                ]),
                .callout(
                    title: "100% Offline by Default",
                    text: "All host profiles and drift logs live in ~/Library/Application Support/DrifterMac/drifter_store.json. No network data leaves your Mac.",
                    icon: "lock.shield.fill"
                )
            ]
        ),
        HelpSection(
            id: "baselining",
            title: "Authoritative Baselining",
            icon: "checkmark.shield.fill",
            category: "User Guide",
            summary: "Lock known-good network states and incrementally approve legitimate infrastructure changes.",
            blocks: [
                .paragraph("Drifter operates in either Rolling Discovery mode or Locked Authoritative Baseline mode:"),
                .bullets([
                    "Bless All & Lock Baseline: Snapshots every active host and its current open ports into the gold-master baseline while resolving initial discovery alerts in one click.",
                    "Incremental Approve: When you intentionally deploy a new container or open a port, click Approve on the Drift Alert to merge that specific port or host into your baseline.",
                    "Rogue Host Flagging: Any unknown MAC/IP joining after a baseline lock is immediately marked Unapproved / Rogue and surfaces a high-visibility Drift Alert."
                ])
            ]
        ),
        HelpSection(
            id: "filtering",
            title: "Tokenized Host Filtering",
            icon: "line.3.horizontal.decrease.circle",
            category: "User Guide",
            summary: "Slice large subnets rapidly using typed filter tokens and device categories.",
            blocks: [
                .paragraph("Use the search bar above the host list to combine prefix tokens or free-text queries:"),
                .code("""
                ip:10.0.20.        # Filter hosts on subnet 10.0.20.0/24
                status:drift       # Show only hosts with active port or host drift
                port:22            # Show hosts with SSH open
                synology           # Match hostname, vendor, or MAC substring
                """)
            ]
        ),
        HelpSection(
            id: "ssh-runbook",
            title: "SSH, 1Password & Runbook",
            icon: "terminal.fill",
            category: "User Guide",
            summary: "One-click terminal dispatch with ~/.ssh/config resolution, Touch ID, and Runbook deep links.",
            blocks: [
                .bullets([
                    "SSH Terminal Dispatch: Launches Ghostty, Apple Terminal, iTerm2, or a custom command template.",
                    "Automatic ~/.ssh/config Resolution: Maps discovered IP addresses back to your configured Host aliases so OpenSSH applies User, Port, and IdentityAgent rules.",
                    "1Password Touch ID: Automatically exports SSH_AUTH_SOCK to the 1Password SSH agent socket.",
                    "Runbook Automation: Dispatches runbook://execute?template=security-audit&host={ip} to trigger automated triage playbooks."
                ])
            ]
        ),
        HelpSection(
            id: "ai-advisor",
            title: "Optional AI Security Advisor",
            icon: "sparkles",
            category: "User Guide",
            summary: "Local Ollama or BYOK cloud threat triage with 1Password op:// secret references.",
            blocks: [
                .paragraph("When enabled in Settings, the AI Security Advisor synthesizes active drift alerts or individual host port profiles into structured security briefs with copyable terminal verification commands."),
                .bullets([
                    "Ollama (Local): Runs 100% offline against http://localhost:11434 (default model: llama3.2).",
                    "Cloud BYOK: Supports Google Gemini, Anthropic Claude, and OpenAI with op://vault/item/credential secret resolution.",
                    "Fast Triage vs. Deep Security Reasoning: Start with a sub-second summary or escalate to multi-step lateral-movement threat modeling."
                ])
            ]
        ),
        HelpSection(
            id: "recipe-baseline",
            title: "Recipe 1: Zero-Trust Homelab Baseline",
            icon: "lock.desktopcomputer",
            category: "Cookbook Recipes",
            summary: "Establish an authoritative gold-master baseline and catch rogue IoT or container ports.",
            blocks: [
                .bullets([
                    "1. Click Scan Local Network in the bottom-left sidebar to sweep your active subnet.",
                    "2. Select key hypervisors and NAS nodes and click Deep Scan to capture all 23 homelab service ports.",
                    "3. Open Drift Alerts and click Bless All to lock your gold-master baseline.",
                    "4. Enable Background Watchdog Polling (Every 15 minutes) in Settings so unauthorized devices or newly exposed ports trigger immediate desktop notifications."
                ])
            ]
        ),
        HelpSection(
            id: "recipe-incident",
            title: "Recipe 2: Triaging an Unexpected Open Port",
            icon: "exclamationmark.triangle.fill",
            category: "Cookbook Recipes",
            summary: "Investigate a Port Opened alert using the Explainer Popover, AI Triage, and Runbook.",
            blocks: [
                .bullets([
                    "1. Open Drift Alerts and click the orange Port Opened badge to view the Port Security Explainer.",
                    "2. Right-click the alert row and select Deep Security Investigation (or click Runbook to execute security-audit.yaml).",
                    "3. If the port belongs to a legitimate new service, click Approve to merge it into the host's baseline; otherwise SSH into the host and close the service."
                ])
            ]
        ),
        HelpSection(
            id: "recipe-audit-export",
            title: "Recipe 3: Exporting Compliance Audit Reports",
            icon: "doc.text.magnifyingglass",
            category: "Cookbook Recipes",
            summary: "Generate Markdown or JSON network posture snapshots for GitOps or change logs.",
            blocks: [
                .bullets([
                    "1. Navigate to Drift Alerts and click Export Audit in the top-right toolbar.",
                    "2. Choose Export Markdown (.md) for human-readable documentation or Export JSON (.json) for automated diffing in Git.",
                    "3. Review the Executive Summary metrics (Compliance %, Rogue Hosts, Open Port Divergence)."
                ])
            ]
        )
    ]
}
