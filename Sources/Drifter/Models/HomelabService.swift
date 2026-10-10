import Foundation

public struct HomelabService: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let port: Int
    public let icon: String
    public let isHttps: Bool
    public let path: String
    public let isWebGUI: Bool

    public init(id: String, name: String, port: Int, icon: String, isHttps: Bool, path: String = "", isWebGUI: Bool = true) {
        self.id = id
        self.name = name
        self.port = port
        self.icon = icon
        self.isHttps = isHttps
        self.path = path
        self.isWebGUI = isWebGUI
    }

    public func url(for ip: String) -> URL? {
        guard isWebGUI else { return nil }
        let scheme = isHttps ? "https" : "http"
        return URL(string: "\(scheme)://\(ip):\(port)\(path)")
    }

    public static func detectServices(openPorts: [Int]) -> [HomelabService] {
        var services: [HomelabService] = []

        for port in openPorts {
            switch port {
            case 8006:
                services.append(HomelabService(id: "proxmox", name: "Proxmox VE", port: 8006, icon: "server.rack", isHttps: true))
            case 9000:
                services.append(HomelabService(id: "portainer_http", name: "Portainer", port: 9000, icon: "shippingbox.fill", isHttps: false))
            case 9443:
                services.append(HomelabService(id: "portainer_https", name: "Portainer", port: 9443, icon: "shippingbox.fill", isHttps: true))
            case 8123:
                services.append(HomelabService(id: "homeassistant", name: "Home Assistant", port: 8123, icon: "house.fill", isHttps: false))
            case 32400:
                services.append(HomelabService(id: "plex", name: "Plex Media Server", port: 32400, icon: "play.tv.fill", isHttps: false, path: "/web"))
            case 8096:
                services.append(HomelabService(id: "jellyfin", name: "Jellyfin", port: 8096, icon: "play.rectangle.fill", isHttps: false))
            case 3000:
                services.append(HomelabService(id: "grafana", name: "Grafana", port: 3000, icon: "chart.line.uptrend.xyaxis", isHttps: false))
            case 9090:
                services.append(HomelabService(id: "cockpit", name: "Cockpit", port: 9090, icon: "gauge.with.needle", isHttps: true))
            case 5000:
                services.append(HomelabService(id: "synology_http", name: "Synology DSM", port: 5000, icon: "externaldrive.fill", isHttps: false))
            case 5001:
                services.append(HomelabService(id: "synology_https", name: "Synology DSM", port: 5001, icon: "externaldrive.badge.checkmark", isHttps: true))
            case 8443:
                services.append(HomelabService(id: "unifi", name: "UniFi Console", port: 8443, icon: "wifi.router.fill", isHttps: true))
            case 1883:
                services.append(HomelabService(id: "mqtt", name: "MQTT Broker", port: 1883, icon: "point.3.filled.connected.trianglepath.dotted", isHttps: false, isWebGUI: false))
            case 53:
                services.append(HomelabService(id: "dns", name: "DNS Resolver", port: 53, icon: "arrow.triangle.branch", isHttps: false, isWebGUI: false))
            default:
                break
            }
        }

        return services
    }
}
