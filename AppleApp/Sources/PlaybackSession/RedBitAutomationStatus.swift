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

/// Begrenzte, typisierte Einstellungen; keine frei interpretierbaren Befehle.
enum RedBitAdjustment {
    case volumePercent(Double)
    case seekSeconds(Double)
    case automix(Bool)

    enum Decision: String, Encodable {
        case requested, unchanged, locked, unavailable, invalidValue
    }

    var command: String {
        switch self {
        case .volumePercent: return "setVolume"
        case .seekSeconds: return "seek"
        case .automix: return "setAutomix"
        }
    }

    func decision(status: RedBitAutomationStatus, volume: Double,
                  duration: Double, loaded: Bool, mixing: Bool,
                  automixEnabled: Bool) -> Decision {
        guard !status.controlsLocked else { return .locked }
        switch self {
        case .volumePercent(let percent):
            guard percent.isFinite, (0...100).contains(percent) else { return .invalidValue }
            return abs(volume - percent / 100) < 0.0001 ? .unchanged : .requested
        case .seekSeconds(let seconds):
            guard seconds.isFinite, seconds >= 0 else { return .invalidValue }
            guard status.hasTrack, loaded, !mixing,
                  status.state == .playing || status.state == .paused,
                  duration.isFinite, duration > 0 else { return .unavailable }
            guard seconds <= duration else { return .invalidValue }
            return .requested
        case .automix(let enabled):
            if automixEnabled == enabled { return .unchanged }
            guard !mixing else { return .unavailable }
            return .requested
        }
    }

    struct Receipt: Encodable {
        let version = 1
        let command: String
        let decision: Decision
        let status: RedBitAutomationStatus
        let volumePercent: Double?
        let automixEnabled: Bool?

        init(adjustment: RedBitAdjustment, decision: Decision,
             status: RedBitAutomationStatus, volume: Double, automixEnabled: Bool) {
            self.command = adjustment.command
            self.decision = decision
            self.status = status
            switch adjustment {
            case .volumePercent:
                self.volumePercent = volume.isFinite && (0...1).contains(volume) ? (volume * 100).rounded() : nil
                self.automixEnabled = nil
            case .automix:
                self.volumePercent = nil
                self.automixEnabled = automixEnabled
            case .seekSeconds:
                self.volumePercent = nil
                self.automixEnabled = nil
            }
        }

        func json() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return String(decoding: try encoder.encode(self), as: UTF8.self)
        }
    }
}
