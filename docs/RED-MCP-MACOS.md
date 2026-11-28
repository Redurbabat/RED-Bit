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
Audio-/Shuffle-Einstellungswerkzeuge benötigen das eigene Opt-in unten.

## Optional: Automix, Equalizer, Qualität und Shuffle

Mit dem zusätzlichen Host-Startargument `--allow-preferences` werden
vier weitere lokale MCP-Werkzeuge eingeblendet:
- `redbit_set_automix`, `redbit_set_equalizer` und
  `redbit_set_shuffle` verwenden `{"enabled":true}` bzw. `false`.
- `redbit_set_quality` verwendet z. B.
  `{"quality":"HIGH","metered":true}`. Zulässig sind nur LOW, MEDIUM,
  HIGH und LOSSLESS. `metered` wählt das Profil für mobile Daten.

**Standardmässig ist dieser Zugriff aus.** Zusätzlich muss in RED Bit
„Audio- und Zufallseinstellungen ändern“ ausdrücklich freigegeben sein;
die Statusfreigabe ist Voraussetzung. Nur der lokale, vertrauenswürdige
Mac-MCP-Host kann die Flags setzen; es gibt weiterhin keinen Remote-Zugang.
Einstellungen werden über die vorhandenen App-Aktionen geändert. Der Adapter
prüft exakte Parameter und Quittungsfelder; unerwartete Daten werden nicht
an den Host weitergegeben. `requested` bestätigt lediglich einen Auftrag,
keine erfolgreiche Wiedergabe. Bei unklarem Ausgang erfolgt kein Retry.

## Aufrufschutz (lokale MCP-Sitzung)

Version 0.5 reserviert die ID jedes gültigen, tatsächlich zugelassenen
Werkzeugaufrufs vor dem Kurzbefehlsstart. Dieselbe ID wird in diesem Prozess
auch nach einem Fehler oder Timeout nicht erneut ausgeführt. Maximal 4096
zugelassene Werkzeugaufrufe pro Prozess; danach muss der Host neu verbinden.
Es gibt keine Löschung alter IDs innerhalb der Sitzung. In einem gleitenden
60-Sekunden-Fenster sind höchstens 60 Aufrufe insgesamt und 20 Schreibaufrufe
erlaubt. Reads bleiben bei ausgeschöpftem Schreiblimit möglich, solange das
Gesamtlimit frei ist. Abgewiesene Aufrufe erreichen die App nicht.
IDs sind begrenzt; Argumente und Antworten werden nicht im Guard gespeichert.
Der Host muss pro Anfrage eine neue ID verwenden. Ein neuer Prozess hat
einen neuen Guard: das ist kein dauerhafter geräteübergreifender Replay-Schutz,
keine Server-Autorisierung und keine Garantie, dass ein Timeout den bereits
gestarteten Apple-Kurzbefehl beendet hat. Nicht automatisch mit neuer ID
wiederholen, sondern Status prüfen und bewusst entscheiden.

## Tests

`python3 -m unittest discover -s scripts/redbit-mcp -v`

31 lokale Protokoll-/Privacy-/Bridge-Tests (simuliertes shortcuts-Programm),
keine echte macOS-/iPhone-Geräteabnahme. Die tatsächliche App-Antwort, Apple-
Authentifizierung und der konkrete Host müssen noch gemeinsam erprobt werden.
Die macOS-Brücke ist kein iOS- oder Windows-Dienst und kein ChatGPT-Cloud-Connector.
Die RED-Server-Anbindung und serverseitige Gerätefreigaben bleiben offen.
