# PR #59 · Vogel-Logo, native Musikinteraktionen und reguläre IPA

## Verhalten

Das neue Nutzerlogo ersetzt die Welle im Legacy-App-Icon, im Icon-Composer-Paket und im Template-Marker. Der rote Hintergrund reicht bis in die quadratischen Ecken; weiße Federdetails bleiben erhalten. Historische Dateien und die vorgefundene Icon-Composer-Konfiguration bleiben als Quellen erhalten.

Die aus React Bits ausgewählten Ideen werden in vorhandenen SwiftUI-Komponenten umgesetzt, ohne WebView oder React-Abhängigkeit:

- Galaxie: vorhandene coverbasierte Umlaufbahn, begrenzter Hintergrundbetrieb; die Sternanimation pausiert außerhalb der aktiven, sichtbaren Ansicht. Fehlende Coverfarben fallen auf den Akzent zurück.
- Plattenkarussell: laufende Auswahl bleibt bestehen; alte Animationsabschlüsse werden nach einem schnellen Richtungswechsel verworfen.
- Wortfokus: bisherige Wörter und ausgewählte Verlaufzeilen bleiben besser lesbar. Sternbild-Navigation und Quellenangaben bekommen stärkeren Kontrast.
- Kometen-Scrubber: kurzer Lichtschweif nur beim tatsächlichen Ziehen, ohne Daueranimation und ohne Änderung der Seek-Zeitbasis.
- Coverfächer: ruhigere Expansion mit Reduce-Motion-Fallback und gezielter Hervorhebung unter dem Mac-Zeiger.
- Favoriten-Puls: nur nach dem bestehenden bestätigten Speichermarker; kein optimistischer Speichererfolg.
- Zusätzliche Album-Rückseite in der vorhandenen Vorschau, ohne Wiedergabestart und ohne zusätzliche Datenabfrage.

Die Mix-Anzeige steht in einer eigenen Layoutzeile, damit sie nicht mehr über dem Lautstärkeregler liegt. Herkunfts-/Cache-/Songtextstatus und Anmeldebeschreibung bekommen deutsche Katalogwerte; gespeicherte Sprachwahl bleibt erhalten. Native Suche, Bottom Accessory, Scroll-Minimierung und Mini-/Vollplayer-Zoom bleiben an ihren bisherigen Montagepunkten.

## Prüfungen

Xcode 27.2 auf Apple Silicon. `xcodebuild -project AppleApp/RedBit.xcodeproj -scheme RedBit -configuration Debug -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=NO build`: BESTANDEN, reguläre App einschließlich Widget.

- 8 RED-Morph- und 10 native Now-Playing-Quellinvarianten bestanden.
- Tatsächliche Swift-Geometriereihe für Bogen, Zeitgrenzen, Sternroute, Schlusszoom und Galaxie bestanden.
- Repository-Prüfung und 33 deutsche Sprachinvarianten bestanden.
- Release-Metadaten-Gegenproben bestanden.
- 21 IPA-Paket-Gegenproben mit Python 3.13 und PyYAML 6.0.3 bestanden. Der erste Versuch unter dem vorinstallierten Python 3.9 konnte `hashlib.file_digest` nicht ausführen; keine gelockerten Prüfungen.
- Erster aktueller iPhone-UI-Lauf konnte den Automationsmodus nicht rechtzeitig starten; der Nutzer hat das Gerät danach entsperrt. Wiederholung siehe Nachtrag.

Neue Gerätetests bleiben ausdrücklich Preview-/UI-Fixture-Nachweise mit Produktionskomponenten. Ältere Bloodstream-Aufnahmen belegen keine Abnahme dieser neuen Revision. Echte Audioqualität, automatische Automix-Übergabe, Bluetooth, VoiceOver, große Schrift und alle Reduce-Motion-Zustände sind für diesen Nachtrag NICHT GETESTET. Die zusätzlichen Live-Musiktests benötigen absichtlich `REDBIT_LIVE_DEVICE_TESTS=1` im Test-Runner und eine vorbereitete echte Gerätesitzung; sie laufen nicht versehentlich im Offline-CI-Test.

## Paket und Identität

Die auszuliefernde IPA wird aus `AppleApp/project.yml` gebaut: `com.babat.bbtbit`, Target `RedBit`, Widget `com.babat.bbtbit.widget`, ursprüngliche App-Group-/iCloud-Konfiguration. Die lokale kostenlose Testkonfiguration wird nicht als Produktpaket verwendet und nicht committed. Version 1.0.4, Build 13 bleibt ein Entwicklungskandidat.

Mit dem vorhandenen Personal Team ist kein reguläres iCloud-Provisioning möglich. Die reguläre IPA ist daher ausdrücklich **unsigniert**, kein direkt installierbares signiertes Update. Sie muss später mit einem geeigneten Team und passenden Berechtigungen signiert werden. Das Paket verändert keine bereits installierte App; vom Agenten wird keine App gelöscht.

