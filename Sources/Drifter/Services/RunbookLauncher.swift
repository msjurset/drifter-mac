import AppKit
import SwiftUI

@MainActor
public final class RunbookLauncher {
    public static func launchRunbook(host: HostItem, event: DriftEvent? = nil, store: DrifterStore) {
        guard store.settings.enableRunbookIntegration else { return }

        let template = store.settings.runbookURLTemplate
        let hostStr = host.hostname.isEmpty ? host.ip : host.hostname
        let ipStr = host.ip
        let typeStr = event?.type ?? "audit"

        // Resolve SSH host alias via SSHConfigParser (e.g. 192.168.86.55 -> pi-hole, 192.168.86.1 -> router)
        let targetHost = SSHConfigParser.findBestSSHTarget(ip: host.ip, hostname: host.hostname)

        // Extract runbook template name from template string (e.g. "runbook://execute?template=security-audit" -> "security-audit")
        var runbookName = "security-audit"
        if template.contains("template=") {
            if let range = template.range(of: "template=") {
                let substring = template[range.upperBound...]
                let components = substring.split(separator: "&")
                if let first = components.first, !first.isEmpty {
                    runbookName = String(first)
                }
            }
        }

        // Open Runbook.app GUI if installed
        let workspace = NSWorkspace.shared
        if let runbookAppURL = workspace.urlForApplication(withBundleIdentifier: "com.msjurset.runbook-mac") ??
            (FileManager.default.fileExists(atPath: "/Applications/Runbook.app") ? URL(fileURLWithPath: "/Applications/Runbook.app") : nil) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.openApplication(at: runbookAppURL, configuration: config)
        }

        // Locate runbook CLI binary & 1Password SSH agent socket
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opSock = "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        let candidates = [
            "\(home)/.local/bin/runbook",
            "/usr/local/bin/runbook",
            "/opt/homebrew/bin/runbook"
        ]
        let runbookBin = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "runbook"

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = ipStr.replacingOccurrences(of: ".", with: "_")
        let scriptURL = tempDir.appendingPathComponent("drifter_runbook_\(safeName).command")

        let scriptContent = """
        #!/bin/zsh
        if [ -S "\(opSock)" ]; then
            export SSH_AUTH_SOCK="\(opSock)"
        fi

        echo "======================================================="
        echo " Drifter Watchdog — Executing Runbook: \(runbookName)"
        echo " Target Host: \(targetHost) (\(ipStr))"
        echo " Event Type:  \(typeStr)"
        echo "======================================================="
        echo ""
        "\(runbookBin)" run \(runbookName) --var host="\(targetHost)" --var ip="\(ipStr)" --var hostname="\(hostStr)" --var type="\(typeStr)" || "\(runbookBin)" run triage --var host="\(targetHost)" --var ip="\(ipStr)" --var hostname="\(hostStr)" || "\(runbookBin)" list
        echo ""
        echo "Press any key to close..."
        read -k 1
        """

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let ghosttyAppURL: URL? = workspace.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") ??
                (FileManager.default.fileExists(atPath: "/Applications/Ghostty.app") ? URL(fileURLWithPath: "/Applications/Ghostty.app") : nil)

            if let ghosttyAppURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                workspace.open([scriptURL], withApplicationAt: ghosttyAppURL, configuration: config) { _, error in
                    if let error {
                        TerminalLauncher.log("Failed to launch runbook in Ghostty: \(error)")
                    }
                }
            } else {
                workspace.open(scriptURL)
            }
        } catch {
            TerminalLauncher.log("Failed to create runbook script: \(error)")
        }
    }
}
