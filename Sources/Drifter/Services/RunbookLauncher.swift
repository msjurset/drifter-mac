import AppKit

@MainActor
public final class RunbookLauncher {
    public static func launchRunbook(host: HostItem, event: DriftEvent? = nil, store: DrifterStore) {
        guard store.settings.enableRunbookIntegration else { return }

        let template = store.settings.runbookURLTemplate
        let urlString = template
            .replacingOccurrences(of: "{ip}", with: host.ip)
            .replacingOccurrences(of: "{hostname}", with: host.hostname.isEmpty ? host.ip : host.hostname)
            .replacingOccurrences(of: "{type}", with: event?.type ?? "audit")
            .replacingOccurrences(of: "{detail}", with: (event?.detail ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")

        guard let url = URL(string: urlString) else {
            openRunbookAppFallback()
            return
        }

        let workspace = NSWorkspace.shared
        let runbookAppURL: URL? = {
            if let url = workspace.urlForApplication(withBundleIdentifier: "com.msjurset.runbook-mac") {
                return url
            }
            if FileManager.default.fileExists(atPath: "/Applications/Runbook.app") {
                return URL(fileURLWithPath: "/Applications/Runbook.app")
            }
            return nil
        }()

        if let runbookAppURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.open([url], withApplicationAt: runbookAppURL, configuration: config) { _, error in
                if let error {
                    TerminalLauncher.log("Failed to open URL in Runbook.app: \(error)")
                }
            }
        } else {
            let success = workspace.open(url)
            if !success {
                openRunbookAppFallback()
            }
        }
    }

    private static func openRunbookAppFallback() {
        let workspace = NSWorkspace.shared
        if let runbookAppURL = workspace.urlForApplication(withBundleIdentifier: "com.msjurset.runbook-mac") ??
            (FileManager.default.fileExists(atPath: "/Applications/Runbook.app") ? URL(fileURLWithPath: "/Applications/Runbook.app") : nil) {
            workspace.openApplication(at: runbookAppURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
