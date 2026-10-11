# Drifter (`drifter-mac`)

**Drifter** is a lightweight, native macOS application for real-time local network host monitoring, mDNS microservice discovery, and port drift security auditing. Built with Swift 6, AppKit, and SwiftUI, Drifter provides instant visibility over your home lab, Raspberry Pi nodes, Home Assistant instances, Docker services, and local subnets without cloud lock-in or subscription bloat.

📖 **For detailed usage instructions and workflows, see the [User Guide](USER_GUIDE.md).**

---

## Preview

<p align="right"><sub><em>Image anonymized by <a href="https://github.com/msjurset/anonymark">msjurset/anonymark</a></em></sub></p>

![Drifter Dashboard](docs/images/dashboard.png)

<br>

<p align="right"><sub><em>Image anonymized by <a href="https://github.com/msjurset/anonymark">msjurset/anonymark</a></em></sub></p>

![Drifter Drift Alerts](docs/images/alerts.png)

---

## Key Features

- **Authoritative Baseline & Granular Evolution**: Snapshot and lock your known-good network state. Incremental "Approve into Baseline" allows seamless evolution when you add services, without blowing away the entire network baseline.
- **Port Drift & Rogue Host Detection**: Detects newly opened ports, closed ports, IP changes, and unapproved rogue devices joining the subnet.
- **Subnet ARP Sweeper**: Non-blocking UDP sweeper warms the kernel ARP cache across the active `/24` subnet, ensuring quiet IoT devices and sleeping microcontrollers are never missed.
- **Native Bonjour Discovery**: Uses Apple's `Network.framework` (`NWBrowser`) to discover live mDNS services (`_home-assistant`, `_esphomelib`, `_matter`, `_smb`, `_airplay`, `_printer`, `_ssh`).
- **Deep Port Probe & Homelab Service Detection**: On-demand 23-port scanner detecting Proxmox VE, Portainer, Home Assistant, Plex, Cockpit, Grafana, Synology DSM, MQTT, and databases with smart 1-click web launcher badges.
- **Wake-on-LAN (WoL)**: Native magic packet sender (`0xFF * 6` + `MAC * 16`) to power on or wake sleeping workstations, servers, and NAS nodes.
- **Network Security Audit Reports**: One-click export to GitHub Flavored Markdown (`.md`) or structured JSON (`.json`) inventory reports.
- **Background Watchdog**: Configurable background scan timer with native desktop notifications and Menu Bar badge alerts.
- **Terminal & 1Password Touch ID Integration**: Launch SSH terminal sessions in **Ghostty**, Apple Terminal, or iTerm2 with `~/.ssh/config` alias resolution and `SSH_AUTH_SOCK` Touch ID key authentication.
- **Runbook Automation Deep-Linking**: One-click integration with [Runbook](https://github.com/msjurset/runbook-mac) (`runbook://execute?template=security-audit&host={ip}`).
- **Optional AI Security Advisor**: On-demand fast drift triage and deep multi-step security investigations. Strictly additive and disabled by default (supports local private Ollama as well as Google Gemini, Anthropic Claude, and OpenAI with 1Password Touch ID secret references).
- **100% Offline & Local**: Zero telemetry, zero cloud dependencies. All state persisted locally in JSON.

---

## Architecture & Integration

```
[ Local Subnet ARP / mDNS ] ──> [ Drifter Scanner Engine ]
                                          │
                  ┌───────────────────────┼───────────────────────┐
                  ▼                       ▼                       ▼
      [ Ghostty / SSH Terminal ]  [ Runbook Automation ]  [ AI Security Advisor ]
   (1Password Touch ID Agent)   (runbook://execute?...) (Optional Ollama / BYOK)
```

---

## Installation

### Via Homebrew (Recommended)

```bash
brew tap msjurset/tap
brew install --cask drifter-mac
```

### From Source

#### Prerequisites
- macOS 14.0 or later
- Swift 6.0+ toolchain / Xcode 15+

#### Build & Deploy Locally

```bash
# Run Unit Tests
make test

# Compile & Deploy to Local /Applications
make deploy
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
