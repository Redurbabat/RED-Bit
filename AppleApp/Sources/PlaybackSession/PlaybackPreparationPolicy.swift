import Foundation

/// Leave time to arm the transition even when quality lookups are still running.
enum PlaybackPreparationPolicy {
    static func lookupBudget(remainingSeconds: TimeInterval, transitionSeconds: TimeInterval) -> TimeInterval {
        min(12.5, max(0.8, remainingSeconds - max(0, transitionSeconds) - 2))
    }

    /// Die bereits vorbereitete Sicherheitsüberblendung hat Vorrang vor
    /// zusätzlicher Analyse, besonders bei kurzen Titeln oder unbekannter Länge.
    static func shouldAnalyze(attempt: Int, elapsed: TimeInterval,
                              outgoingDuration: TimeInterval, position: TimeInterval,
                              fadeSeconds: TimeInterval) -> Bool {
        guard attempt >= 0, attempt < 12, elapsed.isFinite, elapsed >= 0, elapsed < 24,
              position.isFinite, fadeSeconds.isFinite, outgoingDuration.isFinite else { return false }
        if outgoingDuration <= 0 { return attempt == 0 }
        return outgoingDuration - position > max(0, fadeSeconds) + 8
    }

    /// Ein Fehler im Planner oder in der Engine beweist nicht, dass die
    /// erfolgreich vorbereitete Musikquelle unspielbar ist.
    static func mayMarkUnplayable(sourcePrepared: Bool) -> Bool {
        !sourcePrepared
    }
}
