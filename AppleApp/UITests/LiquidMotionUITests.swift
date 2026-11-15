#if os(iOS)
import XCTest

/// Real-device UI automation. Runs from Xcode / a device lab, NOT from the
/// installed app itself. The test only validates the offline design previews.
@MainActor
final class LiquidMotionUITests: XCTestCase {
    func testBloodstreamLiveConstellationNavigation() throws {
        guard ProcessInfo.processInfo.environment["REDBIT_LIVE_DEVICE_TESTS"] == "1" else {
            throw XCTSkip("Echter Musiktest benötigt ausdrücklich REDBIT_LIVE_DEVICE_TESTS=1 und eine vorbereitete Gerätesitzung.")
        }
        let app = XCUIApplication()
        app.activate()
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name; shot.lifetime = .keepAlways; add(shot)
        }
        let map = app.buttons["red.lyrics.map"]
        if !map.exists {
            let pill = app.buttons["bbt.playback.pill.open"]
            if pill.waitForExistence(timeout: 10) { pill.tap() }
            let lyrics = app.buttons["quote.bubble"]
            if lyrics.waitForExistence(timeout: 10) { lyrics.tap() }
        }
        XCTAssertTrue(map.waitForExistence(timeout: 20), "Bloodstream-Sternbild muss geöffnet sein")
        capture("Bloodstream-Sternbild-live")
        map.tap()
        capture("Bloodstream-Songkarte-live")
        app.swipeLeft()
        capture("Bloodstream-Verlauf-live")
        let current = app.buttons["red.lyrics.current"]
        if current.exists && current.isHittable { current.tap() }
        app.buttons["bbt.lyrics.constellation.list"].tap()
        capture("Bloodstream-Liste-live")
        XCUIDevice.shared.press(.home)
        let timer = expectation(description: "Hintergrundbeobachtung")
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { timer.fulfill() }
        wait(for: [timer], timeout: 20)
        app.activate()
        capture("Bloodstream-nach-Hintergrund")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Bloodstream-Navigation-Hierarchie"; tree.lifetime = .keepAlways; add(tree)
    }

    func testRealCurrentMusicTransportAndZoom() throws {
        guard ProcessInfo.processInfo.environment["REDBIT_LIVE_DEVICE_TESTS"] == "1" else {
            throw XCTSkip("Echter Musiktest benötigt ausdrücklich REDBIT_LIVE_DEVICE_TESTS=1 und eine vorbereitete Gerätesitzung.")
        }
        let app = XCUIApplication()
        app.activate()
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }
        defer {
            capture("RED-Bit-Musik-Testabschluss")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "RED-Bit-Musik-Player-Hierarchie"
            tree.lifetime = .keepAlways
            add(tree)
        }
        let pill = app.buttons["bbt.playback.pill.open"]
        XCTAssertTrue(pill.waitForExistence(timeout: 30))
        XCTAssertFalse(pill.label.contains("Keine Wiedergabe"), "Kein echter Titel in der Sitzung")
        capture("RED-Bit-Musik-Mini-Player")
        let transport = app.buttons["bbt.playback.pill.play"]
        XCTAssertTrue(transport.exists)
        if transport.label == "Pause" { transport.tap() }
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        transport.tap()
        let playing = expectation(for: NSPredicate(format: "label == %@", "Pause"), evaluatedWith: transport)
        wait(for: [playing], timeout: 30)
        capture("RED-Bit-Musik-fortgesetzt")
        pill.tap()
        let fullPlay = app.buttons["bbt.nowPlaying.play"].firstMatch
        XCTAssertTrue(fullPlay.waitForExistence(timeout: 15))
        capture("RED-Bit-Musik-Vollplayer")
        let tools = app.buttons.matching(NSPredicate(format: "label IN %@", ["More player tools", "Weitere Player-Werkzeuge", "Weitere Playerwerkzeuge"])).firstMatch
        if tools.exists {
            tools.tap()
            capture("RED-Bit-Musik-Werkzeugmenue")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "RED-Bit-Musik-Werkzeugmenue-Hierarchie"
            tree.lifetime = .keepAlways
            add(tree)
            app.tap()
        }
        let lyrics = app.buttons.matching(NSPredicate(format: "label IN %@", ["Lyrics", "Songtexte", "Songtext", "No lyrics", "Keine Songtexte"])).firstMatch
        if lyrics.exists && lyrics.isHittable {
            lyrics.tap()
            capture("RED-Bit-Musik-Songtextansicht")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "RED-Bit-Musik-Songtext-Hierarchie"
            tree.lifetime = .keepAlways
            add(tree)
        }
        app.swipeLeft()
        capture("RED-Bit-Musik-Player-nach-links")
        app.swipeRight()
        capture("RED-Bit-Musik-Player-nach-rechts")
    }

    /// Echter Netzwerk-Nutzerweg; ohne Vorschauargumente oder Audio-Fixtures.
    func testRealMusicSearchAndPlayer() throws {
        guard ProcessInfo.processInfo.environment["REDBIT_LIVE_DEVICE_TESTS"] == "1" else {
            throw XCTSkip("Echter Musiktest benötigt ausdrücklich REDBIT_LIVE_DEVICE_TESTS=1 und eine vorbereitete Gerätesitzung.")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-onboarding_done", "YES", "-automix_models_prompt_dismissed_v2", "YES"]
        app.launch()
        defer {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "RED-Bit-Echte-Musik-Endzustand"
            shot.lifetime = .keepAlways
            add(shot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "RED-Bit-Echte-Musik-Hierarchie"
            tree.lifetime = .keepAlways
            add(tree)
        }
        let search = app.tabBars.buttons.containing(.image, identifier: "magnifyingglass").firstMatch
        if !app.searchFields.firstMatch.exists {
            XCTAssertTrue(search.waitForExistence(timeout: 30))
            search.tap()
        }
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        }
        // Bei Hardware-Tastatur kann das Feld fokussiert sein, ohne dass iOS
        // eine Bildschirmtastatur in der Accessibility-Hierarchie meldet.
        if let value = field.value as? String, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText("Ed Sheeran Bloodstream\n")
        let play = app.buttons.matching(NSPredicate(format: "label == %@", "Bloodstream, Ed Sheeran")).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 45), "Keine echte Suchantwort mit abspielbarem Top-Ergebnis")
        play.tap()
        let pill = app.buttons["bbt.playback.pill.open"]
        XCTAssertTrue(pill.waitForExistence(timeout: 20))
        pill.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RED-Bit-Echte-Musik-Vollplayer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let lyrics = app.buttons["quote.bubble"]
        XCTAssertTrue(lyrics.waitForExistence(timeout: 10))
        lyrics.tap()
        let lyricsShot = XCTAttachment(screenshot: app.screenshot())
        lyricsShot.name = "Bloodstream-Songtexte"
        lyricsShot.lifetime = .keepAlways
        add(lyricsShot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Bloodstream-Songtext-Hierarchie"
        tree.lifetime = .keepAlways
        add(tree)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Prüft die native Suche mit sichtbarer leerer Pill, Tastatur-Handoff
    /// und anschließendem Öffnen des Vollplayers. Kein Audio-Nachweis.
    func testSearchKeyboardCanOpenAndDismissOnRegularAppLaunch() throws {
        let app = XCUIApplication()
        // Beide vorhandenen Erststart-Fragen sind für diesen wiederkehrenden
        // Nutzerweg schon beantwortet. Die echte App startet ohne Test-Preview.
        app.launchArguments += ["-onboarding_done", "YES",
                                "-automix_models_prompt_dismissed_v2", "YES"]
        app.launch()

        // Die Kennung gehört zum Bild im nativen Button, nicht zum Button
        // selbst. Der echte Accessibility-Baum trennt diese beiden Elemente.
        let searchTab = app.tabBars.buttons.containing(.image, identifier: "magnifyingglass").firstMatch
        if !searchTab.waitForExistence(timeout: 20) {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "BBT-Bit-Search-Tab-Missing"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertTrue(searchTab.exists,
                      "Search tab unavailable on regular app launch. Accessibility tree: \(app.debugDescription)")
        let searchReady = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: searchTab)
        wait(for: [searchReady], timeout: 15)
        searchTab.tap()

        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 15) {
            let missing = XCTAttachment(screenshot: app.screenshot())
            missing.name = "RED-Bit-Suchfeld-fehlt"
            missing.lifetime = .keepAlways
            add(missing)
        }
        XCTAssertTrue(searchField.exists,
                      "Natives iPhone-Suchfeld fehlt. Hierarchie: \(app.debugDescription)")
        let pillID = "bbt.playback.pill.open"
        let pill = app.buttons[pillID]
        XCTAssertTrue(pill.waitForExistence(timeout: 10),
                      "Mini-player must be present even in the empty playback state")
        XCTAssertEqual(app.buttons.matching(identifier: pillID).count, 1,
                       "Expected exactly one mini-player before keyboard focus")

        searchField.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10),
                      "Search field did not display the keyboard")
        // Ein frischer iOS-Simulator zeigt zuerst die QuickPath-Einführung.
        // Dieser Systemdialog gehört nicht zur App und muss beantwortet sein.
        let keyboardIntroduction = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Continue", "Fortfahren"])
        ).firstMatch
        if keyboardIntroduction.waitForExistence(timeout: 2) {
            keyboardIntroduction.tap()
        }
        // Keep a diagnostic screenshot even when a subsequent geometry
        // assertion fails. XCTest otherwise loses the interesting layout.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "BBT-Bit-Search-Keyboard-Visible"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(pill.waitForExistence(timeout: 10),
                      "Mini-player disappeared when the search keyboard opened")
        XCTAssertEqual(app.buttons.matching(identifier: pillID).count, 1,
                       "Native bottom accessory and keyboard inset duplicated the mini-player")
        XCTAssertTrue(pill.isHittable, "Mini-player is not reachable above the keyboard")
        XCTAssertGreaterThanOrEqual(pill.frame.height, 44,
                                    "Öffnen-Trefffläche des Mini-Players ist zu klein")
        for identifier in ["bbt.playback.pill.play", "bbt.playback.pill.next"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.exists, "Transport-Bedienelement fehlt: \(identifier)")
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
        }
        XCTAssertLessThanOrEqual(pill.frame.maxY, keyboard.frame.minY + 4,
                                 "Mini-player overlaps the native keyboard")
        XCTAssertFalse(pill.frame.intersects(searchField.frame),
                       "Der Mini-Player überlagert das native Suchfeld")
        XCTAssertLessThanOrEqual(pill.frame.maxY, searchField.frame.minY + 1,
                                 "Der Player muss oberhalb der Suchleiste liegen")
        XCTAssertTrue(searchField.isHittable, "Das Suchfeld ist vom Player verdeckt")

        // Native return-key labels are localized (e.g. "Suchen" on a
        // German simulator). A missing key must fail, not skip the whole
        // test and conceal already-executed keyboard layout assertions.
        searchField.typeText("red bit")
        let searchKey = ["Suchen", "Search", "search"].map { keyboard.buttons[$0] }
            .first(where: { $0.exists })
        if searchKey == nil {
            let noKey = XCTAttachment(screenshot: app.screenshot())
            noKey.name = "BBT-Bit-Search-Key-Unavailable"
            noKey.lifetime = .keepAlways
            add(noKey)
        }
        XCTAssertNotNil(searchKey, "Native search keyboard has no recognized submit key")
        searchKey?.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: keyboard)
        wait(for: [dismissed], timeout: 10)
        XCTAssertTrue(pill.waitForExistence(timeout: 10),
                      "Mini-player missing after keyboard dismissal")
        XCTAssertEqual(app.buttons.matching(identifier: pillID).count, 1,
                       "Mini-player duplicated after keyboard dismissal")
        pill.tap()
        XCTAssertTrue(app.buttons["bbt.nowPlaying.play"].waitForExistence(timeout: 15),
                      "Der Mini-Player öffnet den Vollplayer nach dem Tastaturwechsel nicht")
    }

    func testVideoReferenceViewsAndLyricsSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--bbt-ui-test-video-references"]
        app.launch()
        let rail = app.otherElements["bbt.video.artist.rail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 20), "Das echte Künstlerkarten-Fixture fehlt")
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "RED-Bit-Videoreferenz-Karussell-und-Bogen"
        before.lifetime = .keepAlways
        add(before)
        rail.swipeLeft(velocity: .slow)
        let moved = XCTAttachment(screenshot: app.screenshot())
        moved.name = "RED-Bit-Videoreferenz-Karussell-nach-Wischen"
        moved.lifetime = .keepAlways
        add(moved)
        let open = app.buttons["bbt.video.constellation.open"]
        if !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let list = app.buttons["bbt.lyrics.constellation.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Sternbild muss einen direkten Listen-Rückweg besitzen")
        let stars = XCTAttachment(screenshot: app.screenshot())
        stars.name = "RED-Bit-Videoreferenz-Sternbild"
        stars.lifetime = .keepAlways
        add(stars)
        list.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Rückkehr aus dem Sternbild zur Liste fehlt")
    }

    /// Prüft beide Sammlungen getrennt mit Produktionskomponenten und lokalen Prüfdaten.
    func testAlbumPreviewFlipAndCoverFan() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--red-ui-test-creative"]
        app.launch()
        let flip = app.buttons["red.album.preview.flip"]
        XCTAssertTrue(flip.waitForExistence(timeout: 20))
        var attempts = 0
        while !flip.isHittable && attempts < 8 { app.swipeUp(); attempts += 1 }
        XCTAssertTrue(flip.isHittable)
        let originalLabel = flip.label
        flip.tap()
        XCTAssertNotEqual(flip.label, originalLabel)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "RED-Bit-Album-Rueckseite"
        shot.lifetime = .keepAlways
        add(shot)
        flip.tap()
        XCTAssertEqual(flip.label, originalLabel)
        let fan = app.buttons["red.playlist.fan.toggle"]
        while !fan.isHittable && attempts < 16 { app.swipeDown(); attempts += 1 }
        XCTAssertTrue(fan.isHittable)
        fan.tap()
        let expandedLabel = fan.label
        fan.tap()
        XCTAssertNotEqual(fan.label, expandedLabel)
    }

    func testGalaxyAndRecordsTransitions() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--red-ui-test-creative"]
        app.launch()
        for style in ["galaxy", "records"] {
            let collection = app.descendants(matching: .any)["red.fixture.\(style)"].firstMatch
            XCTAssertTrue(collection.waitForExistence(timeout: 20))
            let next = collection.buttons["red.collection.next"]
            var attempts = 0
            while !next.isHittable && attempts < 6 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(next.isHittable)
            for step in 0...3 {
                if step > 0 { next.tap() }
                let title = ["Abendlicht", "Farbenspiel", "Horizont", "Weitblick"][step]
                XCTAssertTrue(collection.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "RED-Bit-\(style)-Wechsel-\(step)"
                shot.lifetime = .keepAlways
                add(shot)
            }
            collection.buttons["red.collection.previous"].tap()
            XCTAssertTrue(collection.staticTexts["Horizont"].firstMatch.waitForExistence(timeout: 5))
        }
    }

    func testCreativeCollectionsAndTimedConstellationFinale() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--red-ui-test-creative"]
        app.launch()
        let next = app.buttons.matching(identifier: "red.collection.next").firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        if !next.isHittable { app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.staticTexts["Farbenspiel"].firstMatch.waitForExistence(timeout: 5))
        app.swipeDown()
        let lyrics = app.buttons["red.fixture.lyrics"]
        XCTAssertTrue(lyrics.isHittable)
        lyrics.tap()
        let map = app.buttons["red.lyrics.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["red.lyrics.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["red.lyrics.current"].exists)
        app.buttons["red.fixture.finale"].tap()
        XCTAssertTrue(app.staticTexts["red.lyrics.finale"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["red.lyrics.finale"].value as? String, "0 %")
        app.buttons["red.fixture.middle"].tap()
        XCTAssertEqual(app.staticTexts["red.lyrics.finale"].value as? String, "50 %")
        let middle = XCTAttachment(screenshot: app.screenshot())
        middle.name = "RED-Bit-Sternkarte-fuenf-Sekunden-vor-Ende"
        middle.lifetime = .keepAlways
        add(middle)
        app.buttons["red.fixture.end"].tap()
        XCTAssertEqual(app.staticTexts["red.lyrics.finale"].value as? String, "100 %")
        let end = XCTAttachment(screenshot: app.screenshot())
        end.name = "RED-Bit-Sternkarte-vollstaendiger-Verlauf"
        end.lifetime = .keepAlways
        add(end)
        app.buttons["Start"].tap()
        XCTAssertFalse(app.staticTexts["red.lyrics.finale"].exists)
        app.buttons["bbt.lyrics.constellation.list"].tap()
        XCTAssertTrue(lyrics.waitForExistence(timeout: 5))
    }

    func testTopResultAndNativeMinimizedAccessoryDoNotStretchOrOverlap() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--bbt-ui-test-playback-chrome"]
        app.launch()
        let play = app.buttons["bbt.search.topResult.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        let playlist = app.buttons["bbt.search.topResult.playlist"]
        for button in [play, playlist] {
            XCTAssertTrue(button.exists)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThan(button.frame.height, 110,
                              "Die Top-Ergebnis-Aktion streckt sich zur vertikalen Kapsel")
        }
        let card = app.otherElements["bbt.search.topResult"]
        XCTAssertLessThan(card.frame.height, 350, "Das Top-Ergebnis belegt fast den ganzen Bildschirm")
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "RED-Bit-Top-Ergebnis-begrenzte-Hoehe"
        initial.lifetime = .keepAlways
        add(initial)

        app.swipeUp(velocity: .slow)
        app.swipeUp(velocity: .slow)
        assertNativePlaybackDoesNotCoverTabs(app)
        let minimized = XCTAttachment(screenshot: app.screenshot())
        minimized.name = "RED-Bit-Nativer-Dock-nach-Abwaertsscrollen"
        minimized.lifetime = .keepAlways
        add(minimized)
        app.swipeDown(velocity: .slow)
        assertNativePlaybackDoesNotCoverTabs(app)
    }

    private func assertNativePlaybackDoesNotCoverTabs(_ app: XCUIApplication) {
        let pill = app.buttons["bbt.playback.pill.open"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "bbt.playback.pill.open").count, 1)
        // Das inline Accessory kann selbst AX-Nachfahre der Tab-Bar sein.
        // Nur die vier tatsächlichen Tab-Aktionen mit dem Player vergleichen.
        var checkedTabs = 0
        let tabNames = ["Home", "Start", "Jetzt hören", "Explore", "Entdecken", "Library", "Bibliothek", "Mediathek", "Search", "Suchen"]
        let tabs = app.buttons.matching(NSPredicate(format: "label IN %@", tabNames)).allElementsBoundByIndex
        for tab in tabs where tab.isHittable {
            checkedTabs += 1
            for identifier in ["bbt.playback.pill.open", "bbt.playback.pill.play", "bbt.playback.pill.next"] {
                XCTAssertFalse(tab.frame.insetBy(dx: 1, dy: 1).intersects(app.buttons[identifier].frame),
                               "Player überlagert nativen Tab: \(tab.label)")
            }
        }
        XCTAssertGreaterThan(checkedTabs, 0, "Kein nativer Tab für die Überlagerungsprüfung erreichbar")
    }

    func testEveryDesignPreviewIsRenderedAndOpenableOnIPhone() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--bbt-ui-test-designs"]
        app.launch()

        let start = app.buttons["bbt.selftest.run"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "Self-test entry point did not appear")
        start.tap()

        let summary = app.staticTexts["bbt.selftest.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 120), "On-device self-test did not finish")
        XCTAssertTrue(summary.label.contains("15 bestanden"), summary.label)

        let shareReport = app.buttons["bbt.selftest.share"]
        XCTAssertTrue(shareReport.exists, "JSON report export is missing")

        for index in 1...15 {
            let testID = String(format: "bbt.selftest.feature.%02d", index)
            let row = app.buttons[testID]

            var attempts = 0
            while !row.isHittable && attempts < 16 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(row.isHittable, "Could not find or tap design \(index)")

            row.tap()
            let close = app.buttons["bbt.selftest.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 12),
                          "Preview \(index) did not open")

            // Exercise a few representative real SwiftUI preview controls
            // instead of treating every static illustration as interactive.
            switch index {
            case 1:
                // Seit #49/#50 öffnet der Automix-Status ein Detail-Sheet statt
                // umzuschalten; die Beschriftung ist lokalisiert. Deshalb über
                // sprachunabhängige Kennungen prüfen und das Sheet wieder schließen,
                // damit der Schließen-Knopf der Vorschau erreichbar bleibt.
                let automix = app.buttons["bbt.automix.status"]
                XCTAssertTrue(automix.waitForExistence(timeout: 5), "Automix preview control is missing")
                automix.tap()
                let done = app.buttons["bbt.automix.details.done"]
                XCTAssertTrue(done.waitForExistence(timeout: 5), "Automix details did not open")
                done.tap()
                let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: done)
                wait(for: [dismissed], timeout: 5)
            case 2:
                let flip = app.buttons["red.lyrics.mirror.toggle"]
                XCTAssertTrue(flip.exists, "Lyrics switch is missing")
                flip.tap()
                let original = expectation(for: NSPredicate(format: "value == %@", "Wir hören den Rhythmus"), evaluatedWith: flip)
                wait(for: [original], timeout: 5)
            case 3:
                let prism = app.buttons["red.signal.prism.toggle"]
                XCTAssertTrue(prism.exists, "Audio pipeline preview control is missing")
                prism.tap()
                XCTAssertTrue(app.staticTexts["red.signal.stage.0.label"].exists)
            default:
                break
            }

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = String(format: "BBT-Bit-Design-%02d", index)
            screenshot.lifetime = .keepAlways
            add(screenshot)
            close.tap()
            // The JSON share button sits at the top of a lazy List. After
            // scrolling to preview 6+ it is off-screen and may be recycled.
            // Assert the actual page, not a virtualized off-screen button.
            let page = app.navigationBars["Vorschau-Selbsttest"]
            XCTAssertTrue(page.waitForExistence(timeout: 12),
                          "Self-test screen disappeared after closing preview \(index)")
        }
    }
}
#endif
