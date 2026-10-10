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
    @State private var showSavedToast: Bool = false

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
}
