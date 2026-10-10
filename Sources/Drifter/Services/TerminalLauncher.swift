import AppKit

public struct SSHConfigHost {
    public let hostAlias: String
    public let hostname: String?
    public let user: String?
    public let identityAgent: String?
}

public final class SSHConfigParser {
    public static func parseSSHConfig() -> [SSHConfigHost] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.ssh/config"
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }

        var results: [SSHConfigHost] = []
        var currentAliases: [String] = []
        var currentHostname: String?
        var currentUser: String?
        var currentAgent: String?

        func flushCurrent() {
            for alias in currentAliases {
                if alias != "*" {
                    results.append(SSHConfigHost(
                        hostAlias: alias,
                        hostname: currentHostname,
                        user: currentUser,
                        identityAgent: currentAgent
                    ))
                }
            }
            currentAliases = []
            currentHostname = nil
            currentUser = nil
            currentAgent = nil
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count >= 1 else { continue }
            let key = parts[0].lowercased()
            let val = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

            if key == "host" {
                flushCurrent()
                currentAliases = val.split(separator: " ").map(String.init)
            } else if key == "hostname" {
                currentHostname = val
            } else if key == "user" {
                currentUser = val
            } else if key == "identityagent" {
                currentAgent = val
            }
        }
        flushCurrent()
        return results
    }

    public static func findBestSSHTarget(ip: String, hostname: String) -> String {
        let entries = parseSSHConfig()
        
        // 1. Match by exact IP address configured under Hostname (e.g. Hostname 192.168.86.55 -> Host pi-hole)
        if let match = entries.first(where: { $0.hostname?.trimmingCharacters(in: .whitespaces) == ip }) {
            return match.hostAlias
        }

        // 2. Match by normalized hostname (e.g. pi.hole vs pi-hole, pi.local -> pi)
        let cleanHostname = hostname.lowercased()
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".lan", with: "")
        
        if let match = entries.first(where: {
            let alias = $0.hostAlias.lowercased()
            return alias == cleanHostname ||
                   alias == hostname.lowercased() ||
                   alias.replacingOccurrences(of: "-", with: ".") == hostname.lowercased() ||
                   hostname.lowercased().replacingOccurrences(of: ".", with: "-") == alias
        }) {
            return match.hostAlias
        }

        // 3. Fallback to hostname if available, or IP
        return hostname.isEmpty ? ip : hostname
    }
}

public final class TerminalLauncher {
    public nonisolated static func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        print("[Drifter] \(msg)")
        if let data = line.data(using: .utf8) {
            let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("drifter_debug.log")
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    @MainActor
    public static func launchSSH(ip: String, hostname: String = "", store: DrifterStore) {
        let settings = store.settings
        let user = settings.defaultSSHUser.trimmingCharacters(in: .whitespaces)

        // Parse ~/.ssh/config for matching Host aliases (e.g. 192.168.86.55 -> Host pi-hole)
        let matchedTarget = SSHConfigParser.findBestSSHTarget(ip: ip, hostname: hostname)
        let sshTarget = user.isEmpty ? matchedTarget : "\(user)@\(matchedTarget)"

        log("launchSSH target resolved to: \(sshTarget) (from ip: \(ip), hostname: \(hostname))")

        switch settings.preferredTerminal {
        case .ghostty:
            launchGhostty(sshTarget: sshTarget)
        case .terminal:
            launchAppleTerminal(sshTarget: sshTarget)
        case .iterm:
            launchITerm(sshTarget: sshTarget)
        case .custom:
            launchCustom(commandTemplate: settings.customTerminalCommand, sshTarget: sshTarget)
        }
    }

    @MainActor
    public static func launchTest(store: DrifterStore) {
        let settings = store.settings
        log("launchTest starting for preferred terminal: \(settings.preferredTerminal.rawValue)")

        switch settings.preferredTerminal {
        case .ghostty:
            launchGhosttyTest(settings: settings)
        case .terminal:
            launchAppleTerminalTest(settings: settings)
        case .iterm:
            launchITermTest(settings: settings)
        case .custom:
            launchCustomTest(settings: settings)
        }
    }

    private static func launchGhostty(sshTarget: String) {
        log("launchGhostty starting via .command script for \(sshTarget)")
        let workspace = NSWorkspace.shared
        let ghosttyAppURL: URL? = {
            if let url = workspace.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
                return url
            }
            if FileManager.default.fileExists(atPath: "/Applications/Ghostty.app") {
                return URL(fileURLWithPath: "/Applications/Ghostty.app")
            }
            return nil
        }()

        guard let ghosttyAppURL else {
            log("Ghostty.app not found. Falling back to Apple Terminal.")
            launchAppleTerminal(sshTarget: sshTarget)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let safeTarget = sshTarget.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        let scriptURL = tempDir.appendingPathComponent("drifter_ssh_\(safeTarget).command")

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opSock = "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

        let scriptContent = """
        #!/bin/zsh
        export SSH_AUTH_SOCK="\(opSock)"
        echo "Connecting to \(sshTarget) via SSH..."
        ssh \(sshTarget)
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            echo ""
            echo "----------------------------------------------------------"
            echo "SSH disconnected with exit code $EXIT_CODE."
            echo "Starting interactive shell for troubleshooting..."
            echo "----------------------------------------------------------"
            echo ""
            exec zsh -l
        fi
        """

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            workspace.open([scriptURL], withApplicationAt: ghosttyAppURL, configuration: config) { _, error in
                if let error {
                    log("Failed to open .command script in Ghostty: \(error)")
                } else {
                    log("Successfully launched .command script in Ghostty for \(sshTarget)")
                }
            }
        } catch {
            log("Failed to write temporary .command script: \(error)")
        }
    }

