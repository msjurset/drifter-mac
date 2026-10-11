# Drifter (`drifter-mac`)

**Drifter** is a fast, lightweight, native macOS homelab watchdog and local network security auditor. Built with Swift 6, AppKit, and SwiftUI, Drifter continuously monitors your local subnets, discovers mDNS microservices, and detects port drift or unauthorized rogue devices without cloud dependencies, daemons running as root, or subscription fees.

Whether managing a rack of Proxmox VE hypervisors, Raspberry Pi clusters, Docker microservices, or a busy IoT network with Home Assistant, Drifter gives you instant visibility into what’s online, what services are exposed, and what has changed over time.

📖 **For detailed setup, keyboard shortcuts, and incident response workflows, see the [User Guide](USER_GUIDE.md).**

---

## Preview

<p align="right"><sub><em>Image anonymized by <a href="https://github.com/msjurset/anonymark">msjurset/anonymark</a></em></sub></p>

![Drifter Dashboard](docs/images/dashboard.png)

<br>

<p align="right"><sub><em>Image anonymized by <a href="https://github.com/msjurset/anonymark">msjurset/anonymark</a></em></sub></p>

![Drifter Drift Alerts](docs/images/alerts.png)

---

## Why Drifter?

Most network scanners fall into two extremes:
1. **Raw CLI utilities** (`nmap`, `arp`, `ping`) that provide point-in-time terminal output without tracking historical state, drift, or baseline changes over time.
2. **Heavyweight enterprise monitoring systems** (Zabbix, PRTG, Nagios) that require dedicated server infrastructure, SNMP agent configurations, and complex dashboards.

**Drifter bridges this gap directly on macOS:**
- **Authoritative Baselining**: Snapshot your network once. Any unexpected port, new MAC address, or IP shift triggers a drift alert.
- **Granular Baseline Evolution**: When you spin up a new container or add a smart plug, approve it into the baseline with one click—no need to wipe and reset your network baseline.
- **Zero-Configuration Discovery**: Combines active ARP cache warming with Apple's native Bonjour framework (`NWBrowser`) to identify devices, vendors, and services automatically.
- **Immediate Actionability**: Spawns SSH terminal sessions in Ghostty with Touch ID authentication, opens web administration interfaces, wakes devices with Wake-on-LAN, and triggers operational runbooks directly from any alert or host card.

---

## Key Features

- **Authoritative Baseline & One-Click Blessing**: Start in rolling discovery mode and bless your entire network into a locked baseline with one click (**Bless All & Lock Baseline**). Progressively approve changes as your homelab grows.
- **Port Drift & Rogue Host Detection**: Instant alerts when ports open or close, IP addresses reassign, or unapproved devices join the subnet.
- **Subnet ARP Sweeper**: Non-blocking UDP broadcast sweeper warms the macOS kernel ARP cache across active `/24` subnets, ensuring sleeping microcontrollers and quiet IoT nodes are never missed.
- **Native Bonjour Discovery**: Uses Apple's `Network.framework` (`NWBrowser`) to discover live Zeroconf services (`_home-assistant`, `_esphomelib`, `_matter`, `_airplay`, `_smb`, `_printer`, `_ssh`).
- **Comprehensive Hardware OUI & IoT Categorization**: Out-of-the-box vendor recognition for Logitech (Harmony Hub), Roku, Smart TVs (Samsung, LG, Sony), smart home hubs (Shelly, LIFX, Broadlink, Lutron, Wyze, Eufy, Roborock, Meross, Chamberlain/myQ, Withings, Nanoleaf, Belkin/Wemo), and network infrastructure (Ubiquiti, Cisco, ASUS, Amazon Eero, Netgear, MikroTik).
- **Interactive Device Categorization**: Organize devices into **Servers & Storage**, **IoT & Smart Home**, **Workstation & PC**, and **Network Infrastructure** with live sidebar filtering and an interactive dropdown on each device profile.
- **Deep Port Probe & Service Detection**: On-demand 23-port scanner detecting Proxmox VE, Portainer, Home Assistant, Plex, Jellyfin, Cockpit, Grafana, Synology DSM, MQTT, and databases with smart 1-click web launcher badges.
- **Right-Click Alert Context Menus**: Native macOS menus on alert rows to trigger targeted Deep Security Investigations, jump to host inventory, open web interfaces, launch SSH sessions, execute runbooks, or dismiss alerts.
- **Wake-on-LAN (WoL)**: Native magic packet sender (`0xFF * 6` + `MAC * 16`) to power on or wake sleeping workstations, servers, and NAS nodes.
- **Terminal & 1Password Touch ID Integration**: Launch SSH terminal sessions in **Ghostty**, Apple Terminal, or iTerm2 with `~/.ssh/config` alias resolution and `SSH_AUTH_SOCK` Touch ID key authentication.
- **Runbook Automation Deep-Linking**: One-click integration with [Runbook](https://github.com/msjurset/runbook-mac) (`runbook://execute?template=security-audit&host={ip}`).
- **Optional AI Security Advisor**: On-demand fast triage (~1s) or multi-pass **Deep Security Reasoning** (up to 4,096 tokens) with adversarial homelab threat modeling. Strictly additive and disabled by default. Supports local private Ollama (`llama3.2`) as well as cloud BYOK (Google Gemini, Anthropic Claude, OpenAI) with 1Password Touch ID secret references (`op://`).
- **Network Security Audit Reports**: One-click export to GitHub Flavored Markdown (`.md`) or structured JSON (`.json`) inventory reports.
- **Background Watchdog & Menu Bar Agent**: Configurable background scan timer with native desktop notifications, live drift count badge, and quick window toggle.
- **100% Offline & Local**: Zero telemetry, zero analytics, zero cloud dependencies. All state persisted locally in `~/Library/Application Support/DrifterMac/drifter_store.json`.

---

## Architecture & Integration

```
[ Subnet ARP Sweeper ] ──┐
[ Bonjour NWBrowser  ] ──┼──> [ Drifter Scanner Engine ]
[ Hardware OUI Map   ] ──┘                 │
                                           ▼
                              [ Authoritative Baseline ]
                                (Incremental Evolution)
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
[ Ghostty / SSH Terminal ]     [ Runbook Automation ]            [ AI Security Advisor ]
(1Password Touch ID Agent)      (runbook://execute?...)         (Optional Ollama / BYOK)
         │                                 │                                 │
         └─────────────────────────────────┴─────────────────────────────────┘
                                           │
                                           ▼
                              [ Native macOS Menu Bar ]
                               (Live Alerts & Watchdog)
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

#### Package Release Archive

```bash
# Compile Release Binary & Create dist/Drifter-<version>.zip
make archive
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
