# Hinweise zu Prüfungen auf Cloudflare

## Zweck und Geltungsbereich

Dieses Dokument fasst organisatorische Hinweise für Sicherheitsprüfungen von Anwendungen zusammen, die Cloudflare-Dienste nutzen. Es ist keine Erklärung, dass ein bestimmter Test oder dieses Repository die Cloudflare-Regeln vollständig erfüllt. Es ist keine Rechtsberatung.

Vor jeder Prüfung sind die aktuellen Bedingungen und Vorgaben von Cloudflare sowie die Vereinbarungen mit dem Betreiber der Zielanwendung zu prüfen. Die jeweils gültigen Regeln können sich ändern.

**Referenz:** [Cloudflare: Scans and penetration testing](https://developers.cloudflare.com/fundamentals/reference/scans-penetration/)

## Vor Beginn

- Hole eine ausdrückliche schriftliche Genehmigung der berechtigten Eigentümer oder Betreiber ein.
- Bestätige, welche Anwendung, Hostnamen, APIs und Cloud-Dienste umfasst sind. Die Nutzung von Cloudflare durch ein Ziel bedeutet nicht automatisch, dass dessen Edge- oder sonstige Anbieter-Infrastruktur für aktive Tests freigegeben ist.
- Kläre erlaubte Prüfmethoden, Zeitraum, Anfrageraten, Kontakt für Störungen und Abbruchkriterien.
- Prüfe, ob zusätzliche Genehmigungen des Plattformanbieters erforderlich sind.

## Schonende Durchführung

- Beginne mit risikoarmen, begrenzten Prüfungen und verwende nur den schriftlich vereinbarten Umfang.
- Begrenze Anfragen und Umfang entsprechend der Freigabe. Die Startskripte dieses Repositories erzwingen keine globalen Ratenlimits.
- Führe keine Last- oder Verfügbarkeitstests, Umgehungsversuche oder destruktiven Tests ohne gesonderte ausdrückliche Genehmigung durch.
- Stelle die Prüfung bei unerwarteter Beeinträchtigung, Sperre oder unklarem Umfang ein und informiere die vereinbarte Kontaktperson.
- Verifiziere automatisierte Treffer manuell und mit möglichst geringer Auswirkung.

## Was das Repository technisch umsetzt

Die Podman-Skripte setzen `--cap-drop=ALL` und `no-new-privileges`, verwenden einen nicht privilegierten Container-Benutzer und mounten `pentest/` für die Ergebnisablage. Diese Maßnahmen begrenzen bestimmte Risiken, setzen aber weder die Freigabe noch den Prüfbereich oder die zulässige Anfragerate technisch durch.

Die Dokumentation behauptet daher nicht, dass:

- nur Ziele aus `targets.txt` erreichbar oder prüfbar sind;
- Werkzeuge automatisch ein vereinbartes Ratenlimit einhalten;
- alle enthaltenen Werkzeugoptionen nicht-destruktiv sind;
- Scan-Ergebnisse automatisch verschlüsselt, bereinigt oder gegen Zugriff geschützt werden;
- eine Prüfung allein durch die Konfiguration dieses Containers mit Anbieterbedingungen oder geltendem Recht übereinstimmt.

## Aufbewahrung und Meldung

Bewahre nur für den Auftrag erforderliche Nachweise auf, beschränke den Zugriff und halte die vereinbarte Löschfrist ein. Berichte mögliche Auswirkungen zeitnah an die vereinbarte Kontaktperson. Weitere Hinweise zum Ablauf stehen im [Prüfleitfaden](../PLAYBOOK.md) und in der [Vorlage für Umfang und Freigabe](../../pentest/targets/scope.md).
