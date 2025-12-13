# Operations Manual: Cloudflare Security Toolkit

## 1. System Architecture

This toolkit adheres to the **"Golden Phat" Architecture**, prioritizing reproducibility, security, and strict data isolation. It is designed as a **stateless processing unit** (the container) operating on **persistent state** (the host filesystem).

### 1.1. The Container (The Tool)
-   **Build Strategy:** Source-Based Multi-Stage Build.
    -   **Stage 1 (Go):** Compiles Go-based tools (`httpx`, `nuclei`, etc.) from source.
    -   **Stage 2 (Rust):** Compiles Rust-based tools (`feroxbuster`, `rustscan`) from source via `cargo`.
    -   **Stage 3 (Runtime):** A minimal `debian:slim` image containing only the compiled binaries and essential runtime dependencies.
-   **Ephemeral Nature:** The container is designed to be disposable. It is always executed with the `--rm` flag, ensuring it is destroyed immediately after the session ends.
-   **Security Context:** Runs as a non-root user (`pentest`, UID 10001) to mitigate container breakout risks. Uses `tini` as an init process for proper signal handling.

### 1.2. The Host (The Vault)
-   **Source of Truth:** The local directory `pentest/` on the host machine acts as the single source of truth for all configuration and results.
-   **Volume Mounts:**
    -   **Data Mount:** Host `pentest/` ↔ Container `/work/pentest`. This bridge allows the container to write results directly to the host's encrypted filesystem.
    -   **History Mount:** Host `.container_bash_history` ↔ Container `~/.bash_history`. Preserves command history across ephemeral sessions (Interactive mode only).

---

## 2. Data Lifecycle & Persistence

Strict adherence to this model ensures compliance with data privacy regulations (e.g., GDPR) and client confidentiality agreements.

### 2.1. Where Data Lives
| Data Type | Location | Persistence | Description |
| :--- | :--- | :--- | :--- |
| **Scan Results** | Host: `pentest/runs/` | **Permanent** | Evidence, logs, and reports. Backed up by the user. |
| **Target Config** | Host: `pentest/targets/` | **Permanent** | Scope definitions and target lists. Versioned in Git. |
| **Temporary Files** | Container: `/tmp` | **Ephemeral** | Deleted instantly when the container exits. |
| **Tool Caches** | Container: `~/.cache` | **Ephemeral** | Deleted instantly when the container exits. |

### 2.2. Directory Structure
The system enforces a structured approach to every engagement via the runner scripts.

```text
pentest/
├── targets/              # Configuration (Git-tracked)
│   ├── targets.txt       # List of authorized targets
│   └── scope.md          # Legal scope definition
└── runs/                 # Results (Git-ignored)
    └── YYYY-MM-DD_target/
        ├── recon/        # Raw output (subdomains, ports)
        ├── evidence/     # Proofs (screenshots, headers)
        ├── findings/     # Human-written analysis
        └── logs/         # Tool execution logs
```

### 2.3. Git Hygiene
A strict `.gitignore` policy ensures that **no client data** is ever committed to the repository. The repository contains logic and configuration; the local filesystem contains intelligence.

---

## 3. Operational Workflows

### 3.1. Interactive Mode ("The Lab")
**Script:** `./podman-interactive.sh [target_identifier]`

Used for manual deep-dives, exploration, and complex command chaining.

*   **With Target:** `./podman-interactive.sh example.com`
    *   Automatically creates the `runs/YYYY-MM-DD_example.com` directory structure.
    *   Sets `$SCAN_RESULTS_DIR` and `$TARGET_ID` environment variables.
    *   Drops the user into a shell **inside** the result directory.
*   **Without Target:** `./podman-interactive.sh`
    *   Drops the user into the root `/work/pentest` directory.
    *   Useful for maintenance or cross-target analysis.

**Key Feature:** Command history is preserved on the host. You can recall complex one-liners from previous sessions even after the container has been rebuilt.

### 3.2. Automated Mode ("The Sniper")
**Script:** `./podman-run.sh <target_identifier> <command...>`

Used for CI/CD pipelines, cron jobs, or "fire-and-forget" tasks.

*   **Mechanism:**
    1.  Prepares the directory structure.
    2.  Spins up the container.
    3.  Executes the specific command provided.
    4.  Terminates the container.
*   **Example:**
    ```bash
    ./podman-run.sh example.com httpx -u https://example.com -o $SCAN_RESULTS_DIR/recon/http.txt
    ```

### 3.3. CI/CD Integration (GitHub Actions)
The container is CI-ready. To use it in a workflow:
1.  **Build:** `podman build -t cf-pentest .`
2.  **Execute:** Use `./podman-run.sh` to wrap tool execution, ensuring artifacts are stored in the correct path.
3.  **Artifacts:** Use the `actions/upload-artifact` step to save the contents of `pentest/runs/` generated during the build.

---

## 4. Compliance & Security

This architecture supports "Red Team" compliance requirements:

1.  **Forensic Integrity:** Using specific, pinned versions of tools (SHA-1 commits) ensures that findings are reproducible.
2.  **Clean Desk Policy:** Since the container is stateless and filesystem writes are tunnelled to the host, no sensitive data remains in container layers or temporary caches after the session closes.
3.  **Scope Enforcement:** The workflow encourages defining targets explicitly. The folder structure makes it obvious which data belongs to which engagement.

## 5. Troubleshooting

**Error: `requires at least 1 arg(s), only received 0`**
*   **Cause:** The container or a tool inside it was called without necessary arguments.
*   **Fix:** Ensure you are passing a valid command string to `podman-run.sh`.
    *   *Bad:* `./podman-run.sh example.com` (No command specified)
    *   *Good:* `./podman-run.sh example.com id`

**Permission Denied on Result Files**
*   **Cause:** The container runs as UID 10001 (`pentest`).
*   **Fix:** Podman usually handles user namespace mapping automatically on rootless setups (macOS/Linux). If issues persist, ensure your host user has permissions on the `pentest/` directory.

**Tool Not Found**
*   **Cause:** The tool might not be in the `$PATH` or was removed from the build.
*   **Fix:** Check `Containerfile` to see if the tool is installed. In interactive mode, type `alias` to see if there is a shortcut (e.g., `kr` for `kiterunner`).
