# RED ID – Pilot (Apple)

Local Swift package originally copied from Redion PR #257 commit
9646b183a43451400518c2fe4c17c6208aea3b9a. No moving remote package dependency.
Settings → Account & Integrations → RED Home Server. Set the private HTTPS
origin, create the QR/public JSON request, approve in RED ION and claim.
Tokens use the package's device-only Keychain. No automatic data transfer.
The existing music account is independent. Test on a real iPhone/macOS
with trusted HTTPS and an approved private server before release.
Android and RED Share integration are not part of this pilot.

## Separate RED-Bit-Lesefreigabe (Server-Pilot)

Die native Erweiterung fragt auf ausdrücklichen Tastendruck ausschließlich
GET /red-bit/v1/permission beim gespeicherten privaten HTTPS-Server ab.
Serverbasis: Redion `cc1173578c18d97ec4d3a39d9c32031537c58be3`,
Branch `feat/red-bit-server-permissions-20261128`. Der Server-Pilot muss
separat aktiviert und die betreffende RED-ID-v2-Sitzung vom Owner freigegeben
werden. Der vorhandene Keychain-/Refresh-Pfad bleibt erhalten; kein Token
wird an die UI oder den MCP-Host ausgegeben. Redirects bleiben gesperrt.
Nur Scope, Ablaufzeit und remoteAvailable:false werden validiert; unbekannte
Felder, falsche App, abgelaufene oder zu lange Gültigkeit und Remote-Flags
werden abgelehnt. 60 Sekunden Toleranz für Uhrabweichung zusätzlich zur
Server-Maximaldauer von 3600 Sekunden, niemals über das Sitzungsende hinaus.
Keine automatische Wiederholung bei 401/403/404. Kein Musikupload, kein
neuer Scope im Identitätstoken, keine Server-Aktionsausführung. Die Anzeige
ist eine Momentaufnahme, keine Autorisierung für künftige Aufträge.
Echte private HTTPS-/Apple-Geräteabnahme steht aus.

## Einmalige Statusantwort (opt-in)

Serverbasis Redion `aff6e1eeb52b6ab026f639784493b66813bfdd3e`. Der Owner muss den Statusauftrag erzeugen und die beiden Server-Pilotflags aktivieren. In RED Bit ist die lokale Statusfreigabe erforderlich. Unter RED Home Server → Server-Statusauftrag bestätigt der Nutzer jeden einzelnen Vorgang. Erst dann holt der SDK einen Auftrag ab, akzeptiert ausschliesslich redbit_read_status und prüft ID, Ablauf und exakte Felder. Die App liest nur die bestehende Statusprojektion nach erneuter lokaler Freigabeprüfung. POST read-complete erhält nur ID und begrenzten Status. Keine Musiksteuerung, kein Hintergrund-Polling, kein Retry. Beim Verlassen des Bildschirms oder der aktiven Szene wird die Task abgebrochen; ein bereits gesendeter Request kann trotzdem angekommen sein. Keine Statusdaten in Logs. Der SDK prüft die Serverquittung. Echte Geräte-/HTTPS-Abnahme bleibt offen.