## Herkunft und Überschneidungen

Kein Code, Shader oder Sound aus React Bits übernommen; eigene native Änderungen anhand visueller Ideen. Deren aktuelle MIT-plus-Commons-Clause-Bedingungen sind im [Ideenbericht](REACT_BITS_IDEEN_20261115.md) verlinkt. Logoquelle vom Nutzer, Randkorrektur und Silhouette mit eingebautem Bildwerkzeug; keine Zusicherung pixelidentischer Retusche. Die vorbestehende Änderung an `PlaybackPill.swift` bleibt im Arbeitsbaum und wird nicht mitgenommen. Frühere lokale Testskript-/Geräteprüfungen werden als solche erhalten; lokale Fotos, Videos und Diagnosehierarchien gehen nicht in den PR.

## Aktueller iPhone-Nachweis

Wiederholung nach Entsperren: vier von vier ausgewählten XCUITests BESTANDEN, Exitcode 0. Album-Rückseite/Coverfächer 14,269 s, Sternbild-Finale 15,010 s, Galaxie/Plattenwechsel 24,606 s und Videoreferenz/Lyrics-Umschaltung 8,172 s. Resultbundle `build/ios/PR59-motion-unlocked-20261115.xcresult`, Log `build/ios/pr59-motion-unlocked.log`, exportierte Bilder `build/ios/pr59-motion-screenshots/`. Physisches iPhone 13 Pro Max, iOS 26.6.1. Die Prüfungen verwenden markierte lokale Prüfdaten und bestätigen keine neue echte Audio-/Kontenabnahme.

## Fertige reguläre Release-IPA

Xcode-Release-Archiv aus sauberem App-Commit `0cf95151dff16f33f9078f7446d331f391dcb058`: **ARCHIVE SUCCEEDED**, 151 Sekunden. `scripts/package-ios-ipa.sh 1.0.4 --output-dir <lokaler Ausgabeordner>` im isolierten Checkout erzeugte `RedBit-1.0.4-build13-ios-unsigned.ipa` (rund 30 MB). Die lokale kostenlose Testkonfiguration ist nicht enthalten.

`scripts/verify-regular-ios-ipa.py` mit Python 3.13 bestätigt App `com.babat.bbtbit`, Widget `com.babat.bbtbit.widget`, Version/Build, `RedBitRevision=0cf95151dff1`, Hintergrundaudio, beide Frameworks und arm64-iPhoneOS-Binaries. Kotlin-/Rust-Frameworks liegen in gültigen Universal-Containern mit arm64-Geräteslices; der zuvor verwendete reine Thin-Mach-O-Prüfer war dafür ungeeignet. Acht neue positive/negative Gegenproben bestanden. Kein eingebettetes Provisioning-Profil.

SHA-256: `b13ae5a7c8e49ea8d1948d4ecaf2eaf986ec55af0726cfff8aabdf26488b408a`.

Lokale Dateien unter `build/release/pr59-0cf9515/`: IPA, `build.json`, `SHA256.txt`, `INSTALL.md`. Der anschließende Prüfskript-/Dokumentationscommit ändert keinen App-Code; die IPA bleibt dem oben genannten App-Commit zugeordnet. Externe Signierung und Installation der regulären IPA sowie deren echte Audio-/Cloud-Abnahme bleiben offen. Kein Release veröffentlicht und kein Merge nach main.

## Parallel eingegangene Icon-Korrektur

Während des letzten Dokumentations-Pushs ging `75c25c1` auf demselben PR-Branch ein. Der Commit entfernt Glas-/Brechungsangaben vom Vogel-Icon und die nicht mehr verwendete Wellen-Ebene. Die Absichten überschneiden sich nur gestalterisch; der Prüfskriptcommit betraf getrennte Dateien. Konfliktfreie Integration ohne Force-Push in `4bdd5490a87f48e501e0dda4c7476a0756e657a2`. Die vorbestehende lokale PlaybackPill-Änderung und der unversionierte Nutzerordner bleiben erhalten. Für den integrierten App-Stand wird eine neue reguläre Release-IPA gebaut; das ältere Paket `0cf9515` bleibt ein historischer Zwischennachweis.

## Finale IPA mit vereinfachtem Vogel-Icon

Xcode `ARCHIVE SUCCEEDED` für `4bdd5490a87f48e501e0dda4c7476a0756e657a2`, 142 Sekunden. `build/release/pr59-4bdd549/RedBit-1.0.4-build13-ios-unsigned.ipa` ist die aktuelle Datei, nicht das ältere Zwischenpaket. Regulärer IPA-Prüfer BESTANDEN: ursprüngliche App-Kennung, Widget, native Frameworks und Quellrevision stimmen. SHA-256: `49be2694116013d0633e84b98e632371c5bbaac56f9da88410bde583ace4f23f`. Paketnachweise und Installationsgrenzen liegen daneben. Keine Entwickler-Signatur oder Installation dieser regulären IPA bestätigt.
