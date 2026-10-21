#!/usr/bin/env bash
#
# Dieses Skript bereitet die Ergebnisablage auf dem Host vor und führt
# anschließend den angegebenen Befehl im Container aus.
#
set -euo pipefail

# --- Konfiguration ---
# Standard-Image verwenden; die Umgebungsvariable IMAGE kann es überschreiben.
readonly IMAGE="${IMAGE:-cf-web-api-security:latest}"
# Absoluten Projektpfad für den Volume-Mount bestimmen.
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Verzeichnis mit den Prüfungsdaten festlegen.
readonly PENTEST_DIR="${PROJECT_ROOT}/pentest"

# --- Eingaben prüfen ---
# Zielkennung und auszuführender Befehl müssen angegeben sein.
if [[ $# -lt 2 ]]; then
  echo "Fehler: Ungültige Anzahl an Argumenten." >&2
  echo "Dieses Skript bereitet die Ergebnisablage vor und führt einen Befehl im Container aus." >&2
  echo "" >&2
  echo "Verwendung: $(basename "$0") <zielkennung> <befehl> [argumente...]" >&2
  echo "Beispiel:   $(basename "$0") example.com subfinder -d example.com -o \$SCAN_RESULTS_DIR/recon/subdomains.txt" >&2
  exit 1
fi

# --- Argumente verarbeiten ---
# Das erste Argument ist die Zielkennung.
readonly TARGET_ID="$1"
# Zielkennung entfernen; die übrigen Argumente bilden den auszuführenden Befehl.
shift
readonly COMMAND_TO_RUN=("$@")

# --- Ergebnisverzeichnis vorbereiten ---
# Tagesdatum und Verzeichnisname für Ziel und Prüflauf bestimmen.
readonly TIMESTAMP=$(date +'%Y-%m-%d')
readonly RUN_DIR_RELATIVE="runs/${TIMESTAMP}_${TARGET_ID}"
readonly RUN_DIR_ABSOLUTE="${PENTEST_DIR}/${RUN_DIR_RELATIVE}"
readonly CONTAINER_NAME="cf-web-api-security-${TIMESTAMP}-${TARGET_ID}"

echo "[+] Prüflauf für Zielkennung wird vorbereitet: ${TARGET_ID}"

# Standard-Unterverzeichnisse für diesen Prüflauf anlegen.
# Mehrere Aufrufe desselben Ziels am selben Tag verwenden dieselben Ordner.
if ! mkdir -p \
  "${RUN_DIR_ABSOLUTE}/recon" \
  "${RUN_DIR_ABSOLUTE}/evidence" \
  "${RUN_DIR_ABSOLUTE}/findings" \
  "${RUN_DIR_ABSOLUTE}/reports" \
  "${RUN_DIR_ABSOLUTE}/logs"; then
  echo "Fehler: Ergebnisverzeichnis konnte nicht angelegt werden: ${RUN_DIR_ABSOLUTE}." >&2
  exit 1
fi

echo "[+] Ergebnisse werden hier gespeichert: ${RUN_DIR_RELATIVE}"
echo "[+] Auszuführender Befehl: ${COMMAND_TO_RUN[*]}"
echo "---"

# --- Container starten ---
# Podman mit den vorgesehenen Mounts und zusätzlichen Einschränkungen starten.
# Alle Argumente nach der Zielkennung werden an den Container übergeben.
# Es wird nur 'pentest/' eingebunden (-v), das Arbeitsverzeichnis gesetzt (-w)
# und der Ergebnispfad über eine Umgebungsvariable übergeben (-e).
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
