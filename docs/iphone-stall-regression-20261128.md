# iPhone-Befund 28.11.2026 – Titelende und Diagnose

Version 1.0.4 (13), Revision bd15a0fee37a; 390 Messpunkte, 14/33 Prüfbereiche bestanden, 19 unbeobachtet, Bericht unterbrochen. Ab Sekunde 366 steht der Fortschritt bei 373,449 s von 373,461 s bis Sekunde 405. Playing bleibt wahr, Buffering falsch. Automix war aus, kein Übergang/Modellplan belegt. Keine Originalberichte, Titel oder personenbezogenen Daten im Repository.

## Änderungen und Prüfkriterien

- 10 s durchgehender Stillstand wird in der Fortschrittsprüfung als Fehler protokolliert; spätere erfolgreiche Messungen löschen ihn nicht.
- Nach 12 s und nur bei praktisch erreichtem Ende, leerem Puffer und belegbar vollständiger lokaler Quelle wird der gemeinsame EOS-Pfad verwendet. Decoderfehler haben Vorrang.
- Nach 24 s ohne Fortschritt erfolgt eine begrenzte Quellenreparatur oder sichtbare Pause mit Wiederanlaufpunkt. Der vorhandene Ausgabewatchdog bleibt aktiv.
- Bericht enthält Puffer, Underruns, Rebuilds, Xruns und Stillstandszeit. Beobachtungsfenster wird bei Pause/Puffern/Wechsel/Seek/Ausführungslücke zurückgesetzt.
- 60 Minuten passive Beobachtung und bis zu 3600 Messpunkte; iOS-Suspendierung bleibt eine Einschränkung.
- Drei zusätzliche Prüfbereiche erfassen nur neu gemeldete Modell-Planquellen getrennt von Dateiintegrität und Runtime-Status. Die Planmeldung allein ist kein unabhängiger Inferenznachweis. AutoMix mit zwei Titeln, tatsächlichem Übergang und Planquelle ([beat:coreml], [beat:rten], [vocals:open_unmix]) getrennt prüfen.

## Abnahme

Reine Swift-Regression: scripts/test-playback-progress.swift. Zusätzlich bestehende Native-End-, Repeat-, Autoplay-, Simulator- und Stream-Recovery-Checks ausführen. Auf echtem iPhone 60 Minuten mit mehreren Titeln, AutoMix aus/ein, Repeat aus/ein, gesperrtem Bildschirm, Netzwechsel und Bluetooth prüfen. Export muss Fehler bei Stillstand zeigen und darf unverwendete Funktionen nicht als bestanden ausgeben. Der native Grund für die fehlende EOS-Meldung ist mit den bisherigen Daten nicht bewiesen; die Hardware-Abnahme steht aus.

## Native Nacharbeit

Decoderfehler bleiben bis zum Abschluss der Stimme erhalten, auch bei Bit-Perfect. Ohne aktive Überblendung wird bei Decoderfehler nicht zum vorbereiteten Titel gesprungen. Nach belegbar leerer Ausgabe meldet der Mixer den tatsächlichen Endstand ohne erneuten Abzug der DSP-Latenz und genau ein Ende. Neue Rust-Regressionen decken Restpuffer, doppelten Abschluss und fehlerhafte Decoder ab. Der Livetest-Monitor läuft nun auch in der Simulator-CI. Für den ausdrücklich angeforderten IPA-Test wurde ein auf diesen Branch und einen Commitmarker beschränkter Opt-in unter dem bestehenden globalen Auto-Build-Schalter ergänzt; keine Signierung oder Veröffentlichung.
