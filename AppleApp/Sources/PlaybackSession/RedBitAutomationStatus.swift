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
