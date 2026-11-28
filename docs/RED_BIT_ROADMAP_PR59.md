# RED Bit – Integrations- und Entwicklungsplan (PR #59)

Stand: 28.11.2026. Ein gemeinsamer Integrationsbranch; kein Merge nach main vor grüner CI und dokumentierter Abnahme.

## Integration
- #54: Historie übernommen; aktueller Automix-UI-Test verwendet stabilere Accessibility-IDs statt alter Textlabels.
- #57 und #58: bereits in der Historie; native Suche und Mini-Player-Tests erhalten.
- #60: alle zehn Dateiveränderungen übernommen. XcodeGen behält die aktuellen RedBit-Target-Namen; bestehende Herkunftsvermerke bleiben erhalten.
- RED ID bleibt freiwillig und getrennt von Musik-Anmeldungen. Keine automatische Übertragung von Musikdaten. Herkunft/Lizenz des eigenen SDK vor Veröffentlichung prüfen.
- Such-UI-Test: nativen Return alternativ zum lokalisierten Tastaturbutton auslösen; Tastatur-Dismissal, Mini-Player-Geometrie und Öffnen des Vollplayers weiterhin zwingend prüfen.

## P0 – Stabilität und Auslieferung
- [ ] CI des integrierten Heads prüfen; Rust-Übergangstest gezielt reproduzieren und Ursache beheben, nicht deaktivieren. Älterer #60-Lauf meldete no handoff fired; neuerer Integrationsbranch enthält bereits verbesserte Drain-Diagnostik.
- [ ] iOS-XCUITest auf regulärem Suchweg, echte Wiedergabe, Netzwerkwechsel, Bluetooth, Hintergrund, Pause/Fortsetzen; keine Fixture als Audio-Nachweis ausgeben.
- [ ] macOS-Build, iPad-Layout, iOS-Archiv, Paketprüfung und signierte Geräteinstallation. Alte Bundle-ID beibehalten.
- [ ] RED ID: QR/Antrag, Owner-Freigabe, Widerruf, Keychain, Offline-Fehler und TLS auf echtem Server/Gerät prüfen.

## P1 – Audio und Wiedergabe
Vor Implementierung jeweils vorhandenen Code inventarisieren; nicht als fehlend oder fertig deklarieren.
- [ ] Audio-Steuerung, Automix, Equalizer, Lautstärkenormalisierung, Gapless.
- [ ] Stream-Recovery, Cache und Preloading mit Speicherbudget und erlaubten Quellen.
- [ ] Sleep Timer, Bluetooth-/Audio-Routen-Recovery, reproduzierbare Audio-Qualitätsmessungen.

## P2 – Native Oberfläche
- [ ] Liquid Glass, Cover Morph, native Suche/Tabbar, Mini-Player, geeignete Live Activities (keine System-Dynamic-Island-Nachbildung).
- [ ] Visualizer, 3D-Alben, modulare Startseite, Haptik, Widgets, Performance-Modus.
- [ ] VoiceOver, Dynamic Type, Reduce Motion/Transparency, Light/Dark, iPad/Mac separat abnehmen.

## P3 – Musikintelligenz
- [ ] RED DJ, Smart Playlists, natürliche Suche, Lyrics-Übersetzung (nur berechtigte Inhalte), Discovery.
- [ ] Duplikate, Hörstatistiken, Wrapped, Smart Queue, freiwillige Musikerkennung.
- [ ] Lokal bevorzugen; Netzwerk/KI-Funktionen opt-in, Datenschutz und Kosten transparent.

## P4 – RED-Ökosystem
- [ ] RED ID Pilot abnehmen; RED Sync, Server-Musikbibliothek, Vault, Connect.
- [ ] RED MCP mit eng begrenzten Werkzeugrechten, Bestätigung für destruktive Aktionen und Audit-Protokoll.
- [ ] RED Fit, RED Poly, RED ION, Backup: separate Freigaben, Konfliktlösung, Export und Wiederherstellung.
- [ ] Verschlüsselung und Schlüsselmodell mit RED Server abstimmen; keine Zero-Knowledge-Zusage ohne nachgewiesenes Konzept.

## Abnahme
Jeder Bereich bekommt Quellnachweis, Tests, SHA, Build/Plattform, Status und bekannte Grenzen. Nicht getestete Funktionen bleiben offen. Keine Freigabe allein anhand eines grünen Konfigurations- oder Fixture-Tests.

## 28.11.2026 – Umsetzung Audio-Watchdog

