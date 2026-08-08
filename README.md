# Drifter (`drifter-mac`)

**Drifter** is a lightweight, native macOS application for real-time local network host monitoring, mDNS microservice discovery, and port drift security auditing. Built with Swift 6, AppKit, and SwiftUI, Drifter provides instant visibility over your home lab, Raspberry Pi nodes, Home Assistant instances, Docker services, and local subnets without cloud lock-in or subscription bloat.

---

## Key Features

- **Port Drift & Security Auditing**: Automatically detects when network hosts open new ports, close existing ports, or change IP lease assignments.
- **Subnet & mDNS Service Discovery**: Scans local ARP tables, probes common service ports (SSH, HTTP, HTTPS, Home Assistant, DNS, SMB), and parses mDNS broadcast tags (`_home-assistant._tcp`, `_http._tcp`).
- **Terminal & 1Password Touch ID Integration**: Launch SSH terminal sessions in **Ghostty**, Apple Terminal, or iTerm2. Resolves `~/.ssh/config` host aliases (e.g. `pi-hole`, `ha`, `wrt`) and passes `SSH_AUTH_SOCK` for Touch ID key authentication.
- **Runbook Automation Deep-Linking**: One-click integration with [Runbook](https://github.com/msjurset/runbook-mac) (`runbook://execute?template=security-audit&host={ip}`) to launch automated security audits and triage procedures.
- **Menu Bar Status Item**: Native macOS menu bar item with live drift alerts and category status.
- **100% Offline & Local**: Stores all scan baselines, host profiles, and drift logs locally in JSON state. Zero telemetry, zero cloud dependencies.

---

## Architecture & Integration

```
[ Local Subnet ARP / mDNS ] ──> [ Drifter Scanner Engine ]
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
      [ Ghostty / SSH Terminal ]                    [ Runbook Automation ]
   (1Password Touch ID Agent)                  (runbook://execute?template=...)
```

---

## Build & Installation

### Prerequisites
- macOS 14.0 or later
- Swift 6.0+ toolchain / Xcode 15+

### Build & Deploy

```bash
# Run Unit Tests
make test

# Compile Release Binary & Package App Bundle
make deploy
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
