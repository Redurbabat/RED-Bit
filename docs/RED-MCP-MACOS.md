# RED Bit – lokaler MCP-Lesepilot (macOS)

Basis: PR #61, lokaler Werkzeugvertrag v1. Kein HTTP-Port, keine Cloud,
keine RED-ID-Token, kein automatischer Hintergrunddienst. Ein vertrauenswürdiger
lokaler MCP-Host startet einen eigenen stdio-Prozess. Kompatibilitätsziel ist
bewusst die MCP-Protokollrevision 2025-11-25 mit initialize/initialized,
tools/list und tools/call; kein vollständiger Konformitätsnachweis.

## Einrichtung und Grenzen

1. RED Bit aus dem Folgebranch installieren und **Status lesen** in RED Automation
   ausdrücklich freigeben. Apple-Systemauthentifizierung bleibt erforderlich.
2. In Apple Kurzbefehle selbst einen vertrauenswürdigen Kurzbefehl namens
   RED Bit Local anlegen: Datei als Eingabe → Text aus Eingabe → Wörterbuch aus
   Text → Werte tool und arguments lesen → Aktion RED Bit Werkzeug aufrufen
   mit beiden Werten befüllen → Text zurückgeben (Stoppen und ausgeben).
   Keine weitere Aktion und keine Weitergabe. Der Adapter installiert keinen
   Kurzbefehl. Apple kann weitere Bestätigung verlangen.
3. Den lokalen MCP-Host für einen Prozess konfigurieren, z. B. mit
   command = absoluter Pfad zu Python 3, args = [absoluter Pfad zu
   scripts/redbit-mcp/server.py, --shortcut, RED Bit Local].
   Nur für vertrauenswürdige lokale Hosts; nicht in einen Remote-Proxy hängen.
4. Erst tools/list, dann redbit_read_status mit {} und redbit_read_queue
   mit {} testen. Bei Widerruf oder fehlender App muss der Aufruf fehlschlagen.

Die Antwort wird auf die bekannten Status-/Queue-Felder begrenzt. Fremde Felder
und ungültige Werte werden nicht weitergegeben; Fehlertexte enthalten keine
Rohdaten. Nur zwei Lesewerkzeuge, keine Schreibbefehle. Keine automatische
Wiederholung nach Timeout. Der Host erhält die ausdrücklich freigegebenen
Status-/Queue-Daten und kann sie seinerseits verarbeiten.

Apple CLI: https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac
MCP-Protokoll: https://modelcontextprotocol.io/specification/2025-11-25

## Tests

`python3 -m unittest discover -s scripts/redbit-mcp -v`

Sechs lokale Protokoll-/Privacy-/Bridge-Tests (simuliertes shortcuts-Programm),
keine echte macOS-/iPhone-Geräteabnahme. Die tatsächliche App-Antwort, Apple-
Authentifizierung und der konkrete Host müssen noch gemeinsam erprobt werden.
Die macOS-Brücke ist kein iOS- oder Windows-Dienst und kein ChatGPT-Cloud-Connector.
Die RED-Server-Anbindung und serverseitige Gerätefreigaben bleiben offen.
