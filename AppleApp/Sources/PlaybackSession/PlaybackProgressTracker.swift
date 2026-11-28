import Foundation

/// Misst Zeitfortschritt zwischen zwei Beobachtungen, ohne Wiedergabe zu verändern.
struct PlaybackProgressTracker {
    private struct Sample {
        let trackID: String
        let position: Double
        let at: TimeInterval
        let advancing: Bool
    }
    private var previous: Sample?

    mutating func observe(trackID: String?, position: Double, at: TimeInterval,
                          playing: Bool, buffering: Bool) -> Bool {
        guard let trackID, position.isFinite, position >= 0, at.isFinite else {
            previous = nil
            return false
        }
        let current = Sample(trackID: trackID, position: position, at: at,
                             advancing: playing && !buffering)
        defer { previous = current }
        guard let previous, previous.trackID == trackID,
              previous.advancing, current.advancing else { return false }
        let elapsed = at - previous.at
        let delta = position - previous.position
        // Große Sprünge sind Seeks; sie belegen keinen laufenden Transport.
        return elapsed > 0 && delta > 0.25 && delta <= elapsed * 2 + 0.5
    }
}

/// Monotone Stillstandsmessung: Pause, Puffern, Titelwechsel, Seek und
/// Ausführungslücken beginnen ein neues Beobachtungsfenster.
struct PlaybackStallTracker {
    private var trackID: String?
    private var anchor: Double?
    private var since: TimeInterval?
    private var previousAt: TimeInterval?

    mutating func observe(trackID: String?, position: Double, at: TimeInterval,
                          playing: Bool, buffering: Bool) -> TimeInterval {
        guard let trackID, position.isFinite, position >= 0, at.isFinite,
              playing, !buffering else {
            self = PlaybackStallTracker()
            return 0
        }
        if self.trackID != trackID || anchor == nil || previousAt == nil
            || at <= (previousAt ?? at) || at - (previousAt ?? at) > 5
            || abs(position - (anchor ?? position)) > 0.02 {
            self.trackID = trackID
            anchor = position
            since = at
        }
        previousAt = at
        return max(0, at - (since ?? at))
    }

    /// Nur bei praktisch erreichtem Ende und belegbar vollständiger Quelle.
    /// Eine Katalogdauer oder eine leere Netzwerk-Pufferung genügt nicht.
    static func canFinish(stalledFor: TimeInterval, position: Double, duration: Double,
                          bufferedFrames: UInt64, completeSource: Bool) -> Bool {
        stalledFor >= 12 && position.isFinite && duration.isFinite && duration > 1
            && position >= 0 && abs(duration - position) <= 0.1
            && bufferedFrames == 0 && completeSource
    }
}
