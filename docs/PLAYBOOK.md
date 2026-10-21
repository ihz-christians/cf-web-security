# Leitfaden für autorisierte Sicherheitsprüfungen

## Ziel und Grenzen

Dieser Leitfaden beschreibt einen vorsichtigen, manuellen Ablauf für Prüfungen von Webanwendungen und APIs, einschließlich Anwendungen hinter einem CDN oder auf einer Edge-Plattform. Er ist kein Freibrief und keine Anleitung zum Umgehen von Schutzmaßnahmen.

Vor Beginn müssen die verantwortliche Organisation, die konkreten Systeme, der Zeitraum, erlaubte Prüfmethoden, zulässige Last und ein Kontakt für Störungen schriftlich bestätigt sein. Die Vorlage [Umfang und Freigabe](../pentest/targets/scope.md) muss vor einer realen Prüfung durch konkrete Angaben ersetzt werden. Gefundene oder technisch erreichbare Systeme gelten nicht automatisch als freigegeben.

## Ablauf

### 1. Auftrag und Umfang bestätigen

- Bestätige die schriftliche Freigabe durch eine Person, die zur Erteilung berechtigt ist.
- Erfasse exakt freigegebene Hostnamen, Anwendungen und API-Endpunkte sowie ausdrücklich ausgeschlossene Systeme.
- Kläre erlaubte Testkonten, Testdaten, Zeitfenster, Kontaktwege und Abbruchkriterien.
- Behandle Drittanbieter-, CDN- und Cloud-Infrastruktur nur dann als eingeschlossen, wenn die Freigabe und die geltenden Anbieterbedingungen dies zulassen.

### 2. Ausgangslage dokumentieren

- Halte Datum, Zielkennung, Prüfperson, Freigabeverweis und verwendete Werkzeugversionen fest.
- Erfasse zunächst nur die für den Auftrag erforderlichen öffentlich sichtbaren Informationen.
- Lege fest, wo Ergebnisse sicher gespeichert, wer darauf zugreifen darf und wann sie gelöscht werden.

### 3. Mit risikoarmen Prüfungen beginnen

- Prüfe Erreichbarkeit, TLS-Konfiguration, Weiterleitungen und sicherheitsrelevante HTTP-Header.
- Untersuche öffentliche Webinhalte und dokumentierte API-Oberflächen innerhalb des bestätigten Umfangs.
- Verwende nur niedrige, ausdrücklich vereinbarte Anfrageraten. Beginne nicht mit breit angelegter oder aggressiver Erkundung.
- Führe keine Last-, Verfügbarkeits-, Umgehungs- oder zerstörerischen Tests ohne gesonderte schriftliche Genehmigung durch.

### 4. Befunde manuell verifizieren

- Behandle automatisierte Treffer als Hinweise, nicht als bestätigte Schwachstellen.
- Verifiziere Auswirkungen mit möglichst wenigen und risikoarmen Anfragen.
- Greife nicht auf fremde Konten oder Daten zu und verändere oder lösche keine Produktivdaten.
- Stoppe die Prüfung bei unerwarteter Auswirkung, Schutzmaßnahme oder Unklarheit im Umfang und kontaktiere die vereinbarte Ansprechperson.

### 5. Ergebnisse berichten

Ein nachvollziehbarer Bericht beschreibt je Befund:

- betroffene, freigegebene Komponente;
- beobachtetes Verhalten und reproduzierbare, risikoarme Nachweise;
- mögliche Auswirkung, Voraussetzungen und Einschränkungen;
- eine angemessene Abhilfe und den Verifikationsstatus.

Unbestätigte Vermutungen sind als solche zu kennzeichnen. Entferne unnötige personenbezogene Daten, Geheimnisse und Rohdaten aus dem Bericht.

## Werkzeuggruppen

Das Image enthält Werkzeuge zur Erkundung, Prüfung von Web- und API-Oberflächen, Analyse von Quellcode und Abhängigkeiten sowie zur Untersuchung von Netzwerk- und Protokollkonfigurationen. Welche Werkzeuge geeignet sind, hängt vom Auftrag ab. Ein enthaltenes Werkzeug ist weder automatisch für jeden Einsatz freigegeben noch durch die Installation sicher konfiguriert.

## Mindest-Checkliste

- [ ] Schriftliche Freigabe und aktueller, konkreter Prüfbereich geprüft
- [ ] Testzeitraum, Kontakt und Abbruchbedingungen vereinbart
- [ ] Zielsysteme und Testkonten eindeutig zugeordnet
- [ ] Anfrageraten und zulässige Methoden festgelegt
- [ ] Ablage und Schutz der Ergebnisse organisiert
- [ ] Treffer manuell geprüft und Einschränkungen dokumentiert
- [ ] Ergebnisse fristgerecht und datensparsam übergeben
