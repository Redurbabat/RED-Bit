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

/// Nur explizite Audio-/Queue-Einstellungen, keine freien Kommandos.
enum RedBitAutomationPreference {
    case equalizer(Bool)
    case streamQuality(String, metered: Bool)
    case shuffle(Bool)

    enum Decision: String, Encodable {
        case requested, unchanged, locked, unavailable, invalidValue
    }

    enum Quality: String, CaseIterable {
        case low = "LOW", medium = "MEDIUM", high = "HIGH", lossless = "LOSSLESS"
    }

    var command: String {
        switch self {
        case .equalizer: return "setEqualizer"
        case .streamQuality: return "setStreamQuality"
        case .shuffle: return "setShuffle"
        }
    }

    func decision(locked: Bool, mixing: Bool, equalizer: Bool,
                  wifiQuality: String, cellularQuality: String, shuffle: Bool) -> Decision {
        guard !locked else { return .locked }
        switch self {
        case .equalizer(let enabled):
            return equalizer == enabled ? .unchanged : .requested
        case .streamQuality(let value, let metered):
            guard Quality(rawValue: value) != nil else { return .invalidValue }
            return value == (metered ? cellularQuality : wifiQuality) ? .unchanged : .requested
        case .shuffle(let enabled):
            if shuffle == enabled { return .unchanged }
            return mixing ? .unavailable : .requested
        }
    }

    struct Receipt: Encodable {
        let version = 1
        let command: String
        let decision: Decision
        let equalizerEnabled: Bool?
        let shuffleEnabled: Bool?
        let requestedQuality: String?
        let metered: Bool?

        init(preference: RedBitAutomationPreference, decision: Decision,
             equalizer: Bool, wifiQuality: String, cellularQuality: String, shuffle: Bool) {
            self.command = preference.command
            self.decision = decision
            switch preference {
            case .equalizer:
                equalizerEnabled = equalizer; shuffleEnabled = nil; requestedQuality = nil; metered = nil
            case .streamQuality(_, let mobile):
                equalizerEnabled = nil; shuffleEnabled = nil
                requestedQuality = Quality(rawValue: mobile ? cellularQuality : wifiQuality)?.rawValue
                metered = mobile
            case .shuffle:
                equalizerEnabled = nil; shuffleEnabled = shuffle; requestedQuality = nil; metered = nil
            }
        }

        func json() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return String(decoding: try encoder.encode(self), as: UTF8.self)
        }
    }
}

/// Aggregate statt Titelliste; verrät keine Titel, IDs oder Dateipfade.
struct RedBitQueueSummary: Encodable {
    let version = 1
    let total: Int
    let upcoming: Int
    let automaticUpcoming: Int
    let manualUpcoming: Int
    let shuffleEnabled: Bool
    let controlsLocked: Bool

    init(total: Int, upcoming: Int, automaticUpcoming: Int, shuffleEnabled: Bool, controlsLocked: Bool) {
        self.total = max(0, total)
        self.upcoming = min(max(0, upcoming), self.total)
        self.automaticUpcoming = min(max(0, automaticUpcoming), self.upcoming)
        self.manualUpcoming = self.upcoming - self.automaticUpcoming
        self.shuffleEnabled = shuffleEnabled
        self.controlsLocked = controlsLocked
    }

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

extension Notification.Name {
    static let redBitAutomationPreferencesChanged = Notification.Name("redbit.automation.preferences.changed")
}

/// Lokale Einwilligung pro Installationsprofil. Kein RED-ID-Scope,
/// kein Cloud-Grant und keine Berechtigung für einen entfernten Client.
enum RedBitLocalAutomationConsent {
    enum Scope: String, CaseIterable {
        case status, transport, preferences

        var key: String { "red.bit.automation.local.v1." + rawValue }
    }

    static func isEnabled(_ scope: Scope, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: scope.key) as? Bool == true
    }

    static func allows(_ scope: Scope, defaults: UserDefaults = .standard) -> Bool {
        // Alle neuen Aktionsquittungen können private Zustandsdaten enthalten.
        // Status ist deshalb zwingend, auch für schreibende Aktionen.
        guard isEnabled(.status, defaults: defaults) else { return false }
        return scope == .status || isEnabled(scope, defaults: defaults)
    }

    static func set(_ scope: Scope, enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: scope.key)
        if scope == .status && !enabled {
            // Erneute Freigabe des Lesens darf alte Schreibrechte nicht reaktivieren.
            defaults.set(false, forKey: Scope.transport.key)
            defaults.set(false, forKey: Scope.preferences.key)
        }
    }

    static func revokeAll(defaults: UserDefaults = .standard) {
        for scope in Scope.allCases { defaults.set(false, forKey: scope.key) }
    }
}