- Ausgabe-Watchdog getrennt vom Stream: 12 s ohne Positionsfortschritt bei nichtleerem Ring, maximal eine automatische Ausgabereparatur je Ladegeneration. Keine Ausgabereparatur während Pause, Buffering, Dolby oder Smart-Mix. Kein erneuter URL-Abruf für diesen Pfad.
- Reconnect nutzt das vorhandene Budget erst beim tatsächlichen Neu-Load; erschöpftes Budget pausiert mit gespeichertem Wiederanlaufpunkt.
- Diagnose ergänzt um Underruns, Rebuilds, Xruns, Sessionstatus und System-/Geräteunterbrechungsgründe.
- Policy-Regressionen für Wartezeit, Pausen, Fortschritt, leeren Puffer und begrenzte Reparatur. Keine Geräteabnahme behauptet.
- Weitere Roadmap-Bereiche bleiben offen; insbesondere native UI, Sync, MCP, RED DJ und IPA müssen separat abgenommen werden.

## Folgebranch: Audio-Kontinuität

Der Branch `feat/red-bit-audio-continuity-20261128` basiert auf PR #59 (bd15a0f); der laufende Gerätebau bleibt unberührt. Erster Umfang: natürliches Ende der lokalen Queue bei aktivem Autoplay wartet höchstens 20 Sekunden auf verspätete Empfehlungen. Auswahl-, Queue- und Kontokontext sowie Pause/Repeat/Party begrenzen den Wiederanlauf. Ohne Netzwerk oder Seed bleibt das normale Ende erhalten. Sieben neue Policy-Prüfungen in der bestehenden Queue-Suite; echte Wiedergabe und Gerätebau sind nicht bestätigt. Weitere Audio-, Design- und Ökosystem-Punkte bleiben offen.

### Cache und URL-Vorwärmung (Folge-PR)
- Abgebrochene Quellen nicht als wachsend oder fertig registrieren; ältere Abschlüsse dürfen neuere laufende Quellen nicht überschreiben.
- Offline-Liste blendet falsche Dateigrössen, ungültige Manifestversionen, unbekannte Codecs und Fehler-/Abbruchmarker aus; SHA-256 bleibt beim Öffnen verbindlich.
- URL-Vorwärmung an Auswahlgeneration und Netzpfad koppeln, keine Auflösung nach Task-Abbruch, nur noch kommende Queue-Einträge. Bestehendes Limit 1 (Mobilfunk) / 3 (WLAN) bleibt.
- Drei neue Download-/Cache-Gegenproben; vollständige Apple-CI und Geräteabnahme stehen aus.

### RED DJ – begrenzte Automix-Planung
- Eine erfolgreich vorbereitete Quelle wird bei einem späteren Planungs-/Enginefehler nicht mehr als unspielbar markiert. Sicherheitsüberblendung oder normaler EOS-Load bleibt möglich.
- Zusätzliche Planung startet/erneuert sich nur innerhalb eines Budgets von 12 Versuchen und 24 Sekunden, mit mindestens Fade + 8 Sekunden Vorlauf bei bekannter Länge. Bei unbekannter Länge maximal eine Runde. Prüfungen auch zwischen Analysephasen und vor Übergabe an die Engine. Bereits laufende native Analyse kann das Budget überschreiten; keine harte Unterbrechung versprochen.
- Neun neue Policy-Gegenproben; keine Änderung der eigentlichen DJ-Analysemodelle oder DSP-Effekte. Vollständige CI und Hörtest ausstehend.

### Schnellere IPA-Builds
- Messung PR #59: Kotlin 650 s, Rust 494 s; beide Framework-Misses trotz allgemeinem Actions-Cache.
- Separate quell-/toolchainbasierte Cache-Schlüssel, sofortiges Speichern erfolgreicher Frameworks, Cache-Diagnose und Zeiten in der Build-Zusammenfassung. Kein Parallelbau erzwungen (CPU/RAM-Konkurrenz noch nicht gemessen).
- Fixture-Prüfungen für reine Swift-Änderungen, unabhängige native Änderungen, lokale Buildkonfiguration und beschädigtes Archiv erweitert. Tatsächlicher macOS-Warmbau steht aus; keine neue IPA aus diesem Folge-PR gestartet.

### Energiesparbetrieb und Ausgabeschutz
- System-Stromsparmodus begrenzt spekulative URL-Auflösungen auf null und überspringt zusätzliche DJ-/Queue-Analyse; echte Next-Track-Vorbereitung und Sicherheitsüberblendung bleiben aktiv. Pause beendet URL- und Sequencing-Aufgaben, Fortsetzung startet sie bei Bedarf neu. Keine Änderung von Audioqualität oder gespeicherten Einstellungen.
- Offline-Sequencing betrachtet nur fertige Cachedateien. Pausierte, puffernde oder leere Auswahl setzt Watchdog-Beobachtung ohne wiederholte native Statusabfragen zurück; gestoppte geladene Quellen behalten Fehlerbehandlung.
- Output-Watchdog prüft Transportgeneration und Mix vor und nach Session-Aktivierung; bestätigter Reparaturfehler führt zu Pause statt stiller Wiedergabeanzeige.
- Sieben neue Policy-Prüfungen. Bereits laufende native Analyse kann noch auslaufen; Akkueinsparung und Audioverhalten müssen am Gerät gemessen werden.
