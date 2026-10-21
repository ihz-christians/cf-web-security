# Architektur

## Zweck

Dieses Repository stellt eine containerisierte Werkzeugumgebung für autorisierte Prüfungen von Webanwendungen und APIs bereit. Die Architektur trennt den Build der Werkzeuge, ihre Laufzeit und die auf dem Host gespeicherten Ergebnisse. Sie bietet dafür eine nachvollziehbare Ausgangsbasis, ist aber keine zertifizierte oder vollständig gehärtete Sicherheitsplattform.

## Grundsätze

1. **Getrennte Build- und Laufzeitumgebung:** Go- und Rust-Werkzeuge werden in vorherigen Stufen des mehrstufigen Builds installiert. Das endgültige Laufzeit-Image basiert auf Debian 12 und enthält die vorgesehenen Werkzeuge und Laufzeitabhängigkeiten.
2. **Nicht privilegierter Container-Benutzer:** Das Image setzt `pentest` (UID 10001) als Benutzer. Die Podman-Startskripte verwerfen zusätzlich Linux-Capabilities und setzen `no-new-privileges`.
3. **Ergebnisse auf dem Host:** Die Startskripte mounten `pentest/` nach `/work/pentest`; Ergebnisse bleiben dadurch nach dem Ende des mit `--rm` gestarteten Containers auf dem Host erhalten.
4. **Bedienung über Skripte:** `make`, `podman-run.sh` und `podman-interactive.sh` vereinheitlichen wiederkehrende Build- und Startparameter.

## Komponenten

### Image-Build

Das [Containerfile](../Containerfile) verwendet drei Stufen:

- **Go-Build-Stufe:** installiert Go 1.22.3 und baut mehrere Go-Werkzeuge. Die meisten Werkzeugversionen sind als Build-Argumente festgelegt; `gf` und `qsreplace` werden derzeit mit `@latest` installiert.
- **Rust-Build-Stufe:** baut `feroxbuster` und `rustscan`. `feroxbuster` wird mit `--locked` installiert; nicht alle Build-Abhängigkeiten des Projekts sind fest versioniert.
- **Laufzeit-Stufe:** basiert auf `debian:12-slim`, erstellt den Benutzer `pentest` und übernimmt die gebauten Werkzeuge. Weitere Pakete und Skripte werden während des Builds installiert.

Damit sind weder der gesamte Build noch sämtliche Abhängigkeiten vollständig reproduzierbar: Unter anderem sind Betriebssystempakete, einige Python- und Node-Abhängigkeiten sowie mehrere geklonte Repositories nicht durchgängig auf unveränderliche Versionen oder Prüfsummen festgelegt.

### Startskripte

- `podman-run.sh <zielkennung> <befehl ...>` legt `pentest/runs/JJJJ-MM-TT_<zielkennung>/` mit Unterordnern für Erkundung, Nachweise, Befunde, Berichte und Protokolle an. Es startet den Container mit `--rm`, einem Mount von `pentest/`, `--cap-drop=ALL` und `no-new-privileges`.
- `podman-interactive.sh [zielkennung]` startet eine interaktive Shell. Mit Zielkennung verwendet die Shell das entsprechende Tagesverzeichnis; ohne Zielkennung startet sie unter `/work/pentest`. Die Bash-History wird in `.container_bash_history` im Projektverzeichnis auf dem Host gespeichert.

Die Verzeichnisse werden nur nach Datum und Zielkennung benannt. Wiederholte Aufrufe für dasselbe Ziel am selben Tag teilen sich daher ein Verzeichnis. Die Skripte lesen die Datei `targets.txt` nicht aus und erzwingen keinen Prüfbereich; die Freigabe und Zielprüfung bleiben Aufgabe der ausführenden Person.

### GitHub Actions

Der Workflow baut ein lokales Image, führt einen Smoke Test mit ausgewählten Versions- und Hilfeaufrufen aus und erstellt bei Pushes auf `main` oder Tags ein Multi-Arch-Image. Der Smoke Test ist kein vollständiger Funktionstest und überprüft nicht alle Sicherheitsparameter zur Laufzeit.

## Datenfluss

```text
Host: pentest/  <->  Container: /work/pentest
Host: .container_bash_history  <->  Container: /home/pentest/.bash_history
```

`pentest/runs/` ist in `.gitignore` aufgeführt. Das verhindert das übliche Git-Tracking dieser Ergebnisse, ersetzt aber weder eine Zugriffskontrolle noch Verschlüsselung oder eine geregelte Löschung auf dem Host. Der Container wird mit `--rm` entfernt; dies löscht nicht die über Mounts auf dem Host gespeicherten Daten.

## Bekannte Grenzen

- `--cap-drop=ALL` und `no-new-privileges` werden von den bereitgestellten Podman-Skripten gesetzt, nicht pauschal von jedem möglichen Aufruf des Images.
- Der Container läuft nicht mit einem erzwungenen schreibgeschützten Dateisystem.
- Zielvorgaben in `scope.md` und `targets.txt` werden nicht technisch validiert oder erzwungen.
- Abhängigkeiten und Versionsangaben sind nicht vollständig reproduzierbar festgelegt.
- Aufbewahrung, Verschlüsselung und Zugriff auf Ergebnisse müssen außerhalb des Containers geregelt werden.

## Anpassung und Pflege

Werkzeugversionen und Installationsschritte sind im [Containerfile](../Containerfile) definiert. Änderungen sollten mit einem Image-Build und dem verfügbaren CI-Smoke-Test geprüft werden. Die Dokumentation sollte bei Änderungen an Startskripten, Mounts oder Build-Stufen mitangepasst werden.
