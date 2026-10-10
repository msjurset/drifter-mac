import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: DrifterStore

    @State private var preferredTerminal: TerminalApp = .ghostty
    @State private var defaultSSHUser: String = ""
    @State private var customCommand: String = ""
    @State private var notifyOnDrift: Bool = true
    @State private var enableRunbookIntegration: Bool = true
    @State private var runbookURLTemplate: String = "runbook://execute?template=security-audit&host={ip}"
    @State private var backgroundScanInterval: Int = 0
    @State private var showMenuBarItem: Bool = true
    @State private var showSavedToast: Bool = false

    @State private var aiEnabled: Bool = false
    @State private var aiProvider: AIProvider = .ollama
    @State private var aiApiKey: String = ""
    @State private var aiEndpointURL: String = "http://localhost:11434"
    @State private var aiCustomModelName: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var testConnectionStatus: String? = nil
    @State private var isConnectionSuccess: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drifter Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure your SSH terminal application, Runbook procedure triggers, and drift notifications.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Terminal Application Preferences
                VStack(alignment: .leading, spacing: 16) {
                    Label("Terminal & SSH Dispatch", systemImage: "terminal.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Preferred Terminal:", selection: $preferredTerminal) {
                            ForEach(TerminalApp.allCases) { app in
                                Text(app.rawValue).tag(app)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        if preferredTerminal == .custom {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Custom Terminal Command Template ({ip} or {target}):")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                FilterField(
                                    placeholder: "e.g. ghostty -e ssh {ip}",
                                    text: $customCommand,
                                    style: .rounded
                                )
                                .frame(height: 28)
                            }
                            .padding(.top, 4)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Default SSH Username (Optional):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FilterField(
                                placeholder: "e.g. root, pi, or leave empty",
                                text: $defaultSSHUser,
                                style: .rounded
                            )
                            .frame(height: 28)
                        }

                        HStack {
                            Button("Test Launch Terminal") {
                                saveCurrentSettings()
                                TerminalLauncher.launchSSH(ip: "127.0.0.1", store: store)
                            }
                            .buttonStyle(.bordered)
                            .focusable(false)

                            Spacer()

                            if showSavedToast {
                                Text("Settings Saved")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.opacity)
                            }

                            Button("Save Settings") {
                                saveCurrentSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .focusable(false)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Runbook Integration Preferences
                VStack(alignment: .leading, spacing: 16) {
                    Label("Runbook Procedure Dispatch", systemImage: "book.closed.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Runbook Integration (triggers Runbook.app from Drifter)", isOn: $enableRunbookIntegration)

                        if enableRunbookIntegration {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Runbook Deep Link Template ({ip}, {hostname}, {type}, {detail}):")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                FilterField(
                                    placeholder: "runbook://execute?template=security-audit&host={ip}",
                                    text: $runbookURLTemplate,
                                    style: .rounded
                                )
                                .frame(height: 28)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Security & Drift Alerts
                VStack(alignment: .leading, spacing: 16) {
                    Label("Security & Drift Alerts", systemImage: "shield.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Log and alert when port drift or new hosts are detected", isOn: $notifyOnDrift)
                            .onChange(of: notifyOnDrift) { _, newValue in
                                var updated = store.settings
                                updated.notifyOnDrift = newValue
                                store.updateSettings(updated)
                            }

                        Toggle("Show Menu Bar Watchdog Item (Status & Quick Actions)", isOn: $showMenuBarItem)
                            .onChange(of: showMenuBarItem) { _, newValue in
                                var updated = store.settings
                                updated.showMenuBarItem = newValue
                                store.updateSettings(updated)
                            }

                        Divider()

                        Picker("Background Watchdog Polling:", selection: $backgroundScanInterval) {
                            Text("Manual Only (Disabled)").tag(0)
                            Text("Every 5 minutes").tag(5)
                            Text("Every 15 minutes").tag(15)
                            Text("Every 30 minutes").tag(30)
                            Text("Every 1 hour").tag(60)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: backgroundScanInterval) { _, newValue in
                            var updated = store.settings
                            updated.backgroundScanIntervalMinutes = newValue
                            store.updateSettings(updated)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Authoritative Baseline & Compliance
                VStack(alignment: .leading, spacing: 16) {
                    Label("Authoritative Baseline & Compliance", systemImage: "lock.shield.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        if let lockDate = store.lastBaselineLockDate {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Authoritative baseline locked on \(lockDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("No authoritative baseline established. Operating in rolling drift mode.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button("Lock Current Network as Baseline") {
                                store.lockBaseline()
                            }
                            .buttonStyle(.borderedProminent)
                            .focusable(false)

                            Button("Export Network Audit Report (.md)") {
                                let report = AuditReportGenerator.generateMarkdownReport(
                                    hosts: store.hosts,
                                    events: store.driftEvents,
                                    baselineLockDate: store.lastBaselineLockDate
                                )
                                AuditReportGenerator.exportReportToFile(content: report, defaultName: "drifter_network_audit", fileExtension: "md")
                            }
                            .buttonStyle(.bordered)
                            .focusable(false)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // AI Security Advisor (Optional)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("AI Security Advisor (Optional)", systemImage: "sparkles")
                            .font(.headline)
                        Spacer()
                        if aiEnabled {
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Enable AI Security Advisor", isOn: $aiEnabled)
                            .onChange(of: aiEnabled) { _, _ in
                                saveCurrentSettings()
                            }

                        Text("Synthesizes network drift alerts into high-level security briefs and audits host port profiles on demand. Disabled by default; when off, all AI controls remain completely hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if aiEnabled {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Provider:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Picker("", selection: $aiProvider) {
                                    ForEach(AIProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }
                                .pickerStyle(.radioGroup)
                                .onChange(of: aiProvider) { _, _ in
                                    saveCurrentSettings()
                                }
                            }

                            if aiProvider == .ollama {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ollama Endpoint URL:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    FilterField(
                                        placeholder: "http://localhost:11434",
                                        text: $aiEndpointURL,
                                        style: .rounded
                                    )
                                    .frame(height: 28)

                                    Text("Model Name (Optional Override):")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    FilterField(
                                        placeholder: "Default: llama3.2",
                                        text: $aiCustomModelName,
                                        style: .rounded
                                    )
                                    .frame(height: 28)

                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.shield")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        Text("100% Local & Private. No network payloads or telemetry leave your machine.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(aiProvider.rawValue) API Key:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    FilterField(
                                        placeholder: "Paste your API key here",
                                        text: $aiApiKey,
                                        style: .rounded
                                    )
                                    .frame(height: 28)

                                    Text("Model Name (Optional Override):")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    FilterField(
                                        placeholder: "Default: \(aiProvider.defaultModel)",
                                        text: $aiCustomModelName,
                                        style: .rounded
                                    )
                                    .frame(height: 28)

                                    HStack(spacing: 4) {
                                        Image(systemName: "key.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("Stored locally in macOS app preferences. Sent directly to \(aiProvider.rawValue) with zero telemetry.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                            }

                            HStack(spacing: 12) {
                                Button {
                                    testAIConnection()
                                } label: {
                                    if isTestingConnection {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.trailing, 2)
                                        Text("Testing...")
                                    } else {
                                        Label("Test Connection", systemImage: "network")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .focusable(false)
                                .disabled(isTestingConnection)

                                if let status = testConnectionStatus {
                                    HStack(spacing: 4) {
                                        Image(systemName: isConnectionSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundStyle(isConnectionSuccess ? .green : .red)
                                        Text(status)
                                            .font(.caption)
                                            .foregroundStyle(isConnectionSuccess ? .green : .red)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Button("Save AI Settings") {
                                    saveCurrentSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .focusable(false)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .onAppear {
            preferredTerminal = store.settings.preferredTerminal
            defaultSSHUser = store.settings.defaultSSHUser
            customCommand = store.settings.customTerminalCommand
            notifyOnDrift = store.settings.notifyOnDrift
            enableRunbookIntegration = store.settings.enableRunbookIntegration
            runbookURLTemplate = store.settings.runbookURLTemplate
            backgroundScanInterval = store.settings.backgroundScanIntervalMinutes
            showMenuBarItem = store.settings.showMenuBarItem
            aiEnabled = store.settings.aiSettings.enabled
            aiProvider = store.settings.aiSettings.provider
            aiApiKey = store.settings.aiSettings.apiKey
            aiEndpointURL = store.settings.aiSettings.endpointURL
            aiCustomModelName = store.settings.aiSettings.customModelName
        }
    }

    private func saveCurrentSettings() {
        var updated = store.settings
        updated.preferredTerminal = preferredTerminal
        updated.defaultSSHUser = defaultSSHUser
        updated.customTerminalCommand = customCommand
        updated.notifyOnDrift = notifyOnDrift
        updated.enableRunbookIntegration = enableRunbookIntegration
        updated.runbookURLTemplate = runbookURLTemplate
        updated.backgroundScanIntervalMinutes = backgroundScanInterval
        updated.showMenuBarItem = showMenuBarItem
        updated.aiSettings = AISettings(
            enabled: aiEnabled,
            provider: aiProvider,
            apiKey: aiApiKey,
            endpointURL: aiEndpointURL,
            customModelName: aiCustomModelName
        )
        store.updateSettings(updated)

        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedToast = false
            }
        }
    }

    private func testAIConnection() {
        saveCurrentSettings()
        isTestingConnection = true
        testConnectionStatus = nil
        let currentSettings = AISettings(
            enabled: aiEnabled,
            provider: aiProvider,
            apiKey: aiApiKey,
            endpointURL: aiEndpointURL,
            customModelName: aiCustomModelName
        )
        Task {
            do {
                let msg = try await AIAdvisorService.shared.testConnection(settings: currentSettings)
                await MainActor.run {
                    testConnectionStatus = msg
                    isConnectionSuccess = true
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testConnectionStatus = error.localizedDescription
                    isConnectionSuccess = false
                    isTestingConnection = false
                }
            }
        }
    }
}
