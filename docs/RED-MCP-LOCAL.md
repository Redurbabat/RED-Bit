# RED Bit – lokale Automatisierung als RED-MCP-Grundlage

## Verfügbar im Folge-PR #61

In Apple Kurzbefehle die Aktion **RED Bit Wiedergabestatus lesen** auswählen.
Die Aktion verlangt Systemauthentifizierung und gibt einen JSON-Text zurück.
Sie liest den aktuellen In-Memory-Zustand der App; sie startet keine Musik
und führt keine eigene Netzwerkanfrage durch. Bei einem Kaltstart kann die
Wiedergabesitzung noch nicht wiederhergestellt sein. Kein Echtzeit-Abonnement.

Beispiel (Fixture, kein echter Nutzerstatus):

```json
{"canNext":true,"canPrevious":false,"controlsLocked":false,"durationSeconds":240,"hasPlaybackError":false,"hasTrack":true,"positionSeconds":42,"state":"playing","version":1}
```

Felder: version=1, state=stopped/buffering/playing/paused, hasTrack,
optionale positionSeconds/durationSeconds (ganze Sekunden), canNext,
canPrevious, controlsLocked, hasPlaybackError. Ungültige Zeitwerte entfallen.
Party-Sperren werden in den Transportfähigkeiten berücksichtigt.
Keine Titel, Künstler, Konten, Stream-URLs, Dateipfade, Track-IDs, Tokens,
Historie oder freien Fehlertexte. Keine automatische Übertragung.

## Lokale Transportaktionen

Weitere authentifizierungspflichtige Kurzbefehle:
- RED Bit fortsetzen: Play nur bei pausierter oder gestoppter Auswahl.
- RED Bit pausieren: Pause ohne Start eines neuen Titels; wiederholte Pause bleibt Pause.
- RED Bit nächster Titel und RED Bit vorheriger Titel: normale Player-Navigation, nicht idempotent.
  Zurück kann den aktuellen Titel neu beginnen; Party-Sperren und verfügbare Ziele werden geprüft.

Die vier Aktionen liefern eine versionierte JSON-Quittung mit command,
decision (requested/unchanged/locked/unavailable) und begrenztem status.
`requested` bedeutet nur, dass der Auftrag an den Controller übergeben
wurde. Keine Garantie, dass asynchrones Laden oder Audioausgabe gelingt.
Bei leerer Auswahl startet die Aktion keine neue Queue.
Keine Remote-Befehle, kein Netzwerk-Listener, keine neue RED-ID-Berechtigung.

## Lokale Audio-Einstellungen

Drei weitere Kurzbefehle mit Systemauthentifizierung:
- Lautstärke einstellen: App-Regler 0–100 Prozent, keine Änderung der Systemlautstärke.
- Wiedergabeposition einstellen: Sekunden innerhalb der bekannten Dauer des geladenen Titels.
  Nur pausierte/spielende Auswahl; während Laden oder Automix-Überblendung abgelehnt.
- Automix einstellen: explizit an/aus, unveränderte Werte ohne erneute Einrichtung;
  Wechsel während laufender Überblendung abgelehnt.

Alle drei prüfen Party-Sperren. Nicht endliche oder ausserhalb der Grenzen liegende
Werte werden als `invalidValue` abgelehnt, nicht still korrigiert.
Quittung: version, command, decision (requested/unchanged/locked/unavailable/invalidValue),
status; bei Lautstärke bzw. Automix zusätzlich der entsprechende beobachtete App-Wert.
Ein angeforderter Seek oder Automix-Wechsel ist noch kein hörbarer Erfolgsnachweis.
Keine automatische Remote-Ausführung. Die bestehenden acht lokalen Aktionen
(Status, vier Transportaktionen, drei Audio-Einstellungen) sind erst nach Installation
der entsprechenden App-Version verfügbar.

## Noch nicht verfügbar

Dies ist **kein MCP-Server**. Der App Intent ist eine lokale, vom System
vermittelte Aktion. RED ID unterstützt aktuell nur identity:read; kein
vorhandenes Token darf als Erlaubnis für Musikdaten oder Steuerung gelten.

Vor einem echten RED-MCP-Adapter auf RED Server:
1. Separate, widerrufbare Einwilligung pro Gerät und Scope (Status / Transport).
2. Versionierte Tool-Schemas, authentifizierter Transport, Gerätezuordnung,
   Ablaufzeit, Schutz vor Wiederholung, Rate-Limit und redigierte Audit-Ereignisse.
3. Idempotente Play/Pause-Aktionen, Party- und Benutzerintent-Schutz; keine
   automatische Wiedergabe bei einer Statusabfrage.
4. Verbindliche Tests für unbefugte Zugriffe, Offline-Geräte, Widerruf und
   tatsächliche Wiedergabe. iOS-Hintergrundgrenzen respektieren.

Keine Listener, externe Endpunkte oder Freigaben wurden eingerichtet.
