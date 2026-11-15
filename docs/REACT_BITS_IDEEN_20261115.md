# React Bits als Ideenquelle für RED Bit · 15. November 2026

## Umfang und Ergebnis

Öffentlichen [Komponentenkatalog](https://reactbits.dev/get-started/index) über alle fünf Bereiche gelesen: Text, Animationen, Komponenten, Hintergründe und Mikrointeraktionen. Für die engere Auswahl die verlinkten Einzelseiten geprüft. Das ist eine Konzeptrecherche anhand der veröffentlichten Beschreibungen; nicht jede interaktive Demo wurde im Browser abgespielt, kein Pro-Zugang geprüft und keine Performance auf iPhone gemessen.

Die folgenden Vorschläge sind eigene Übertragungen auf unsere native Musik-App. React Bits liefert Web-Komponenten, RED Bit bleibt SwiftUI mit vorhandener Wiedergabesitzung. Keine WebView und kein neues React-Paket eingebaut. Bereits vorhandene Galaxie, Plattenregal, Sternbild und Coverfächer erweitern, statt parallele Ansichten zu schaffen.

## Zuerst verbessern

Vor neuen Effekten: Überschneidung von Mix-Kapsel und Lautstärke lösen, deutsche Statusangaben vervollständigen und die schwachen Kontraste im Sternbild korrigieren. [Gerätebefunde und Umsetzung](PR59_NATIVE_MOTION_20261115.md). Der neue detaillierte Vogel ist als großes Icon geeignet, verliert aber als winziger Toolbar-Marker viele Federdetails. Deshalb eigene transparente, vereinfachte Silhouette; echte 28-pt-Abnahme noch offen.

## Engere Auswahl – eigene Umsetzungsvorschläge

| Priorität | Referenz | RED-Bit-Nutzerziel und Ablauf | Vorhandener Einstieg / native Umsetzung |
|---|---|---|---|
| 1 | [Orbit Images](https://reactbits.dev/animations/orbit-images), [Galaxy](https://reactbits.dev/backgrounds/galaxy) | In der Musikgalaxie durch echte Alben drehen; Auswahl bleibt groß und lesbar. Nur wenige Hintergrundleuchten, keine dauerhafte Kamerafahrt. | `MusicCollectionShowcase` / `MoodGalaxy`: echte ShelfCards, bestehende Drag-Auswahl, Canvas für sparsame Sterne. |
| 1 | [Circular Carousel](https://reactbits.dev/components/circular-carousel) | Plattenregal: eine Platte klar im Vordergrund, Wischen rastet ein; Plattenwechsel endet stabil und ist sofort umkehrbar. | `.records` in `MusicCollectionShowcase`: Hülle, Einziehen, Auswahlwechsel, Herausgleiten mit derselben Identität. |
| 1 | [True Focus](https://reactbits.dev/text-animations/true-focus) | Sternbild: aktuelles Wort klar, vergangene Wörter ruhiger; Text bleibt auch während Übergängen lesbar. Nicht die ganze Zeile stark verschwimmen lassen. | `ConstellationStage`: echte Wort-/Zeiten aus Lyrics; kein eigener Timer als vermeintlicher Audiofortschritt. |
| 1 | [Comet Dial](https://reactbits.dev/micro/comet-dial) | Bestehender Bogen-Scrubber: kleiner Lichtschweif beim aktiven Ziehen, genaue Zielzeit, Loslassen sucht wirklich. | `ArcPlaybackDeck`, Seek-Aktion und vorhandene Geometrie; Licht nur bei Eingabe, keine zweite Transportsteuerung. |
| 2 | [Bounce Cards](https://reactbits.dev/components/bounce-cards) | Playlist-Vorschau: drei echte Cover auffächern, Auswahl öffnet den Titel/Playlistweg; schließt ohne Wiedergabeverlust. | Vorhandenen `PlaylistCoverFan` erweitern; keine doppelte Playlist-Auswahl. |
| 2 | [Flip Card](https://reactbits.dev/micro/flip-card) | Albumkarte umdrehen: Vorderseite Artwork, Rückseite Titel und Aktionen. Kein automatisches Starten durch bloßes Umdrehen. | Eigene Album-Vorschau mit stabiler Navigation und klarer Schaltfläche „Details“. |
| 2 | [Pulse Heart](https://reactbits.dev/micro/pulse-heart) | Gefällt-mir-Aktion bekommt eine kurze Bestätigung erst nach erfolgreichem Speichern; bei Fehler verständliche Rückmeldung. | Bestehende Like-Aktion, native Symbolanimation und Haptik. |
| 2 | [Particles](https://reactbits.dev/backgrounds/particles) | Sternbild-Verbindungen erklären den echten Textverlauf. Keine beliebigen Sternexplosionen bei jedem Wort. | Vorhandene Lyrics-Geometrie, begrenzte Partikelzahl und echte Audio-/Lyrics-Zeit. |
| 3 | [Soft Aurora](https://reactbits.dev/backgrounds/soft-aurora) | Ruhiger Vollplayer-Hintergrund aus der Artwork-Palette; Text und Bedienelemente bleiben ruhig. | Ausschließlich Vollplayer, gedrosselter Shader; Mini-Player bleibt neutrales Systemglas. |
| 3 | [Gradual Blur](https://reactbits.dev/animations/gradual-blur) | Seitliche Karten am Rand leicht zurücknehmen; Texte und Tasten niemals hinter Blur verstecken. | Maskierter Rand der Cover-Sammlung, nicht die aktive Navigation. |

### MVP und Abnahme für die vier besten Ideen

**Galaxie:** eine bestehende Sammlungsansicht, drei Mikrointeraktionen: drehen, einrasten, öffnen. Quelle sind geladene ShelfCards. Bei Ladefehlern erreichbares Wiederholen und normale Liste; leere Daten zeigen keine erfundenen Alben. Touch-Drag, Maus-/Trackpad-Scroll, Pfeiltasten und VoiceOver-Vor/Zurück müssen dieselbe Auswahl erreichen. Reduce Motion: ruhige Reihe ohne Umlaufanimation. Erfolg: Auswahl bleibt nach schnellem Richtungswechsel korrekt, Rückkehr stellt sie wieder her, Musik läuft weiter.

**Schallplatte:** dieselbe Ansicht mit Plattenstil. Drei Schritte des Wechsels bleiben unterbrechbar; laufende und gewählte Platte dürfen nicht verwechselt werden. Coverfehler zeigen einen ehrlichen Platzhalter. Vor/Zurück als Tasten neben der Wischgeste. Reduce Motion: direkter Coverwechsel. Erfolg: keine falschen Titel/Cover nach Mehrfachwechsel; Hülle verdeckt keine Aktion; Rückkehr in die Sammlung behält Position.

**Sternbild:** zwei vorhandene Zustände, aktuelles Wort und Songkarte. Fokuswechsel, Karte öffnen und zur aktuellen Zeile zurückkehren sind die drei Mikrointeraktionen. Quelle sind echte zeitmarkierte Lyrics; fehlende Wortzeiten verwenden die Zeile, fehlende Lyrics einen verständlichen Leerzustand. Quellenangabe und Navigation ausreichend kontrastreich, mindestens 44 pt große Bedienelemente, VoiceOver liest aktuelle Zeile statt jedes Hintergrundwort. Reduce Motion: stabile Textliste. Erfolg: Seek, Pause, Titelwechsel und Abbruch halten Text und Sitzung zusammen; kein unlesbarer Gesamtzoom.

**Bogen-Scrubber:** eine Playeransicht, Fokus, Ziehen, Loslassen. Quelle ist die bestehende bestätigte Playback-Zeit; Buffering darf keinen Erfolg vorwegnehmen. Tastatur und VoiceOver bieten Zeitänderung in Schritten. Reduce Motion: Zeiger ohne Schweif. Erfolg: Zielzeit nach Seek bestätigt, Abbruch verwirft unbestätigten Sprung, Volume und Mix überlappen nicht.

## Weitere Katalogideen – nur gezielt

| Gruppe | Eignung für RED Bit |
|---|---|
| Split/Blur/Gradient/Rotating Text | Einmalige Überschrift im Onboarding möglich; laufende Lyrics und Songtitel müssen stabil lesbar bleiben. |
| Count Up / Counter | Hörstatistik animieren, niemals ständig tickende Dauer dekorativ durchrollen lassen. |
| Fade Content / Animated Content | Schonendes Einblenden neu geladener Regale; keine Verzögerung bei Wiederöffnung oder Fokus. |
| Tilted Card / Spotlight / Glare / Holo Card | Optional Albumdetails am Mac; auf iPhone kurze Berührung statt hoverabhängiger Bedienung. |
| Stack / Card Swap / Depth Carousel / Circular Gallery | Varianten derselben Cover-Sammlung, nicht vier neue Navigationsarten gleichzeitig. |
| Animated List / Swipe Row / Stepper | Vorhandene SwiftUI-Listen, Swipe-Aktionen und Onboarding-Schritte verwenden; Löschen weiter nur vom Nutzer ausgelöst. |
| Swipe Toast / Status Mark / Fuse Button | Ehrliche Erfolgs- und Fehlerzustände, rücknehmbare Queue-Aktion; Standard-Accessibility und ausreichend Zeit. |
| Waves / Floating Lines / Threads / Silk | Optional ruhige Vollplayer-Atmosphäre; nur wenn Audioleistung und Akku im Gerätetest passen. |
| Star Border / Click Spark | Höchstens einmalige, dezente Bestätigung; keine blinkende Dauerumrandung. |
| Noise / Dither / Pixel-Effekte | Denkbare optionale Retro-Ansicht; nicht über Lesetext oder Coverdetails legen. |

## Bewusst nicht übernehmen

Cursor-Verfolgung und Verfolgungsbänder haben keinen tragfähigen iPhone-Nutzerweg. Glitch-, Entschlüsselungs-, Falltext-, Shredder- und Zerknüll-Effekte verschlechtern in Queue und Lyrics die Orientierung. Dauerhafte Warp-Tunnel, Blitze, Flüssigkeitssimulationen und physikalische Ballwelten erst gar nicht in den Hauptplayer aufnehmen. Foto-/Kameraeffekte brauchen für die Musikwiedergabe keinen zusätzlichen Zugriff.

Web-Dock, Pill Nav, Gooey Nav und Glass Surface ersetzen nicht die native iPhone-Tab-Leiste, Suche und das gekoppelte Bottom Accessory. Cover-Morph und System-Zoom behalten ihren vorhandenen Ursprung. Kein erneuter Kreis-/Boom-Zoom beim Songwechsel.

## Herkunft und Lizenz

Recherche: 15. November 2026, [offizielles Repository](https://github.com/DavidHDev/react-bits). Die [aktuelle Lizenz](https://github.com/DavidHDev/react-bits/blob/main/LICENSE.md) heißt **MIT + Commons Clause**, nicht uneingeschränkt MIT. Die Datei erlaubt Verwendung innerhalb einer App unter Bedingungen und schränkt eigenständige Weitergabe/Verwertung der Komponenten und ihrer Portierungen ein. Vor einer tatsächlichen Codeübernahme genaue Version, Hinweise und Bedingungen separat prüfen. Hier nur Ideenrecherche, kein React-Bits-Code, Shader oder Sound kopiert.

Status: Ursprüngliche Ideenrecherche. Die inzwischen umgesetzten Erweiterungen und ihre tatsächlichen Prüfgrenzen stehen im [PR-59-Nachtrag](PR59_NATIVE_MOTION_20261115.md).
