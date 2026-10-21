# Betrieb und Nutzung

## Voraussetzungen

- Podman und GNU Make
- Git sowie eine Netzwerkverbindung, wenn die Wortlisten mit `make wordlists` geladen werden sollen
- Optional Docker, wenn das Image ohne die bereitgestellten Podman-Skripte genutzt wird

Die Befehle in diesem Handbuch setzen voraus, dass sie im Projektverzeichnis ausgeführt werden. Vor jedem aktiven Test müssen eine schriftliche Freigabe und ein konkreter Prüfbereich vorliegen. Die Datei [scope.md](../pentest/targets/scope.md) ist nur eine Vorlage und erteilt selbst keine Freigabe.

## Image bauen

```bash
make build
```

Der Build lädt Build-Abhängigkeiten und Werkzeuge aus externen Quellen. Nicht alle davon sind auf unveränderliche Versionen festgelegt; identische Build-Ergebnisse sind daher nicht garantiert.

Wortlisten können bei Bedarf separat geladen werden:

```bash
make wordlists
```

Sie werden unter `pentest/wordlists/` abgelegt und nicht mit Git versioniert.

## Interaktive Sitzung

Für eine Sitzung mit einer Zielkennung:

```bash
make interactive TARGET=example.com
```

Ohne Zielkennung:

```bash
make interactive
```

Mit Zielkennung legt das Skript ein Tagesverzeichnis unter `pentest/runs/` an und setzt `TARGET_ID` sowie `SCAN_RESULTS_DIR`. Ohne Zielkennung startet die Shell unter `/work/pentest`. Die Bash-History wird auf dem Host in `.container_bash_history` aufbewahrt. Sie kann Befehle oder vertrauliche Informationen enthalten und sollte entsprechend geschützt und bei Bedarf gelöscht werden.

## Einzelnen Befehl ausführen

```bash
make run TARGET=example.com CMD='httpx -u https://example.com'
```

Das Skript legt ein Verzeichnis `pentest/runs/JJJJ-MM-TT_<zielkennung>/` an, mountet `pentest/` und setzt `SCAN_RESULTS_DIR` und `TARGET_ID`. Verwende `"$SCAN_RESULTS_DIR"` in Befehlen für Ausgabepfade, zum Beispiel:

```bash
make run TARGET=example.com CMD='httpx -u https://example.com -o "$SCAN_RESULTS_DIR/recon/http.txt"'
```

`example.com` dient nur als Beispiel und ist keine Freigabe. Die Tagesverzeichnisse sind nicht pro Aufruf eindeutig; mehrere Läufe für dieselbe Zielkennung am selben Tag verwenden dieselbe Ablage. `podman-run.sh` startet Podman mit einer TTY-Option und ist deshalb nicht ohne Anpassung für alle nicht-interaktiven CI-Umgebungen geeignet.

## Ergebnisse und Datenhaltung

- Laufdaten werden bei Verwendung der Startskripte unter `pentest/runs/` auf dem Host gespeichert.
- `.gitignore` schließt diesen Ordner vom üblichen Git-Tracking aus. Vor einem Commit sollte trotzdem `git status` geprüft werden.
- Verschlüsselung, Zugriffskontrolle, Sicherung und Löschung richten sich nach der Host-Umgebung und sind nicht Teil des Containers.
- Über die Mounts gespeicherte Daten bleiben nach dem Ende des Containers bestehen. `--rm` entfernt den Container, nicht die Host-Ergebnisse.
- Prüfe Befunde manuell und dokumentiere nachvollziehbare Nachweise, ohne mehr personenbezogene oder vertrauliche Daten als nötig zu speichern.

## CI-Hinweis

Der vorhandene GitHub-Actions-Workflow baut das Image, prüft ausgewählte CLI-Aufrufe und erstellt bei Pushes auf `main` oder Tags ein Multi-Arch-Image. Er führt keine Zielscans aus und ist kein umfassender Funktionstest der Werkzeuge.

## Fehlerbehebung

### Fehlende Argumente

`podman-run.sh` benötigt eine Zielkennung und einen auszuführenden Befehl:

```bash
./podman-run.sh example.com httpx -u https://example.com
```

### Schreibfehler im Ergebnisordner

Der Container verwendet UID 10001. Ob Schreibzugriffe auf den gemounteten Ordner funktionieren, hängt auch von Podman, der Host-Plattform und der Dateifreigabe ab. Prüfe die Podman-Mount-Konfiguration und die Berechtigungen auf dem Host, statt Ergebnisse mit erweiterten Rechten auszuführen.

### Werkzeug nicht gefunden

Prüfe, ob das Werkzeug im [Containerfile](../Containerfile) installiert wird und ob das Image nach der Änderung neu gebaut wurde. `kr` ist ein symbolischer Link auf `kiterunner`.
