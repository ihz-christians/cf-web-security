# Containerisierte Umgebung für Web- und API-Sicherheitstests

[![Container-CI](https://github.com/ihz-christians/cf-web-security/actions/workflows/container.yml/badge.svg)](https://github.com/ihz-christians/cf-web-security/actions/workflows/container.yml)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue.svg)](LICENSE)
[![Plattform: Podman / Docker](https://img.shields.io/badge/Plattform-Podman%20%7C%20Docker-orange.svg)]()

Dieses Repository enthält eine containerisierte Werkzeugumgebung für autorisierte Prüfungen von Webanwendungen und APIs. Der Schwerpunkt liegt auf einem nachvollziehbaren Image-Build, einer getrennten Ablage von Scan-Ergebnissen und einer dokumentierten, vorsichtigen Arbeitsweise. Die enthaltenen Werkzeuge unterstützen Prüfungen; sie ersetzen weder eine konkrete Testfreigabe noch die fachliche Bewertung von Ergebnissen.

## Projektüberblick

Das Projekt zeigt die praktische Umsetzung folgender Punkte:

- **Container-Build:** Go- und Rust-Werkzeuge werden in mehrstufigen Builds vorbereitet. Die Laufzeit basiert auf Debian 12 und verwendet den Benutzer `pentest` mit UID 10001.
- **Begrenzte Podman-Ausführung:** Die bereitgestellten Startskripte verwerfen Linux-Capabilities und setzen `no-new-privileges`. Das ist eine zusätzliche Begrenzung, aber keine Garantie gegen alle Container- oder Host-Risiken.
- **Getrennte Ergebnisablage:** Die Skripte legen Ergebnisse unter `pentest/runs/` auf dem Host ab. Diese Daten werden durch `.gitignore` vom Git-Tracking ausgeschlossen; Verschlüsselung oder Zugriffsschutz des Host-Dateisystems werden dadurch nicht eingerichtet.
- **Automatisierte Prüfung:** GitHub Actions baut das Image, prüft ausgewählte Kommandozeilenwerkzeuge aufrufbar und erstellt bei Pushes auf `main` oder Tags ein Multi-Arch-Image für `amd64` und `arm64`. Der Smoke Test ist kein vollständiger Funktionstest der Werkzeuge.
- **Dokumentierte Arbeitsweise:** Die Dokumentation beschreibt Architektur, Betrieb, Prüfschritte und die Notwendigkeit einer ausdrücklich bestätigten Testfreigabe.

## Voraussetzungen

- Podman und GNU Make
- Für `make wordlists`: Git und eine Netzwerkverbindung
- Optional: Docker für die Nutzung des Images außerhalb der Podman-Skripte

## Schnellstart

```bash
make build
make interactive TARGET=example.com
```

`example.com` ist ein Beispieldomainname und keine Testfreigabe. Vor jeder Prüfung müssen Ziel, erlaubte Methoden und Grenzen schriftlich festgelegt und in [pentest/targets/scope.md](pentest/targets/scope.md) geprüft werden.

Für einen einzelnen Befehl:

```bash
make run TARGET=example.com CMD='httpx -u https://example.com'
```

Die Skripte erzeugen ein nach Datum und Ziel benanntes Verzeichnis unter `pentest/runs/`. Mehrere Aufrufe desselben Ziels am selben Tag verwenden dasselbe Verzeichnis. Das nicht-interaktive Ausführen über `podman-run.sh` ist wegen der aktivierten TTY-Option nicht für jede CI-Umgebung geeignet.

Weitere Informationen stehen im [Betriebshandbuch](docs/OPERATIONS.md).

## Enthaltene Werkzeuge

| Bereich | Beispiele | Typischer Zweck |
| --- | --- | --- |
| Erkundung und Erreichbarkeit | `subfinder`, `dnsx`, `httpx`, `gau` | Domain- und URL-bezogene Informationen zusammentragen |
| Webinhalte und Quellcode | `feroxbuster`, `semgrep`, `retire` | Inhalte auffinden sowie Quellcode und JavaScript-Abhängigkeiten prüfen |
| API und Eingabeparameter | `kiterunner` (`kr`), `arjun`, `ffuf` | API-Routen und Parameter in freigegebenen Prüfungen untersuchen |
| Sicherheitsprüfungen | `nuclei`, `dalfox`, `jwt_tool` | Hinweise auf bekannte Fehlkonfigurationen und Schwachstellen sammeln |
| Netzwerk und Protokolle | `rustscan`, `testssl.sh`, `h2csmuggler` | Netzwerkdienste und Protokollkonfigurationen untersuchen |
| Muster und Textsuche | `gf`, `qsreplace`, `ripgrep` | Text- und URL-Daten weiterverarbeiten |

Die Installation allein aktiviert keine sicheren Prüfprofile. Umfang, Intensität und Ziel müssen für jeden Einsatz separat festgelegt werden.

## Grenzen und Genauigkeit

- Einige Versionen sind im [Containerfile](Containerfile) festgelegt, andere Abhängigkeiten werden derzeit nicht auf eine feste Version begrenzt. Der Build ist daher nicht vollständig reproduzierbar.
- Die GitHub-Actions-Pipeline prüft Image-Build und grundlegende CLI-Aufrufe; sie belegt weder die korrekte Funktion jeder Option noch die Wirksamkeit der Isolation.
- Die Startskripte speichern die Ergebnisse lokal. Eine sichere Aufbewahrung, Verschlüsselung, Freigabe und Löschung der Daten muss auf dem Host organisiert werden.
- Die Dokumentation und Konfigurationsdateien sind Beispiele und Vorlagen. Sie ersetzen keine Rechtsberatung, keine verbindliche Freigabe und keine Vereinbarung mit einem Cloud- oder Hosting-Anbieter.

## Dokumentation

- [Architektur](docs/ARCH.md)
- [Betrieb und Nutzung](docs/OPERATIONS.md)
- [Prüfablauf](docs/PLAYBOOK.md)
- [Hinweise zu Cloudflare](docs/compliance/cloudflare.md)
- [Vorlage für Umfang und Freigabe](pentest/targets/scope.md)
- [Zielnotizen](pentest/targets/target-notes.md)

## Lizenz

Der Projektcode steht unter der MIT-Lizenz. Für die enthaltenen Drittanbieter-Werkzeuge gelten jeweils deren eigene Lizenzen und Nutzungsbedingungen.
