# RED Bit – lokaler MCP-Pilot (macOS)

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
Rohdaten. Standardmässig nur zwei Lesewerkzeuge. Keine automatische
Wiederholung nach Timeout. Der Host erhält die ausdrücklich freigegebenen
Status-/Queue-Daten und kann sie seinerseits verarbeiten.

Apple CLI: https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac
MCP-Protokoll: https://modelcontextprotocol.io/specification/2025-11-25

## Optional: Play und Pause

Erst nach einem erfolgreichen Lesetest und ausdrücklicher Entscheidung des
Nutzers kann der lokale Host mit dem zusätzlichen Startargument
`--allow-play-pause` neu gestartet werden. In RED Bit muss zusätzlich
die lokale Transportfreigabe aktiv sein. Dann erscheinen `redbit_play`
und `redbit_pause` mit jeweils `{}` als Eingabe. Weitere Werkzeuge
benötigen separate Host-Startargumente. Der Standardmodus bleibt lesend.

`requested` bestätigt nur den Auftrag, `unchanged` den bereits vorliegenden
Zustand. `locked` und `unavailable` sind Werkzeugfehler. Bei Timeout oder
ungültiger Quittung ist der Ausgang unbekannt; erst Status lesen, nicht
automatisch erneut ausführen. Das Deaktivieren der App-Freigabe verhindert
weitere autorisierte Aufträge, auch wenn der Host noch gestartet ist.
Kein Remote-Proxy und keine automatische Aktivierung von Play/Pause.

## Optional: Navigation und Lautstärke

Unabhängige Host-Startargumente, standardmässig aus:
- `--allow-navigation`: `redbit_next`, `redbit_previous` (je `{}`)
  und `redbit_seek` (z. B. `{"seconds":12.5}`).
- `--allow-volume`: `redbit_set_volume` (z. B. `{"percent":40}`).
  Nur App-Lautstärke, nicht Systemlautstärke.

Auch hier muss die lokale Transportfreigabe in RED Bit aktiv sein. Parameter
werden vor dem Kurzbefehlsaufruf gegen den bestehenden Vertrag geprüft.
Keine zusätzlichen Felder, Strings als Zahlen oder nicht endliche Werte.
Seek-Dauer, Party-Sperren und Mix-Zustand prüft weiterhin die App.
Next/Previous und Seek sind bewusst nicht als idempotent annotiert:
ein erneuter Aufruf kann einen anderen Titel treffen. Keine Wiederholung
bei Timeout; die Quittung bestätigt keinen hörbaren Erfolg. Die vier
Audio-/Shuffle-Einstellungswerkzeuge bleiben im MCP-Adapter gesperrt.

## Tests

`python3 -m unittest discover -s scripts/redbit-mcp -v`

16 lokale Protokoll-/Privacy-/Bridge-Tests (simuliertes shortcuts-Programm),
keine echte macOS-/iPhone-Geräteabnahme. Die tatsächliche App-Antwort, Apple-
Authentifizierung und der konkrete Host müssen noch gemeinsam erprobt werden.
Die macOS-Brücke ist kein iOS- oder Windows-Dienst und kein ChatGPT-Cloud-Connector.
Die RED-Server-Anbindung und serverseitige Gerätefreigaben bleiben offen.
