#!/usr/bin/env bash
#
# Golden Phat: This script is the primary entrypoint for running scans.
# It prepares the host environment according to the project's architecture
# and then executes a specified command inside the container.
#
set -euo pipefail

# --- Configuration ---
# Use a default image name but allow overriding it via an environment variable.
readonly IMAGE="${IMAGE:-cf-web-api-security:latest}"
# Determine the absolute path to the project root directory for robust volume mounting.
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Define the authoritative path for all pentest-related data.
readonly PENTEST_DIR="${PROJECT_ROOT}/pentest"

# --- Input Validation ---
# Ensure both a target identifier and a command are provided.
if [[ $# -lt 2 ]]; then
  echo "Error: Invalid number of arguments." >&2
  echo "This script prepares the scan environment and then executes a command inside the container." >&2
  echo "" >&2
  echo "Usage:   $(basename "$0") <target_identifier> <command> [command_args...]" >&2
  echo "Example: $(basename "$0") example.com subfinder -d example.com -o \$SCAN_RESULTS_DIR/recon/subdomains.txt" >&2
  exit 1
fi

# --- Argument Handling ---
# The first argument is the unique identifier for the target.
readonly TARGET_ID="$1"
# Remove the target_id from the argument list. The rest becomes the command to execute.
shift
readonly COMMAND_TO_RUN=("$@")

# --- Prepare Scan Environment ---
# Generate a timestamp and the unique directory for this specific scan run.
readonly TIMESTAMP=$(date +'%Y-%m-%d')
readonly RUN_DIR_RELATIVE="runs/${TIMESTAMP}_${TARGET_ID}"
readonly RUN_DIR_ABSOLUTE="${PENTEST_DIR}/${RUN_DIR_RELATIVE}"
readonly CONTAINER_NAME="cf-web-api-security-${TIMESTAMP}-${TARGET_ID}"

echo "[+] Initializing scan run for target: ${TARGET_ID}"

# Create the structured, immutable directory for the current run.
# This enforces the auditable architecture defined in the README.
if ! mkdir -p \
  "${RUN_DIR_ABSOLUTE}/recon" \
  "${RUN_DIR_ABSOLUTE}/evidence" \
  "${RUN_DIR_ABSOLUTE}/findings" \
  "${RUN_DIR_ABSOLUTE}/reports" \
  "${RUN_DIR_ABSOLUTE}/logs"; then
  echo "Error: Failed to create results directory at ${RUN_DIR_ABSOLUTE}." >&2
  exit 1
fi

echo "[+] Results will be stored in: ${RUN_DIR_RELATIVE}"
echo "[+] Executing command: ${COMMAND_TO_RUN[*]}"
echo "---"

# --- Execute Container ---
# Launch the Podman container with enhanced security and proper volume mounts.
# All arguments following the target_id are passed directly to the container's entrypoint.
# Note: Mount only the 'pentest' directory for isolation (-v).
#       Set working directory (-w).
#       Pass relative results path via env var (-e).
podman run --rm -it \
  --name "${CONTAINER_NAME}" \
  --security-opt="no-new-privileges" \
  --cap-drop=ALL \
  -v "${PENTEST_DIR}:/work/pentest:Z" \
  -w "/work/pentest" \
  -e "SCAN_RESULTS_DIR=/work/pentest/${RUN_DIR_RELATIVE}" \
  -e "TARGET_ID=${TARGET_ID}" \
  "${IMAGE}" \
  "${COMMAND_TO_RUN[@]}"
