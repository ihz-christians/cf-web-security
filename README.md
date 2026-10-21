# Cloudflare & Web API Security Testing Toolkit

[![Container CI](https://github.com/ihz-christians/cf-web-security/actions/workflows/container.yml/badge.svg)](https://github.com/ihz-christians/cf-web-security/actions/workflows/container.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Podman / Docker](https://img.shields.io/badge/Platform-Podman%20%7C%20Docker-orange.svg)]()
[![Security: Non--Root](https://img.shields.io/badge/Security-Non--Root%20(UID%2010001)-green.svg)]()

A reproducible, containerized Application Security (AppSec) testing environment engineered for authorized security assessments of modern web applications, edge architectures (Cloudflare Pages, Workers), and REST/JSON/JWT APIs.

---

## 🇩🇪 Kurzüberblick für Recruiter & Technische Prüfer (Executive Summary)

Dieses Repository demonstriert die Konzeption und Implementierung einer standardisierten, schlanken Security-Testing-Umgebung nach **DevSecOps- und Security-Consulting-Prinzipien**:

* **Warum dieses Projekt?** Statt schwerfällige Standard-VMs (wie Kali Linux) zu verwenden, wurde eine maßgeschneiderte, schlanke OCI-Container-Umgebung für Web- & API-Audits aufgesetzt.
* **Security & Hardening:**
  * **Least Privilege:** Der Container läuft strikt unprivilegiert als Non-Root-User (`UID 10001`, `pentest`), mit verworfenen Linux-Capabilities (`--cap-drop=ALL`) und `--security-opt="no-new-privileges"`.
  * **Ephemeral Runtime:** Container sind zustandslos (`--rm`) und hinterlassen nach dem Testlauf keine Caches oder Artefakte im Image.
* **Consulting & Data Governance:**
  * **„Code in Git, Evidence on Host Disk“:** Strikte Trennung von Werkzeug und Kundendaten. Sämtliche Scan-Artefakte verbleiben auf dem verschlüsselten Host-System (`pentest/runs/`) und sind über `.gitignore` geschützt (DSGVO- & Vertraulichkeits-Konformität).
  * **Scope & Compliance:** Saubere Trennung von autorisierten Zielen ([pentest/targets/scope.md](pentest/targets/scope.md)) und Einbettung von Cloudflare-Compliance-Vorgaben ([docs/compliance/cloudflare.md](docs/compliance/cloudflare.md)).
* **DevOps / CI/CD:**
  * Multi-Stage-Build ([Containerfile](Containerfile)) zur Trennung von Build-Werkzeugen (Go, Rust) und schlankem Runtime-Image.
  * Automatisierte GitHub Actions CI ([.github/workflows/container.yml](.github/workflows/container.yml)) mit Smoke-Tests für alle integrierten Werkzeuge und Multi-Arch-Build (`amd64`/`arm64`).
* **Realistische Methodik:**
  * Fokus auf Edge-Besonderheiten (Origin IP Leak Detection, API Parameter Fuzzing, CORS/JWT-Validation), dokumentiert im strukturierten [Playbook](docs/PLAYBOOK.md).

---

## 1. Overview & Architecture

Modern web applications increasingly rely on Edge CDNs, Serverless Functions (e.g., Cloudflare Pages & Workers), and decoupled Single-Page-Applications (SPAs) backed by RESTful APIs. Assessing these environments requires lightweight, auditable, and automated toolchains.

### Core Architectural Principles

1. **Stateless Processing, Persistent Evidence:** The container acts purely as a stateless computation unit. Scans write directly to host-mounted, timestamped run directories (`pentest/runs/YYYY-MM-DD_target/`).
2. **Reproducibility & Pinned Tooling:** Compiled Go, Rust, Node.js, and Python tools are pinned to defined versions to ensure audit reproducibility across engagements.
3. **Defense in Depth / Non-Root Execution:** The container drops all root privileges, running under UID `10001` with process isolation handled by `tini`.
4. **Scope & Audit Compliance:** Target specifications and Rules of Engagement (RoE) are version-controlled, preventing out-of-scope testing.

## 2. Scope and Intended Use

This toolkit is designed exclusively for:
- Security assessments of systems you own or are explicitly authorized to test.
- Continuous security regression testing within a CI/CD pipeline.
- Internal security audits and compliance checks.

It is **not** intended for:
- Denial-of-service (DoS) or traffic flood testing.
- Automated vulnerability exploitation without human validation.
- Unauthorized scanning of third-party systems.

**Compliance:** All activities must remain strictly within a pre-defined and authorized scope. See [Cloudflare Compliance Protocol](docs/compliance/cloudflare.md).

## 3. Repository Structure

```text
.
├── Containerfile              # Multi-stage build definition (Go/Rust/Runtime)
├── Makefile                   # Project automation interface (build, run, interactive)
├── podman-run.sh              # Batch runner for automated / CI tasks
├── podman-interactive.sh      # Interactive launcher for manual exploration
├── pentest/
│   ├── targets/               # Scope & configuration (Git-tracked)
│   │   ├── scope.md           # Rules of Engagement & authorized assets
│   │   └── targets.txt        # Active scan targets
│   └── runs/                  # Scan Results & Evidence (Git-ignored, Host-only)
└── docs/
    ├── ARCH.md                # System Architecture & Design Specification
    ├── OPERATIONS.md          # Step-by-step Operational Manual
    ├── PLAYBOOK.md            # Structured Pentest Methodology
    └── compliance/            # Legal boundaries and Cloudflare policy alignment
```

## 4. Usage

### 4.1 Setup
Download the required wordlists and build the container image:
```bash
make wordlists
make build
```

### 4.2 Batch Scans ("The Batch Runner")
Execute atomic, single-command scans against a specified target. This automatically creates structured, timestamped output directories on the host and passes `$SCAN_RESULTS_DIR` to the container:

```bash
# Syntax: make run TARGET=<target> CMD='<command>'
make run TARGET=example.com CMD='subfinder -d example.com -o $SCAN_RESULTS_DIR/recon/subdomains.txt'
```

### 4.3 Interactive Exploration ("The Lab")
Start an interactive shell inside the container with your target context pre-configured and command history preserved across sessions:

```bash
# Syntax: make interactive [TARGET=<target>]
make interactive TARGET=example.com
```

**For complete workflows, data management, and troubleshooting, see the [Operations Manual](docs/OPERATIONS.md).**

## 5. Integrated Tool Arsenal

The container bundles a curated selection of single-binary, industry-standard tools:

| Category | Tools | Purpose |
| :--- | :--- | :--- |
| **Reconnaissance** | `subfinder`, `dnsx`, `httpx`, `gau` | DNS discovery, probe resolution, archive extraction |
| **Content & Web** | `nuclei`, `feroxbuster`, `rustscan`, `semgrep`, `dalfox` | Vulnerability scanning, recursive crawling, SAST, XSS |
| **API & Auth Fuzzing** | `ffuf`, `kiterunner`, `arjun`, `jwt_tool` | Route discovery, hidden parameter discovery, JWT testing |
| **Pattern Matching** | `gf`, `qsreplace`, `ripgrep` | URL parameter filtering, pattern extraction |
| **Edge & Protocol** | `testssl.sh`, `h2csmuggler`, `retire.js` | TLS compliance, HTTP/2 smuggling checks, JS supply chain |

## 6. Real-World Operational Considerations

When testing production edge infrastructure (e.g., behind Cloudflare WAF or Bot Management):
1. **Rate Limiting:** Automated scanners (`ffuf`, `nuclei`, `feroxbuster`) must be throttled (`-rl` / `-rate`) to avoid triggering Cloudflare Bot Fight Mode or 429 Too Many Requests.
2. **Origin Discovery:** In edge-hosted environments, DNS enumeration targets non-CDN IP candidates to evaluate if origin servers leak directly to the public internet.
3. **Safe Assessment:** Scanning focuses on configuration issues, exposed secrets, and logic flaws without executing invasive DoS or data-altering payloads.

## 7. Legal Notice & Disclaimer

This toolkit is provided solely for authorized security testing, educational research, and defensive auditing. The operator assumes full responsibility and liability for compliance with applicable laws, third-party terms of service, and explicit contractual authorizations.

