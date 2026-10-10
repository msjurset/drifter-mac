import SwiftUI

private struct PortExplainerItem: Identifiable {
    let port: Int
    var id: Int { port }
}

struct HostDetailView: View {
    let host: HostItem
    @ObservedObject var store: DrifterStore
    @State private var selectedPortForExplainer: Int?
    @State private var headerWidth: CGFloat = 0

    private var actionItems: [ActionPillItem] {
        var list: [ActionPillItem] = [
            ActionPillItem(
                id: "ssh",
                title: "SSH",
                icon: "terminal.fill",
                help: "Launch interactive SSH terminal session to \(host.ip) in Ghostty",
                isProminent: false,
                action: {
                    TerminalLauncher.launchSSH(ip: host.ip, hostname: host.hostname, store: store)
                }
            )
        ]

        if host.openPorts.contains(80) || host.openPorts.contains(443) || host.openPorts.contains(8123) || host.openPorts.contains(8080) {
            let scheme = host.openPorts.contains(443) ? "https" : "http"
            let portStr = host.openPorts.contains(8123) ? ":8123" : (host.openPorts.contains(8080) ? ":8080" : "")
            list.append(
                ActionPillItem(
                    id: "web",
                    title: "Open Web",
                    icon: "safari.fill",
                    help: "Open web interface (\(scheme)://\(host.ip)\(portStr)) in default browser",
                    action: {
                        if let url = URL(string: "\(scheme)://\(host.ip)\(portStr)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            )
        }

        if store.settings.enableRunbookIntegration {
            list.append(
                ActionPillItem(
                    id: "runbook",
                    title: "Runbook",
                    icon: "book.closed.fill",
                    help: "Open operational runbook for \(host.hostname.isEmpty ? host.ip : host.hostname) in Runbook.app",
                    action: {
                        RunbookLauncher.launchRunbook(host: host, store: store)
                    }
                )
            )
        }

        list.append(
            ActionPillItem(
                id: "forget",
                title: "Forget",
                icon: "trash",
                help: "Remove host profile and port tracking records from Drifter watchdog",
                isDestructive: true,
                action: {
                    store.removeHost(id: host.id)
                }
            )
        )

        return list
    }

    private var isHeaderConstrained: Bool {
        headerWidth > 0 && headerWidth < 560
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(statusColor(host.status).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: categoryIcon(host.category))
                            .font(.system(size: 26))
                            .foregroundStyle(statusColor(host.status))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(host.hostname.isEmpty ? host.ip : host.hostname)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            StatusBadge(status: host.status)
                        }

                        Text(host.ip)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if !host.vendor.isEmpty {
                            Text(host.vendor)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    CollapsibleActionRow(items: actionItems, isConstrained: isHeaderConstrained)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { headerWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, newWidth in headerWidth = newWidth }
                    }
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Device Profile")
                        .font(.headline)

                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Text("MAC Address:")
                                .foregroundStyle(.secondary)
                            Text(host.mac.isEmpty ? "Unknown" : host.mac)
                                .font(.system(.body, design: .monospaced))
                        }
                        GridRow {
                            Text("Category:")
                                .foregroundStyle(.secondary)
                            Text(host.category.capitalized)
                        }
                        GridRow {
                            Text("Last Seen:")
                                .foregroundStyle(.secondary)
                            Text(host.lastSeen.formatted(date: .numeric, time: .standard))
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Open Ports")
                        .font(.headline)

                    if host.openPorts.isEmpty {
                        Text("No open TCP ports detected.")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                            ForEach(host.openPorts, id: \.self) { port in
                                Button {
                                    selectedPortForExplainer = port
                                } label: {
                                    HStack {
                                        Image(systemName: "network")
                                            .foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Port \(port)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(portLabel(port))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.windowBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Discovered Services (mDNS)")
                        .font(.headline)

                    if host.mdnsServices.isEmpty {
                        Text("No mDNS broadcast services registered.")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(host.mdnsServices, id: \.self) { service in
                                HStack {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                        .foregroundStyle(.indigo)
                                    Text(service)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
        .popover(item: Binding(
            get: { selectedPortForExplainer.map { PortExplainerItem(port: $0) } },
            set: { selectedPortForExplainer = $0?.port }
        )) { item in
            let tempEvent = DriftEvent(
                hostId: host.id,
                hostIp: host.ip,
                hostname: host.hostname,
                type: "port_opened",
                detail: "Port \(item.port) open on \(host.hostname.isEmpty ? host.ip : host.hostname)"
            )
            AlertExplainerPopoverView(event: tempEvent, store: store)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "online": return .green
        case "drift": return .orange
        default: return .gray
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "server": return "server.rack"
        case "iot": return "cpu"
        case "network": return "network"
        case "workstation": return "desktopcomputer"
        default: return "laptopcomputer"
        }
    }

    private func portLabel(_ port: Int) -> String {
        switch port {
        case 22: return "SSH"
        case 53: return "DNS"
        case 80: return "HTTP Web"
        case 443: return "HTTPS"
        case 8123: return "Home Assistant"
        case 8080: return "Web Alt"
        case 5000: return "Synology UI"
        case 445: return "SMB Share"
        default: return "Service Port"
        }
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case "online": return .green
        case "drift": return .orange
        default: return .gray
        }
    }
}
