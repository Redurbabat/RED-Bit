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
