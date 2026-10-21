#!/usr/bin/env bash
#
# Golden Phat: Interactive Session Launcher
#
# This script starts a manual, interactive shell inside the security container.
# It ensures that:
# 1. All persistent data (targets, findings) is mounted correctly.
# 2. Command history is preserved between sessions (via .bash_history).
# 3. The container remains ephemeral (--rm) and clean.
#
# Usage: ./podman-interactive.sh [target_identifier]
#
# If a target_identifier is provided, a specific run directory is created and selected.
# If not, the shell starts in the main pentest directory for general tasks.

set -euo pipefail

# --- Configuration ---
readonly IMAGE="${IMAGE:-cf-web-api-security:latest}"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PENTEST_DIR="${PROJECT_ROOT}/pentest"
readonly HISTORY_FILE="${PROJECT_ROOT}/.container_bash_history"

# --- Setup Persistence ---
# Create a local history file if it doesn't exist.
# This ensures that your command history inside the container is saved
# to your host machine, so you don't lose it when the container exits.
if [[ ! -f "${HISTORY_FILE}" ]]; then
    touch "${HISTORY_FILE}"
fi

# --- Context Setup ---
# Check if a target argument was provided
TARGET_ID="${1:-}"
START_DIR="/work/pentest"
ENV_VARS=()

if [[ -n "${TARGET_ID}" ]]; then
    # Mode: Target-Scoped Session
    # Automatically prepare the environment for a specific target scan.
    TIMESTAMP=$(date +'%Y-%m-%d')
    RUN_DIR_RELATIVE="runs/${TIMESTAMP}_${TARGET_ID}"
    RUN_DIR_ABSOLUTE="${PENTEST_DIR}/${RUN_DIR_RELATIVE}"

    echo "[+] Mode: Target-Scoped Session"
    echo "[+] Target: ${TARGET_ID}"
    echo "[+] Context: ${RUN_DIR_RELATIVE}"

    # Enforce Architecture: Create the standard directory structure
    if ! mkdir -p \
        "${RUN_DIR_ABSOLUTE}/recon" \
        "${RUN_DIR_ABSOLUTE}/evidence" \
        "${RUN_DIR_ABSOLUTE}/findings" \
        "${RUN_DIR_ABSOLUTE}/reports" \
        "${RUN_DIR_ABSOLUTE}/logs"; then
        echo "Error: Failed to create results directory." >&2
        exit 1
    fi

    # Set environment variables for the container tools (Absolute path inside container)
    ENV_VARS+=("-e" "SCAN_RESULTS_DIR=/work/pentest/${RUN_DIR_RELATIVE}")
    ENV_VARS+=("-e" "TARGET_ID=${TARGET_ID}")

    # Start the shell directly inside the run directory for focus
    START_DIR="/work/pentest/${RUN_DIR_RELATIVE}"
else
    # Mode: General Exploration
    echo "[+] Mode: General Exploration Session"
    echo "[+] Context: Root (/work/pentest)"
    echo "[!] Note: No specific result directory selected."
    ENV_VARS+=("-e" "SCAN_RESULTS_DIR=/work/pentest")
fi

# --- Execution ---
echo "[+] Starting interactive shell..."
echo "---------------------------------------------------"
echo "Host Path: ${PENTEST_DIR}"
echo "Cont Path: /work/pentest"
echo "---------------------------------------------------"

# Execute Podman with all necessary mounts
# Mount the main data volume (Source of Truth)
# Mount bash history for persistence across sessions
# Set the working directory based on context
# Inject computed environment variables (if any)
exec podman run --rm -it \
    --name "cf-web-api-security-interactive-$(date +%s)" \
    --security-opt="no-new-privileges" \
    --cap-drop=ALL \
    -v "${PENTEST_DIR}:/work/pentest:Z" \
    -v "${HISTORY_FILE}:/home/pentest/.bash_history:Z" \
    -w "${START_DIR}" \
    "${ENV_VARS[@]}" \
    "${IMAGE}" \
    /bin/bash
