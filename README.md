# Cloudflare Web API Security

## 1. Overview

This repository provides a reproducible, containerized security testing toolkit engineered for authorized penetration tests of modern web application infrastructures, with a specific focus on:

-   **Cloudflare Deployments:** Including Pages, Workers, and Edge APIs.
-   **API-Driven Applications:** Targeting REST, JSON, and JWT-based endpoints.

The toolkit is built upon the **"Golden Phat" Architecture**, prioritizing:
-   **Traceability:** Every action is logged and auditable.
-   **Reproducibility:** Source-based builds ensure tool versions are pinned and immutable.
-   **Isolation:** Strict separation between the tool (container) and the data (host).
-   **Minimalism:** A controlled toolset reduces the attack surface and ensures compliance.

This is a purpose-built application security framework, not a general-purpose offensive distribution.

## 2. Scope and Intended Use

This toolkit is designed exclusively for:
-   Security assessments of systems you own or are explicitly authorized to test.
-   Continuous security regression testing within a CI/CD pipeline.
-   Internal security audits and compliance checks.

It is **not** intended for:
-   Denial-of-service (DoS) or traffic flood testing.
-   Unauthorized scanning of third-party systems.

**Compliance:** All activities must remain strictly within a pre-defined and authorized scope. See `docs/compliance/cloudflare.md`.

## 3. Architecture

The toolkit adheres to strict architectural principles for security and stability.

-   **Multi-Stage Source Build:** Tools are compiled from source (Go/Rust) within the build process. No pre-compiled binaries are downloaded from external sources, ensuring architecture compatibility (AMD64/ARM64) and supply chain security.
-   **Stateless Container:** The container environment is ephemeral (`--rm`). It holds no data.
-   **Persistent Host Storage:** Results are written directly to the host's encrypted filesystem via strict volume mounts.
-   **Non-Root Execution:** The container runs as a dedicated `pentest` user (UID 10001).

## 4. Repository Structure

```text
.
├── Containerfile              # Multi-stage build definition
├── Makefile                   # Project automation interface
├── podman-run.sh              # Runner for automated/CI tasks
├── podman-interactive.sh      # Launcher for manual/lab sessions
├── pentest/
│   ├── targets/               # Configuration (Git-tracked)
│   └── runs/                  # Scan Results (Git-ignored, Local-only)
└── docs/
    ├── ARCH.md                # System Master Artifact
    ├── OPERATIONS.md          # Detailed workflow documentation
    └── compliance/            # Policy documentation
```

## 5. Usage

### 5.1 Setup
First, download the required wordlists and build the container image.
```bash
make wordlists
make build
```

### 5.2 Automated Scans ("The Sniper")
Use `make run` for single commands. This automatically creates timestamped result directories and handles volume mounting.

```bash
# Syntax: make run TARGET=<target> CMD='<command>'
make run TARGET=example.com CMD='httpx -u https://example.com -title'
```

### 5.3 Interactive Lab ("The Lab")
Use `make interactive` for manual exploration. This mounts your command history and drops you into a shell inside the result directory.

```bash
# Syntax: make interactive [TARGET=<target>]
make interactive TARGET=example.com
```

**For detailed instructions, workflows, and data management, please refer to the [Operations Manual](docs/OPERATIONS.md).**

## 6. Integrated Tooling

The toolkit includes a curated selection of best-in-class, single-binary tools:

| Category | Tools |
| :--- | :--- |
| **Reconnaissance** | `subfinder`, `dnsx`, `httpx`, `gau` |
| **Scanning** | `nuclei`, `feroxbuster`, `rustscan`, `semgrep`, `dalfox` |
| **Fuzzing** | `ffuf`, `kiterunner`, `arjun`, `jwt_tool` |
| **Utilities** | `gf`, `qsreplace` |
| **Compliance** | `testssl.sh`, `h2csmuggler`, `retire.js` |

## 7. Legal Notice

This toolkit is provided for authorized security testing purposes only. The user assumes all liability for any misuse of this software outside of a legally authorized engagement.
