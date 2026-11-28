import Foundation

/// One bounded retry budget per selected track; pauses and seeks reset observation.
struct PlaybackRecoveryPolicy {
    private var trackID: String?
    private var attempts = 0
    private var lastPosition: Double?
    private var lastProgressAt: TimeInterval?

    static func canRecover(entrySource: String, loadedSource: String, origin: String?) -> Bool {
        if loadedSource.hasPrefix("https://") || loadedSource.hasPrefix("http://") { return true }
        guard origin != "local" else { return false }
        return entrySource.hasPrefix("yt:") || entrySource.hasPrefix("src:") || entrySource.hasPrefix("saavn:")
    }

    mutating func select(_ id: String, resetAttempts: Bool) {
        if trackID != id || resetAttempts { attempts = 0 }
        trackID = id
        lastPosition = nil
        lastProgressAt = nil
    }

    mutating func observe(position: Double, now: TimeInterval, playing: Bool, bufferedFrames: UInt64) -> Bool {
        guard playing else { lastPosition = nil; lastProgressAt = nil; return false }
        if lastPosition == nil || abs(position - (lastPosition ?? position)) > 0.02 {
            lastPosition = position
            lastProgressAt = now
            return false
        }
        // Ein nichtleerer Puffer ist kein Stream-Stillstand. Erst ab dem
        // anschliessenden leeren Puffer beginnt das Zeitfenster erneut.
        if bufferedFrames > 0 {
            lastProgressAt = now
            return false
        }
        return now - (lastProgressAt ?? now) >= 12
    }

    mutating func claimRetry(position: Double, duration: Double, confirmedFailure: Bool = false) -> Bool {
        guard attempts < 2, confirmedFailure || duration <= 0 || position < duration - 3 else { return false }
        attempts += 1
        lastPosition = nil
        lastProgressAt = nil
        return true
    }
}

/// Überwacht die Audio-Ausgabe getrennt von der Netzwerkquelle.
/// Eine Reparatur pro Auswahl, keine Endlosschleife bei defekter Hardware.
struct PlaybackOutputWatchdog {
    private var selection: UInt64?
    private var position: Double?
    private var blockedSince: TimeInterval?
    private var attempted = false

    mutating func observe(selection: UInt64, position: Double, now: TimeInterval,
                          playing: Bool, bufferedFrames: UInt64) -> Bool {
        if self.selection != selection {
            self.selection = selection
            self.position = nil
            blockedSince = nil
            attempted = false
        }
        guard playing, position.isFinite, now.isFinite, bufferedFrames > 0 else {
            self.position = nil
            blockedSince = nil
            return false
        }
        if self.position == nil || abs(position - (self.position ?? position)) > 0.02 {
            self.position = position
            blockedSince = now
            return false
        }
        guard !attempted, now - (blockedSince ?? now) >= 12 else { return false }
        attempted = true
        return true
    }
}
