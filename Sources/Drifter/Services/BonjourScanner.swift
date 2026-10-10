import Foundation
import Network

public struct BonjourDiscoveredService: Sendable, Hashable {
    public let serviceName: String
    public let serviceType: String
    public let domain: String
    public let resolvedIp: String?

    public init(serviceName: String, serviceType: String, domain: String = "local.", resolvedIp: String? = nil) {
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.domain = domain
        self.resolvedIp = resolvedIp
    }
}

@MainActor
public final class BonjourScanner: ObservableObject, @unchecked Sendable {
    public static let shared = BonjourScanner()

    @Published public private(set) var discoveredServices: [BonjourDiscoveredService] = []
    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.drifter.bonjour", qos: .utility)

    public static let supportedServiceTypes = [
        "_home-assistant._tcp",
        "_esphomelib._tcp",
        "_matter._tcp",
        "_matterc._tcp",
        "_smb._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_printer._tcp",
        "_ipp._tcp",
        "_ssh._tcp",
        "_http._tcp",
        "_https._tcp"
    ]

    public func startBrowsing() {
        stopBrowsing()

        for serviceType in Self.supportedServiceTypes {
            let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
            let parameters = NWParameters()
            let browser = NWBrowser(for: descriptor, using: parameters)

            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor [weak self] in
                    self?.handleBrowseResults(results, forType: serviceType)
                }
            }

            browser.start(queue: queue)
            browsers.append(browser)
        }
    }

    public func stopBrowsing() {
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, forType type: String) {
        for result in results {
            if case .service(let name, let serviceType, let domain, _) = result.endpoint {
                let resolvedIp = resolveServiceIP(name: name)
                let item = BonjourDiscoveredService(
                    serviceName: name,
                    serviceType: serviceType,
                    domain: domain,
                    resolvedIp: resolvedIp
                )
                if !discoveredServices.contains(where: { $0.serviceName == item.serviceName && $0.serviceType == item.serviceType }) {
                    discoveredServices.append(item)
                }
            }
        }
    }

    private func resolveServiceIP(name: String) -> String? {
        let candidateHostname = "\(name).local"
        var hints = addrinfo()
        hints.ai_family = AF_INET
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(candidateHostname, nil, &hints, &res) == 0, let info = res else { return nil }
        defer { freeaddrinfo(res) }

        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let sockaddrIn = info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var addr = sockaddrIn.sin_addr
        if inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN)) != nil {
            let len = ipBuffer.firstIndex(of: 0) ?? ipBuffer.count
            return String(decoding: ipBuffer[..<len].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return nil
    }

    /// Finds matching Bonjour service tags for a given host
    public func services(forHost hostname: String, ip: String) -> [String] {
        var matches: Set<String> = []
        let cleanHost = hostname.lowercased()
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".lan", with: "")

        for service in discoveredServices {
            if let serviceIp = service.resolvedIp, serviceIp == ip {
                matches.insert(service.serviceType)
                continue
            }

            let cleanService = service.serviceName.lowercased()
            if cleanHost == cleanService ||
               cleanHost.contains(cleanService) ||
               cleanService.contains(cleanHost) {
                matches.insert(service.serviceType)
            }
        }

        return Array(matches).sorted()
    }
}
