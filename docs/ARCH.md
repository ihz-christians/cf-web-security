# ARCH.md — System Master Artifact

**Status:** Active
**Version:** 1.0.0
**Context:** High-Security Pentest Toolkit ("Golden Phat")

---

## 1. System Definition

This repository hosts a **contained, reproducible, and secure penetration testing environment** designed for auditing Cloudflare applications and infrastructure. It strictly adheres to the **Golden Phat** architecture, prioritizing cognitive clarity, immutability, and supply chain security.

The system is agnostic to the host OS, relying entirely on a strictly defined OCI container image managed via Podman.

## 2. Core Principles

1.  **Immutability:** The runtime environment is read-only. Tools are baked in at build time. No ad-hoc `apt-get install` during operations.
2.  **Source-Based Integrity:** We do not trust external pre-compiled binaries. All Go and Rust tools are compiled from pinned source versions within the build process.
3.  **Data Sovereignty:** All scan data resides in `pentest/`. The container is ephemeral; the data is persistent.
4.  **Cognitive Load Minimization:** Operations are wrapped in standardized scripts (`make`, `podman-*.sh`) to reduce syntax errors and context switching.

## 3. Architecture Layers

### 3.1. Container Layer (`Containerfile`)
The image construction follows a **Multi-Stage Build** pattern to ensure a minimal attack surface and maximum reproducibility.

*   **Stage 1: Go Builder (`golang:1.22`)**
    *   Compiles tools like `subfinder`, `nuclei`, `httpx`.
    *   Uses pinned versions in `Containerfile`.
*   **Stage 2: Rust Builder (`rust:slim`)**
    *   Compiles tools like `feroxbuster`, `rustscan`.
    *   Uses `cargo install --locked` for dependency stability.
*   **Stage 3: Runtime (`debian:12-slim`)**
    *   **No Compilers:** gcc/go/cargo are stripped.
    *   **Non-Root:** Runs as user `pentest` (UID 10001).
    *   **Tools:** Copies binaries from builders.
    *   **Scripts:** Python/NodeJS runtimes included only where strictly necessary.

### 3.2. Orchestration Layer (Scripts)
The host interfaces with the container via two primary entrypoints:

1.  **`podman-run.sh` (Batch Mode)**
    *   **Purpose:** Atomic execution of a single command against a target.
    *   **Behavior:** Creates a timestamped directory structure (`runs/YYYY-MM-DD_TARGET/`), mounts it, executes, and exits.
2.  **`podman-interactive.sh` (Exploration Mode)**
    *   **Purpose:** Manual investigation and debugging.
    *   **Behavior:** Mounts the entire `pentest/` tree, persists bash history to host, and drops the user into a shell.

### 3.3. Data Layer (`pentest/`)
The `pentest/` directory is the **Single Source of Truth** for operational data.

```text
pentest/
├── targets/               # Input Data
│   ├── targets.txt        # List of scope domains
│   └── scope.md           # Rules of Engagement / Context
└── runs/                  # Output Data (Immutable History)
    └── YYYY-MM-DD_target/
        ├── recon/         # Subdomains, DNS records
        ├── evidence/      # Screenshots, Raw HTTP logs
        ├── findings/      # Verified vulnerabilities
        ├── reports/       # Generated reports
        └── logs/          # Tool execution logs
```

## 4. Operational Workflow

### 4.1. Startup
1.  **Check Targets:** Validate `pentest/targets/scope.md`.
2.  **Build/Update:** Run `make build-image` to ensure the toolchain is current.

### 4.2. Execution Loop
*   **Recon:**
    ```bash
    make run TARGET=example.com CMD="subfinder -d example.com -o \$SCAN_RESULTS_DIR/recon/subs.txt"
    ```
*   **Scanning:**
    ```bash
    make run TARGET=example.com CMD="nuclei -l \$SCAN_RESULTS_DIR/recon/subs.txt -o \$SCAN_RESULTS_DIR/findings/nuclei.txt"
    ```
*   **Analysis:**
    Launch interactive mode to manually review results:
    ```bash
    ./podman-interactive.sh example.com
    ```

### 4.3. Shutdown
1.  **Commit Data:** Review `pentest/runs/` and commit valid findings if using a private report repo (exclude raw massive logs if necessary).
2.  **Clean:** `podman system prune` if disk space is tight.

## 5. System Invariants

*   **No Root:** The container process must never run as root.
*   **No Internet for Builds (Ideal):** (Currently allowed, but strictly pinned versions).
*   **Explicit Mounts:** Only `pentest/` is mounted. Host system is isolated.
*   **Structure Enforcement:** Tools should output to `$SCAN_RESULTS_DIR` (mapped via env var) to maintain organization.

## 6. Maintenance & optimization

*   **Updates:** To update a tool (e.g., Nuclei), edit the `ARG NUCLEI_VER` in `Containerfile` and run `make build-image`.
*   **Drift Detection:** Periodically check `ARCH.md` against the codebase. If the code deviates, either refactor the code or update the architecture if the deviation is a deliberate improvement.
