# Drifter Practical Cookbook

Hands-on recipes for securing your homelab subnet, establishing an authoritative gold-master baseline, triaging port drift incidents, and automating remediation with **Drifter**, **1Password**, and **Runbook**.

---

## Table of Contents

1. [Recipe 1: Establishing a Zero-Trust Homelab Baseline](#recipe-1-establishing-a-zero-trust-homelab-baseline)
2. [Recipe 2: Triaging an Unexpected Open Container Port](#recipe-2-triaging-an-unexpected-open-container-port)
3. [Recipe 3: Detecting & Isolating Unapproved / Rogue IoT Devices](#recipe-3-detecting--isolating-unapproved--rogue-iot-devices)
4. [Recipe 4: 1-Click SSH with `~/.ssh/config` & 1Password Touch ID](#recipe-4-1-click-ssh-with-sshconfig--1password-touch-id)
5. [Recipe 5: Automated Incident Response with Runbook Deep Links](#recipe-5-automated-incident-response-with-runbook-deep-links)
6. [Recipe 6: 100% Local AI Threat Modeling with Ollama (`llama3.2`)](#recipe-6-100-local-ai-threat-modeling-with-ollama-llama32)
7. [Recipe 7: GitOps Network Compliance & Audit Report Diffing](#recipe-7-gitops-network-compliance--audit-report-diffing)

---

## Recipe 1: Establishing a Zero-Trust Homelab Baseline

**Goal**: Discover every active host and microservice on your LAN, classify servers vs. IoT devices, and lock an authoritative baseline so any future port or device change triggers an immediate alert.

![Drifter All Hosts Dashboard](assets/network_dashboard.png)

### Steps
1. **Run an Initial Subnet Sweep**:
   - Click **Scan Local Network** at the bottom of the left sidebar (**[1]**). Drifter warms the macOS kernel ARP cache across your active `/24` subnet, inspects `/usr/sbin/arp -a`, queries mDNS/Bonjour services, and resolves hardware vendors via OUI lookup.
2. **Run Deep Scans on Core Hypervisors & NAS Nodes**:
   - Select each server (`pve-cluster-01.lan`, `nas-vault-01.lan`) and click **Deep Scan** in the top action bar (**[3]**).
   - Drifter probes 23 homelab ports (`8006` Proxmox, `9443` Portainer, `5000/5001` Synology DSM, `8123` Home Assistant, `3000` Grafana, `5432` PostgreSQL, `6379` Redis) and populates **Homelab Service Launchers** (**[4]**).
3. **Verify Device Categories**:
   - Check **Servers & Storage** and **IoT & Microservices** in the sidebar. If any host needs reclassification, use the **Category** dropdown under **Device Profile**.
4. **Bless & Lock the Authoritative Baseline**:
   - Switch to **Drift Alerts** in the sidebar and click **Bless All** (or **Bless Baseline > Bless All & Lock Baseline**).
   - Every current host is marked `Approved Host`, its current open ports are recorded as `Baseline Ports`, and the sidebar displays `Baseline: Locked`.

---

## Recipe 2: Triaging an Unexpected Open Container Port

**Goal**: Investigate why a new port (`9443` or `8080`) appeared on an approved server and either remediate the exposure or approve it into the baseline.

![Drift & Security Alerts](assets/drift_alerts.png)

### Steps
1. **Inspect the Drift Alert**:
   - Open **Drift Alerts** (**[1]**). Locate the orange `Port Opened` badge on the affected host (**[3]**).
2. **Open the Interactive Port Security Explainer**:
   - Click the orange warning icon or the `Port Opened` capsule badge (**[3]**).
   - Review the **Port Security Explainer** popover, which details common services on that port, potential attack vectors, and copyable verification commands (`lsof -i :9443`, `ss -tulpn`).
3. **Verify or Remediate**:
   - **If legitimate** (e.g., you just deployed Portainer over HTTPS on `nas-vault-01.lan`): Click the green **Approve** button (**[4]**) to merge port `9443` into that host's `Baseline Ports` without resetting other hosts.
   - **If unauthorized or accidental**: Right-click the alert row, select **Launch SSH Session**, stop the rogue container, and re-scan the host.

---

## Recipe 3: Detecting & Isolating Unapproved / Rogue IoT Devices

**Goal**: Catch unknown devices that join your Wi-Fi or VLAN after your baseline is locked and audit their exposed services.

![Device Categories Filtering](assets/device_categories.png)

### Steps
1. **Enable Background Watchdog Polling**:
   - In **Settings > Security & Drift Alerts**, set **Background Watchdog Polling** to **Every 15 minutes** and enable **Log and alert when port drift or new hosts are detected**.
2. **Filter for Drift Status**:
   - When a desktop notification or menu bar badge alerts you to a `New Host`, open **All Hosts** and type `status:drift` in the filter bar.
   - Any device that joined after your baseline lock displays an `Unapproved / Rogue` badge in its **Device Profile** (**[3]**).
3. **Inspect mDNS & Vendor Signatures**:
   - Check the hardware **Vendor** (resolved from the MAC OUI) and **Discovered Services (mDNS)** (**[4]**) to identify what the device is broadcasting (`_esphomelib._tcp`, `_http._tcp`, `_matter._tcp`).
4. **Approve or Quarantine**:
   - If you recognize the device, click **Approve Host** in the action bar. Otherwise, block its MAC address on your router/firewall and click **Forget** once removed.

---

## Recipe 4: 1-Click SSH with `~/.ssh/config` & 1Password Touch ID

**Goal**: Connect to any discovered host in Ghostty, iTerm2, or Apple Terminal using your existing SSH aliases and 1Password Touch ID keys.

### Steps
1. **Map Hosts in `~/.ssh/config` (Optional)**:
   ```sshconfig
   Host nas-vault
       HostName 10.0.20.15
       User sysadmin
       Port 22
       IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
   ```
2. **Configure Your Terminal in Drifter**:
   - Open **Settings > Terminal & SSH Dispatch** and choose **Ghostty** (or **Apple Terminal** / **iTerm2**).
3. **Launch SSH from Any Host or Alert**:
   - Click **SSH** on any host card (or right-click any Drift Alert and choose **Launch SSH Session**).
   - Drifter matches `10.0.20.15` to `Host nas-vault` in `~/.ssh/config`, exports `SSH_AUTH_SOCK` for 1Password, and opens your terminal with Touch ID authentication ready.

---

## Recipe 5: Automated Incident Response with Runbook Deep Links

**Goal**: Trigger parameterized operational playbooks in **Runbook.app** directly from a Drifter host card or security alert.

![Drifter Settings](assets/settings_scanner.png)

### Steps
1. **Verify Runbook Integration in Settings**:
   - Open **Settings > Runbook Procedure Dispatch** (**[2]**) and confirm **Enable Runbook Integration** is checked.
   - Default template:
     ```text
     runbook://execute?template=security-audit&host={ip}
     ```
2. **Dispatch from a Drift Alert**:
   - In **Drift Alerts**, click **Runbook** on any alert row (or right-click and choose **Runbook Triage**).
   - Drifter launches `Runbook.app` with `security-audit.yaml` pre-populated for the target host IP, checking `ufw`/`iptables` status, listening sockets, and recent SSH auth logs.

---

## Recipe 6: 100% Local AI Threat Modeling with Ollama (`llama3.2`)

**Goal**: Synthesize multi-host drift events and perform deep lateral-movement threat modeling without sending a single packet to the cloud.

### Steps
1. **Start Ollama Locally**:
   ```bash
   ollama pull llama3.2
   ollama serve
   ```
2. **Enable the AI Security Advisor**:
   - In **Settings > AI Security Advisor (Optional)**, toggle **Enable AI Security Advisor** ON.
   - Select **Ollama (Local)**, verify the endpoint is `http://localhost:11434`, and click **Test Connection**.
3. **Run Fast Triage or Deep Security Investigation**:
   - In **Drift Alerts**, click **AI Triage** for a sub-second executive brief, or click the dropdown arrow and select **Deep Security Investigation** for multi-step attack surface analysis with copyable remediation commands.
   - Using Cloud BYOK instead? Paste a 1Password reference (`op://Private/Gemini/api_key`) into the API Key field so raw credentials are never stored on disk.

---

## Recipe 7: GitOps Network Compliance & Audit Report Diffing

**Goal**: Export point-in-time network posture reports in Markdown and JSON to track homelab infrastructure changes in Git.

### Steps
1. **Export a Compliance Snapshot**:
   - Open **Drift Alerts**, click **Export Audit** in the top-right toolbar, and choose **Export Markdown (`.md`)** or **Export JSON (`.json`)** (also accessible from the menu bar icon or **Settings** **[4]**).
2. **Commit & Diff in Your Homelab Repo**:
   ```bash
   cp ~/Downloads/drifter_network_audit.json ~/homelab/audits/latest.json
   git diff ~/homelab/audits/latest.json
   ```
   The report captures compliance percentage, locked baseline timestamps, full host/MAC/vendor/port matrices, and unacknowledged drift events.
