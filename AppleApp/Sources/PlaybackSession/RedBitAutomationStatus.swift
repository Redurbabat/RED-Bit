import Foundation

/// Versionsstabile, rein lesende Statusprojektion für lokale Automatisierung.
/// Keine freien Strings aus der Musikquelle, keine Pfade, IDs, Konten,
/// Tokens, URLs, Titel, Künstler, Historie oder Rohdiagnosen.
struct RedBitAutomationStatus: Encodable {
    enum State: String, Encodable {
        case stopped, buffering, playing, paused
    }

    let version = 1
    let state: State
    let hasTrack: Bool
    let positionSeconds: Double?
    let durationSeconds: Double?
    let canNext: Bool
    let canPrevious: Bool
    let controlsLocked: Bool
    let hasPlaybackError: Bool

    init(state: State, hasTrack: Bool, position: Double, duration: Double,
         canNext: Bool, canPrevious: Bool, controlsLocked: Bool, hasPlaybackError: Bool) {
        self.state = hasTrack ? state : .stopped
        self.hasTrack = hasTrack
        let validDuration = hasTrack && duration.isFinite && duration > 0
        durationSeconds = validDuration ? duration.rounded(.down) : nil
        if hasTrack, position.isFinite, position >= 0 {
            positionSeconds = (validDuration ? min(position, duration) : position).rounded(.down)
        } else {
            positionSeconds = nil
        }
        self.canNext = canNext && !controlsLocked
        self.canPrevious = canPrevious && !controlsLocked
        self.controlsLocked = controlsLocked
        self.hasPlaybackError = hasPlaybackError
    }

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

/// Explizite Befehle statt Toggle. Nur Play/Pause sind idempotent;
/// ein erneutes Next/Previous ist eine weitere bewusste Navigation.
enum RedBitTransportCommand: String, Encodable {
    case play, pause, next, previous

    enum Decision: String, Encodable {
        case requested, unchanged, locked, unavailable
    }

    func decision(for status: RedBitAutomationStatus) -> Decision {
        guard !status.controlsLocked else { return .locked }
        guard status.hasTrack else { return .unavailable }
        switch self {
        case .play:
            return status.state == .playing || status.state == .buffering ? .unchanged : .requested
        case .pause:
            return status.state == .playing || status.state == .buffering ? .requested : .unchanged
        case .next:
            return status.canNext ? .requested : .unavailable
        case .previous:
            return status.canPrevious ? .requested : .unavailable
        }
    }

    struct Receipt: Encodable {
        let version = 1
        let command: RedBitTransportCommand
        let decision: Decision
        let status: RedBitAutomationStatus

        func json() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return String(decoding: try encoder.encode(self), as: UTF8.self)
        }
    }
}
