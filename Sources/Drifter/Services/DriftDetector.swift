import Foundation

public final class DriftDetector {
    public static func computeDrift(existingHosts: [HostItem], newHosts: [HostItem]) -> (updatedHosts: [HostItem], events: [DriftEvent]) {
        var updatedHosts = existingHosts
        var events: [DriftEvent] = []

        var existingMap: [String: HostItem] = [:]
        for host in existingHosts {
            let key = !host.mac.isEmpty ? host.mac.lowercased() : host.ip
            existingMap[key] = host
        }

        for newHost in newHosts {
            let key = !newHost.mac.isEmpty ? newHost.mac.lowercased() : newHost.ip
            if let oldHost = existingMap[key] {
                // Check IP change drift
                if oldHost.ip != newHost.ip && !oldHost.mac.isEmpty {
                    events.append(DriftEvent(
                        hostId: oldHost.id,
                        hostIp: newHost.ip,
                        hostname: newHost.hostname,
                        type: "ip_changed",
                        detail: "IP address changed from \(oldHost.ip) to \(newHost.ip)"
                    ))
                }

                // Check port drift
                let oldPorts = Set(oldHost.openPorts)
                let currentPorts = Set(newHost.openPorts)

                let openedPorts = currentPorts.subtracting(oldPorts)
                for port in openedPorts {
                    events.append(DriftEvent(
                        hostId: oldHost.id,
                        hostIp: newHost.ip,
                        hostname: newHost.hostname,
                        type: "port_opened",
                        detail: "Port \(port) was newly opened on \(newHost.hostname.isEmpty ? newHost.ip : newHost.hostname)"
                    ))
                }

                let closedPorts = oldPorts.subtracting(currentPorts)
                for port in closedPorts {
                    events.append(DriftEvent(
                        hostId: oldHost.id,
                        hostIp: newHost.ip,
                        hostname: newHost.hostname,
                        type: "port_closed",
                        detail: "Port \(port) closed on \(newHost.hostname.isEmpty ? newHost.ip : newHost.hostname)"
                    ))
                }

                // Update existing host in list
                if let idx = updatedHosts.firstIndex(where: { $0.id == oldHost.id }) {
                    var merged = oldHost
                    merged.ip = newHost.ip
                    merged.hostname = newHost.hostname.isEmpty ? oldHost.hostname : newHost.hostname
                    merged.openPorts = newHost.openPorts
                    merged.status = !openedPorts.isEmpty ? "drift" : "online"
                    merged.lastSeen = Date()
                    updatedHosts[idx] = merged
                }
            } else {
                // New host discovered
                events.append(DriftEvent(
                    hostId: newHost.id,
                    hostIp: newHost.ip,
                    hostname: newHost.hostname,
                    type: "new_host",
                    detail: "New host discovered at \(newHost.ip) (\(newHost.vendor.isEmpty ? "Unknown" : newHost.vendor))"
                ))
                updatedHosts.append(newHost)
            }
        }

        return (updatedHosts: updatedHosts, events: events)
    }
}
