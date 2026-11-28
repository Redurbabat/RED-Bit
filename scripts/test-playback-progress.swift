import Foundation

@main struct VerifyPlaybackProgress {
    static func main() {
        var tracker = PlaybackProgressTracker()
        func sample(_ position: Double, _ second: Double, track: String? = "one",
                    playing: Bool = true, buffering: Bool = false) -> Bool {
            tracker.observe(trackID: track, position: position, at: second,
                            playing: playing, buffering: buffering)
        }
        precondition(!sample(10, 0), "Erste Messung hat noch keinen Vergleichswert")
        precondition(sample(11, 1), "Laufende Wiedergabe muss erkannt werden")
        precondition(!sample(11, 2), "Ein Stillstand darf keinen früheren Fortschritt erben")
        precondition(!sample(12, 3, playing: false), "Pause zählt nicht als Fortschritt")
        precondition(!sample(13, 4), "Erste Messung nach Pause ist eine neue Ausgangslage")
        precondition(sample(14, 5), "Fortsetzen wird im nächsten Intervall erkannt")
        precondition(!sample(90, 6), "Ein großer Seek ist kein Wiedergabenachweis")
        precondition(sample(91, 7), "Nach dem Seek kann Wiedergabe wieder fortschreiten")
        precondition(!sample(1, 8, track: "two"), "Titelwechsel übernimmt keinen Fortschritt")
        precondition(sample(2, 9, track: "two"), "Neuer Titel erhält eigenen Vergleich")
        precondition(!sample(3, 10, track: "two", buffering: true), "Puffern zählt nicht als Fortschritt")
        precondition(!sample(4, 11, track: "two"), "Nach Puffern neu vergleichen")
        precondition(!sample(.nan, 12, track: "two"), "Ungültige Position verwerfen")
        precondition(!sample(5, 13, track: "two"), "Keinen Vergleich mit ungültigem Wert")
        precondition(!sample(6, 14, track: nil), "Ohne ausgewählten Titel kein Nachweis")
        precondition(!sample(7, 15, track: "two"), "Nach leerem Player neu vergleichen")
        precondition(!sample(8, 15, track: "two"), "Gleicher Messzeitpunkt ist kein Intervall")
        precondition(!sample(9, 14, track: "two"), "Rückläufige Uhr ist kein Intervall")
        precondition(!sample(10, .infinity, track: "two"), "Ungültige Uhr verwerfen")
        // Originaler iPhone-Befund: letzte 12 ms fehlen, 39 s kein Fortschritt.
        var stall = PlaybackStallTracker()
        precondition(stall.observe(trackID: "one", position: 373.449, at: 366, playing: true, buffering: false) == 0)
        for second in 367...405 {
            let elapsed = stall.observe(trackID: "one", position: 373.449, at: Double(second), playing: true, buffering: false)
            precondition(elapsed == Double(second - 366))
        }
        precondition(PlaybackStallTracker.canFinish(stalledFor: 39, position: 373.449, duration: 373.461, bufferedFrames: 0, completeSource: true))
        precondition(!PlaybackStallTracker.canFinish(stalledFor: 39, position: 373.449, duration: 373.461, bufferedFrames: 0, completeSource: false))
        precondition(!PlaybackStallTracker.canFinish(stalledFor: 39, position: 373.449, duration: 373.461, bufferedFrames: 1, completeSource: true))
        precondition(!PlaybackStallTracker.canFinish(stalledFor: 39, position: 370, duration: 373.461, bufferedFrames: 0, completeSource: true))
        precondition(!PlaybackStallTracker.canFinish(stalledFor: 9, position: 373.449, duration: 373.461, bufferedFrames: 0, completeSource: true))
        precondition(stall.observe(trackID: "one", position: 373.449, at: 406, playing: false, buffering: false) == 0)
        precondition(stall.observe(trackID: "one", position: 373.449, at: 407, playing: true, buffering: true) == 0)
        precondition(stall.observe(trackID: "two", position: 0, at: 408, playing: true, buffering: false) == 0)
        precondition(stall.observe(trackID: "two", position: 0, at: 450, playing: true, buffering: false) == 0)
        precondition(stall.observe(trackID: "two", position: 10, at: 451, playing: true, buffering: false) == 0)
        print("BESTANDEN: Stillstandsregression und Ende-Sicherheitsgrenzen")
        print("BESTANDEN: Fortschritt, Stillstand, Pause, Seek, Titelwechsel, Puffern und ungültige Messwerte")
    }
}