    private static func launchGhosttyTest(settings: AppSettings) {
        log("launchGhosttyTest starting")
        let workspace = NSWorkspace.shared
        let ghosttyAppURL: URL? = {
            if let url = workspace.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
                return url
            }
            if FileManager.default.fileExists(atPath: "/Applications/Ghostty.app") {
                return URL(fileURLWithPath: "/Applications/Ghostty.app")
            }
            return nil
        }()

        guard let ghosttyAppURL else {
            log("Ghostty.app not found. Falling back to Apple Terminal.")
            launchAppleTerminalTest(settings: settings)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("drifter_terminal_test.command")

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opSock = "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

        let scriptContent = """
        #!/bin/zsh
        export SSH_AUTH_SOCK="\(opSock)"
        clear
        echo "=========================================================="
        echo "  Drifter Terminal & SSH Dispatch Test"
        echo "=========================================================="
        echo "✓ Preferred Terminal : Ghostty"
        if [ -S "$SSH_AUTH_SOCK" ]; then
            echo "✓ 1Password SSH Agent: Connected ($SSH_AUTH_SOCK)"
        else
            echo "• 1Password SSH Agent: Socket not detected at standard path"
        fi
        echo "✓ OpenSSH Client     : $(ssh -V 2>&1)"
        echo "----------------------------------------------------------"
        echo "Terminal dispatch is configured and operational!"
        echo "Click 'SSH' on any active host card in Drifter to connect."
        echo "=========================================================="
        echo ""
        exec zsh -l
        """

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            workspace.open([scriptURL], withApplicationAt: ghosttyAppURL, configuration: config) { _, error in
                if let error {
                    log("Failed to open test .command script in Ghostty: \(error)")
                } else {
                    log("Successfully launched test .command script in Ghostty")
                }
            }
        } catch {
            log("Failed to write temporary test .command script: \(error)")
        }
    }

    private static func launchAppleTerminalTest(settings: AppSettings) {
        log("launchAppleTerminalTest starting")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opSock = "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        let script = """
        tell application "Terminal"
            do script "clear; echo '=========================================================='; echo '  Drifter Terminal & SSH Dispatch Test'; echo '=========================================================='; echo '✓ Preferred Terminal : Apple Terminal'; if [ -S \\\"\(opSock)\\\" ]; then echo '✓ 1Password SSH Agent: Connected'; fi; echo '✓ OpenSSH Client     : '`ssh -V 2>&1`; echo '----------------------------------------------------------'; echo 'Terminal dispatch is configured and operational!'; echo 'Click \\'SSH\\' on any active host card in Drifter to connect.'; echo '=========================================================='; echo ''"
            activate
        end tell
        """
        runAppleScript(script)
    }

    private static func launchITermTest(settings: AppSettings) {
        log("launchITermTest starting")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opSock = "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        let script = """
        tell application "iTerm"
            create window with default profile command "zsh -c \\\"clear; echo '=========================================================='; echo '  Drifter Terminal & SSH Dispatch Test'; echo '=========================================================='; echo '✓ Preferred Terminal : iTerm2'; if [ -S \\\\\\\"\(opSock)\\\\\\\" ]; then echo '✓ 1Password SSH Agent: Connected'; fi; echo '✓ OpenSSH Client     : '`ssh -V 2>&1`; echo '----------------------------------------------------------'; echo 'Terminal dispatch is configured and operational!'; echo 'Click \\\\\\'SSH\\\\\\' on any active host card in Drifter to connect.'; echo '=========================================================='; echo ''; exec zsh -l\\\""
            activate
        end tell
        """
        runAppleScript(script)
    }

    private static func launchCustomTest(settings: AppSettings) {
        log("launchCustomTest starting with template: \(settings.customTerminalCommand)")
        let dummyTarget = "test-host"
        launchCustom(commandTemplate: settings.customTerminalCommand, sshTarget: dummyTarget)
    }

    private static func launchAppleTerminal(sshTarget: String) {
        log("launchAppleTerminal starting for \(sshTarget)")
        let script = """
        tell application "Terminal"
            do script "ssh \(sshTarget)"
            activate
        end tell
        """
        runAppleScript(script)
    }

    private static func launchITerm(sshTarget: String) {
        log("launchITerm starting for \(sshTarget)")
        let script = """
        tell application "iTerm"
            create window with default profile command "ssh \(sshTarget)"
            activate
        end tell
        """
        runAppleScript(script)
    }

    private static func launchCustom(commandTemplate: String, sshTarget: String) {
        log("launchCustom starting for \(sshTarget) with template: \(commandTemplate)")
        Task.detached(priority: .userInitiated) {
            let cmd = commandTemplate
                .replacingOccurrences(of: "{ip}", with: sshTarget)
                .replacingOccurrences(of: "{target}", with: sshTarget)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd]
            do {
                try process.run()
                process.waitUntilExit()
                log("Custom process finished with status: \(process.terminationStatus)")
            } catch {
                log("Failed to run custom command: \(error)")
            }
        }
    }

    private static func runAppleScript(_ script: String) {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                log("AppleScript error: \(error)")
            }
        }
    }
}
