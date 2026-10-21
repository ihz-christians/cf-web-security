#!/usr/bin/env bash
#
# Interaktive Sitzung im Prüfcontainer starten
#
# Das Skript startet eine interaktive Shell im Container.
# 1. Das Verzeichnis pentest/ wird eingebunden.
# 2. Der Befehlsverlauf wird über .bash_history auf dem Host gespeichert.
# 3. Der Container wird nach Sitzungsende entfernt (--rm).
#
# Verwendung: ./podman-interactive.sh [zielkennung]
#
# Mit Zielkennung wird das zugehörige Tagesverzeichnis angelegt und verwendet.
# Ohne Zielkennung startet die Shell im Hauptverzeichnis pentest/.

set -euo pipefail

# --- Konfiguration ---
readonly IMAGE="${IMAGE:-cf-web-api-security:latest}"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PENTEST_DIR="${PROJECT_ROOT}/pentest"
readonly HISTORY_FILE="${PROJECT_ROOT}/.container_bash_history"

# --- Befehlsverlauf auf dem Host speichern ---
# Lokale Verlaufsdatei bei Bedarf anlegen.
if [[ ! -f "${HISTORY_FILE}" ]]; then
    touch "${HISTORY_FILE}"
fi

# --- Arbeitsverzeichnis bestimmen ---
# Prüfen, ob eine Zielkennung angegeben wurde.
TARGET_ID="${1:-}"
START_DIR="/work/pentest"
ENV_VARS=()

if [[ -n "${TARGET_ID}" ]]; then
    # Sitzung mit Zielkennung; Ergebnisverzeichnis vorbereiten.
    TIMESTAMP=$(date +'%Y-%m-%d')
    RUN_DIR_RELATIVE="runs/${TIMESTAMP}_${TARGET_ID}"
    RUN_DIR_ABSOLUTE="${PENTEST_DIR}/${RUN_DIR_RELATIVE}"

    echo "[+] Modus: Sitzung mit Zielkennung"
    echo "[+] Zielkennung: ${TARGET_ID}"
    echo "[+] Verzeichnis: ${RUN_DIR_RELATIVE}"

    # Standard-Unterverzeichnisse anlegen.
    if ! mkdir -p \
        "${RUN_DIR_ABSOLUTE}/recon" \
        "${RUN_DIR_ABSOLUTE}/evidence" \
        "${RUN_DIR_ABSOLUTE}/findings" \
        "${RUN_DIR_ABSOLUTE}/reports" \
        "${RUN_DIR_ABSOLUTE}/logs"; then
        echo "Fehler: Ergebnisverzeichnis konnte nicht angelegt werden." >&2
        exit 1
    fi

    # Umgebungsvariablen mit Containerpfaden setzen.
    ENV_VARS+=("-e" "SCAN_RESULTS_DIR=/work/pentest/${RUN_DIR_RELATIVE}")
    ENV_VARS+=("-e" "TARGET_ID=${TARGET_ID}")

    # Shell im Ergebnisverzeichnis starten.
    START_DIR="/work/pentest/${RUN_DIR_RELATIVE}"
else
    # Allgemeine Sitzung ohne Zielkennung.
    echo "[+] Modus: Allgemeine Sitzung"
    echo "[+] Verzeichnis: /work/pentest"
    echo "[!] Hinweis: Kein bestimmtes Ergebnisverzeichnis ausgewählt."
    ENV_VARS+=("-e" "SCAN_RESULTS_DIR=/work/pentest")
fi

# --- Container starten ---
echo "[+] Interaktive Shell wird gestartet..."
echo "---------------------------------------------------"
echo "Host-Pfad: ${PENTEST_DIR}"
echo "Container-Pfad: /work/pentest"
echo "---------------------------------------------------"

# Datenverzeichnis und Befehlsverlauf einbinden.
# Arbeitsverzeichnis festlegen und vorhandene Umgebungsvariablen übergeben.
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
