import SwiftUI
import AppKit

struct DriftAlertsView: View {
    @ObservedObject var store: DrifterStore
    @State private var isAnalyzingDrift: Bool = false
    @State private var isDeepInvestigationRunning: Bool = false
    @State private var aiBrief: AIAnalysisResult? = nil
    @State private var aiError: String? = nil
    @State private var briefTitle: String = "Drift Incident Triage"
    @State private var targetInvestigatedEvent: DriftEvent? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Drift & Security Alerts")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let lockDate = store.lastBaselineLockDate {
                            Text("Baseline: Locked")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                                .help("Authoritative baseline locked at \(lockDate.formatted(date: .abbreviated, time: .shortened))")
                        } else {
                            Text("Baseline: Rolling")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                                .help("No authoritative baseline locked. Operating in rolling audit mode.")
                        }
                    }

                    Text("Historical log of network changes, port drift, and new host discoveries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if store.settings.aiSettings.enabled {
                        Menu {
                            Button {
                                performAITriage(deepOverride: false)
                            } label: {
                                Label("Fast Triage (~1s)", systemImage: "bolt.fill")
                            }

                            Button {
                                performAITriage(deepOverride: true)
                            } label: {
                                Label("Deep Security Investigation", systemImage: "brain.head.profile")
                            }
                        } label: {
                            if isAnalyzingDrift {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 2)
                                Text(isDeepInvestigationRunning ? "Investigating..." : "Triaging...")
                            } else {
                                Label(store.settings.aiSettings.deepReasoning ? "AI Deep Triage" : "AI Triage",
                                      systemImage: store.settings.aiSettings.deepReasoning ? "brain.head.profile" : "sparkles")
                            }
                        } primaryAction: {
                            performAITriage()
                        }
                        .buttonStyle(.bordered)
                        .menuStyle(.borderedButton)
                        .help(store.settings.aiSettings.deepReasoning ? "Synthesize active drift events with Deep Security Reasoning (click arrow for options)" : "Synthesize active drift events with AI security triage (click arrow for options)")
                        .focusable(false)
                        .disabled(isAnalyzingDrift || store.driftEvents.isEmpty)
                    }

                    Menu {
                        Button {
                            store.blessAllIntoBaseline()
                        } label: {
                            Label("Bless All & Lock Baseline", systemImage: "checkmark.shield.fill")
                        }

                        Button {
                            store.lockBaseline(acknowledgeActiveAlerts: false)
                        } label: {
                            Label("Lock Baseline Only", systemImage: "lock.shield")
                        }

                        if store.driftEvents.contains(where: { !$0.acknowledged }) {
                            Divider()

                            Button {
                                store.acknowledgeAllAlerts()
                            } label: {
                                Label("Acknowledge All Alerts", systemImage: "bell.slash")
                            }
                        }

                        Divider()

                        Button {
                            store.autoCategorizeHosts()
                        } label: {
                            Label("Re-scan Device Categories", systemImage: "sparkle.magnifyingglass")
                        }
                    } label: {
                        Label(store.lastBaselineLockDate == nil ? "Bless Baseline" : "Lock Baseline",
                              systemImage: store.lastBaselineLockDate == nil ? "checkmark.shield.fill" : "lock.shield.fill")
                    } primaryAction: {
                        if store.lastBaselineLockDate == nil {
                            store.blessAllIntoBaseline()
                        } else {
                            store.lockBaseline(acknowledgeActiveAlerts: false)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(store.lastBaselineLockDate == nil ? .green : nil)
                    .menuStyle(.borderedButton)
                    .help(store.lastBaselineLockDate == nil
                          ? "Bless all current hosts and ports into authoritative baseline and acknowledge discovery alerts"
                          : "Snapshot current network state as the authoritative baseline")
                    .focusable(false)

                    Menu {
                        Button("Export Markdown (.md)...") {
                            let report = AuditReportGenerator.generateMarkdownReport(
                                hosts: store.hosts,
                                events: store.driftEvents,
                                baselineLockDate: store.lastBaselineLockDate
                            )
                            AuditReportGenerator.exportReportToFile(content: report, defaultName: "drifter_network_audit", fileExtension: "md")
                        }

                        Button("Export JSON (.json)...") {
                            let report = AuditReportGenerator.generateJSONReport(
                                hosts: store.hosts,
                                events: store.driftEvents,
                                baselineLockDate: store.lastBaselineLockDate
                            )
                            AuditReportGenerator.exportReportToFile(content: report, defaultName: "drifter_network_audit", fileExtension: "json")
                        }

                        Divider()

                        Button("Copy Markdown to Clipboard") {
                            let report = AuditReportGenerator.generateMarkdownReport(
                                hosts: store.hosts,
                                events: store.driftEvents,
                                baselineLockDate: store.lastBaselineLockDate
                            )
                            AuditReportGenerator.copyReportToClipboard(content: report)
                        }
                    } label: {
                        Label("Export Audit", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    if !store.driftEvents.isEmpty {
                        Button("Clear History") {
                            store.clearDriftEvents()
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                }
            }
            .padding()

            Divider()

            if store.lastBaselineLockDate == nil && !store.driftEvents.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Operating in rolling discovery mode. Click **Bless All** to snapshot your network as the authoritative baseline and resolve initial alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Bless All (\(store.driftEvents.filter { !$0.acknowledged }.count))") {
                        store.blessAllIntoBaseline()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    .focusable(false)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.08))
            }

            if let brief = aiBrief {
                AISecurityBriefCard(
                    brief: brief,
                    title: briefTitle,
                    onDeepInvestigate: {
                        if let target = targetInvestigatedEvent {
                            performItemInvestigation(event: target, deep: true)
                        } else {
                            performAITriage(deepOverride: true)
                        }
                    }
                ) {
                    withAnimation {
                        aiBrief = nil
                        targetInvestigatedEvent = nil
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            } else if let errorMsg = aiError {
                AIAdvisorErrorCard(errorMessage: errorMsg) {
                    withAnimation {
                        aiError = nil
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }

            if store.driftEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("Network State Clean")
                        .font(.headline)
                    Text("No port drift or unauthorized host changes detected.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.driftEvents) { event in
                        DriftAlertRowView(
                            event: event,
                            store: store,
                            isAnalyzing: isAnalyzingDrift,
                            onInvestigate: { ev, deep in
                                performItemInvestigation(event: ev, deep: deep)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func performAITriage(deepOverride: Bool? = nil) {
        guard !isAnalyzingDrift else { return }
        let isDeep = deepOverride ?? store.settings.aiSettings.deepReasoning
        isAnalyzingDrift = true
        isDeepInvestigationRunning = isDeep
        aiError = nil
        targetInvestigatedEvent = nil
        briefTitle = isDeep ? "Deep Security Investigation" : "Drift Incident Triage"
        Task {
            do {
                let result = try await AIAdvisorService.shared.triageDriftAlerts(
                    events: store.driftEvents,
                    hosts: store.hosts,
                    settings: store.settings.aiSettings,
                    forceDeepReasoning: deepOverride
                )
                await MainActor.run {
                    withAnimation {
                        aiBrief = result
                        isAnalyzingDrift = false
                        isDeepInvestigationRunning = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        aiError = error.localizedDescription
                        isAnalyzingDrift = false
                        isDeepInvestigationRunning = false
                    }
                }
            }
        }
    }

    private func performItemInvestigation(event: DriftEvent, deep: Bool) {
        guard !isAnalyzingDrift else { return }
        let hostName = event.hostname.isEmpty ? event.hostIp : event.hostname
        isAnalyzingDrift = true
        isDeepInvestigationRunning = deep
        aiError = nil
        targetInvestigatedEvent = event
        briefTitle = deep ? "Deep Investigation: \(hostName)" : "Security Triage: \(hostName)"

        let matchedHost = store.hosts.first(where: { $0.id == event.hostId || $0.ip == event.hostIp })
            ?? HostItem(ip: event.hostIp, hostname: event.hostname)

        Task {
            do {
                let result = try await AIAdvisorService.shared.analyzeHostSecurity(
                    host: matchedHost,
                    events: [event],
                    settings: store.settings.aiSettings,
                    forceDeepReasoning: deep
                )
                await MainActor.run {
                    withAnimation {
                        aiBrief = result
                        isAnalyzingDrift = false
                        isDeepInvestigationRunning = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        aiError = error.localizedDescription
                        isAnalyzingDrift = false
                        isDeepInvestigationRunning = false
                    }
                }
            }
        }
    }
}

private struct DriftAlertRowView: View {
    let event: DriftEvent
    @ObservedObject var store: DrifterStore
    var isAnalyzing: Bool = false
    var onInvestigate: ((DriftEvent, Bool) -> Void)? = nil
    @State private var showExplainer = false

    private var matchedHost: HostItem? {
        store.hosts.first(where: { $0.id == event.hostId || $0.ip == event.hostIp })
    }

    private var webURL: URL? {
        let ports = matchedHost?.openPorts ?? []
        if ports.contains(443) {
            return URL(string: "https://\(event.hostIp)")
        } else if ports.contains(80) {
            return URL(string: "http://\(event.hostIp)")
        } else if ports.contains(8123) {
            return URL(string: "http://\(event.hostIp):8123")
        } else if ports.contains(8080) {
            return URL(string: "http://\(event.hostIp):8080")
        } else if event.detail.contains("443") {
            return URL(string: "https://\(event.hostIp)")
        } else if event.detail.contains("8123") {
            return URL(string: "http://\(event.hostIp):8123")
        } else if event.detail.contains("8080") {
            return URL(string: "http://\(event.hostIp):8080")
        } else if event.detail.contains("80") {
            return URL(string: "http://\(event.hostIp)")
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                showExplainer.toggle()
            } label: {
                Image(systemName: iconForType(event.type))
                    .font(.title3)
                    .foregroundStyle(colorForType(event.type))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .popover(isPresented: $showExplainer, arrowEdge: .trailing) {
                AlertExplainerPopoverView(event: event, store: store)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.hostname.isEmpty ? event.hostIp : event.hostname)
                        .font(.headline)

                    Button {
                        showExplainer.toggle()
                    } label: {
                        Text(event.type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForType(event.type).opacity(0.15))
                            .foregroundStyle(colorForType(event.type))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    Spacer()

                    Text(event.timestamp.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(event.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if store.settings.enableRunbookIntegration {
                    Button("Runbook") {
                        if let host = matchedHost {
                            RunbookLauncher.launchRunbook(host: host, event: event, store: store)
                        } else {
                            let tempHost = HostItem(ip: event.hostIp, hostname: event.hostname)
                            RunbookLauncher.launchRunbook(host: tempHost, event: event, store: store)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                }

                if !event.acknowledged {
                    Button("Approve") {
                        store.approveDrift(for: event)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                    .help("Approve this change and update authoritative baseline")
                    .focusable(false)

                    Button("Ack") {
                        store.acknowledgeEvent(id: event.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Acknowledge alert without modifying baseline")
                    .focusable(false)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if store.settings.aiSettings.enabled {
                Section {
                    Button {
                        onInvestigate?(event, true)
                    } label: {
                        Label("Deep Security Investigation", systemImage: "brain.head.profile")
                    }
                    .disabled(isAnalyzing)

                    Button {
                        onInvestigate?(event, false)
                    } label: {
                        Label("Quick Triage", systemImage: "bolt.fill")
                    }
                    .disabled(isAnalyzing)
                }
            }

            Section {
                if let host = matchedHost {
                    Button {
                        store.selectedHostId = host.id
                        store.activeTab = .allHosts
                    } label: {
                        Label("View Host in Inventory", systemImage: "display")
                    }
                }

                if let url = webURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open Web Interface", systemImage: "safari")
                    }
                }

                Button {
                    TerminalLauncher.launchSSH(ip: event.hostIp, hostname: event.hostname, store: store)
                } label: {
                    Label("Launch SSH Session", systemImage: "terminal")
                }

                if store.settings.enableRunbookIntegration {
                    Button {
                        if let host = matchedHost {
                            RunbookLauncher.launchRunbook(host: host, event: event, store: store)
                        } else {
                            let tempHost = HostItem(ip: event.hostIp, hostname: event.hostname)
                            RunbookLauncher.launchRunbook(host: tempHost, event: event, store: store)
                        }
                    } label: {
                        Label("Runbook Triage", systemImage: "book.closed")
                    }
                }
            }

            Section {
                if !event.acknowledged {
                    Button {
                        store.approveDrift(for: event)
                    } label: {
                        Label("Approve into Baseline", systemImage: "checkmark.shield")
                    }

                    Button {
                        store.acknowledgeEvent(id: event.id)
                    } label: {
                        Label("Acknowledge Alert", systemImage: "bell.slash")
                    }
                }

                Button(role: .destructive) {
                    store.removeDriftEvent(id: event.id)
                } label: {
                    Label("Dismiss Alert", systemImage: "trash")
                }
            }

            Section {
                Button {
                    copyToPasteboard(event.hostIp)
                } label: {
                    Label("Copy IP Address", systemImage: "doc.on.doc")
                }

                if !event.hostname.isEmpty {
                    Button {
                        copyToPasteboard(event.hostname)
                    } label: {
                        Label("Copy Hostname", systemImage: "doc.on.doc")
                    }
                }

                Button {
                    let formatted = "[\(event.timestamp.formatted(date: .abbreviated, time: .standard))] \(event.type.replacingOccurrences(of: "_", with: " ").capitalized) - \(event.hostname.isEmpty ? event.hostIp : event.hostname) (\(event.hostIp)): \(event.detail)"
                    copyToPasteboard(formatted)
                } label: {
                    Label("Copy Alert Details", systemImage: "doc.on.doc.fill")
                }
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "port_opened": return "exclamationmark.triangle.fill"
        case "port_closed": return "lock.fill"
        case "new_host": return "plus.circle.fill"
        case "ip_changed": return "arrow.triangle.2.circlepath"
        default: return "bell.fill"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "port_opened": return .orange
        case "port_closed": return .blue
        case "new_host": return .green
        case "ip_changed": return .purple
        default: return .gray
        }
    }
}
