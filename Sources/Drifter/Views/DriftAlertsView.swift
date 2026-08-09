import SwiftUI

struct DriftAlertsView: View {
    @ObservedObject var store: DrifterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drift & Security Alerts")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Historical log of network changes, port drift, and new host discoveries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !store.driftEvents.isEmpty {
                    Button("Clear History") {
                        store.clearDriftEvents()
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }
            }
            .padding()

            Divider()

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
                        DriftAlertRowView(event: event, store: store)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct DriftAlertRowView: View {
    let event: DriftEvent
    @ObservedObject var store: DrifterStore
    @State private var showExplainer = false

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
                        if let host = store.hosts.first(where: { $0.id == event.hostId || $0.ip == event.hostIp }) {
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
                    Button("Ack") {
                        store.acknowledgeEvent(id: event.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .focusable(false)
                }
            }
        }
        .padding(.vertical, 6)
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
