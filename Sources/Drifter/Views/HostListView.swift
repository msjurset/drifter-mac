import SwiftUI

struct HostListView: View {
    @ObservedObject var store: DrifterStore
    var activeTab: SidebarTab
    @Binding var selectedHostId: String?
    @Binding var filterText: String

    var filteredHosts: [HostItem] {
        var baseHosts = store.hosts
        switch activeTab {
        case .servers:
            baseHosts = baseHosts.filter { $0.category == "server" }
        case .iotDevices:
            baseHosts = baseHosts.filter { $0.category == "iot" }
        default:
            break
        }

        if filterText.isEmpty {
            return baseHosts
        }
        let query = filterText.lowercased()

        if query.hasPrefix("ip:") {
            let val = String(query.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return baseHosts.filter { $0.ip.contains(val) }
        }
        if query.hasPrefix("status:") {
            let val = String(query.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            return baseHosts.filter { $0.status.lowercased() == val }
        }
        if query.hasPrefix("port:") {
            let val = Int(String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)) ?? 0
            return baseHosts.filter { $0.openPorts.contains(val) }
        }

        return baseHosts.filter {
            $0.hostname.lowercased().contains(query) ||
            $0.ip.contains(query) ||
            $0.mac.lowercased().contains(query) ||
            $0.vendor.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                FilterField(
                    placeholder: "Filter hosts (e.g. ip:192 status:drift port:22)...",
                    text: $filterText,
                    style: .plain
                )
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(10)

            Divider()

            if filteredHosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No matching hosts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHosts, selection: $selectedHostId) { host in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor(host.status))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(host.hostname.isEmpty ? host.ip : host.hostname)
                                    .font(.body)
                                    .fontWeight(.medium)
                                if host.status == "drift" {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }

                            HStack(spacing: 6) {
                                Text(host.ip)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if !host.openPorts.isEmpty {
                                    Text("• \(host.openPorts.count) ports")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .tag(host.id)
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "online": return .green
        case "drift": return .orange
        default: return .gray
        }
    }
}
