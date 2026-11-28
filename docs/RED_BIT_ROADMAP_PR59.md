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
