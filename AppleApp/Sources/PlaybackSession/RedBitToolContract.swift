import Foundation
import CoreFoundation

/// Versionierter lokaler Werkzeugvertrag. Weder Netzwerk-Listener noch
/// MCP-Authentifizierung: nur der authentifizierte App Intent ruft den
/// bestehenden, einwilligungsgeprüften Controller-Pfad auf.
enum RedBitToolContract {
    enum Tool: String, CaseIterable {
        case status = "redbit_read_status"
        case queue = "redbit_read_queue"
        case play = "redbit_play"
        case pause = "redbit_pause"
        case next = "redbit_next"
        case previous = "redbit_previous"
        case volume = "redbit_set_volume"
        case seek = "redbit_seek"
        case automix = "redbit_set_automix"
        case equalizer = "redbit_set_equalizer"
        case quality = "redbit_set_quality"
        case shuffle = "redbit_set_shuffle"

        var scope: RedBitLocalAutomationConsent.Scope {
            switch self {
            case .status, .queue: return .status
            case .play, .pause, .next, .previous, .volume, .seek: return .transport
            case .automix, .equalizer, .quality, .shuffle: return .preferences
            }
        }

        var description: String {
            switch self {
            case .status: return "Read limited playback state."
            case .queue: return "Read queue counts without song details."
            case .play: return "Resume the selected track."
            case .pause: return "Pause playback."
            case .next: return "Request the next track."
            case .previous: return "Request the normal previous-track action."
            case .volume: return "Set app volume, not system volume."
            case .seek: return "Request an absolute position within a loaded track."
            case .automix: return "Set the saved Automix preference."
            case .equalizer: return "Set the saved equalizer preference."
            case .quality: return "Set streaming quality for the selected network."
            case .shuffle: return "Set shuffle explicitly."
            }
        }

        var properties: [String: [String: Any]] {
            switch self {
            case .volume: return ["percent": ["type": "number", "minimum": 0, "maximum": 100]]
            case .seek: return ["seconds": ["type": "number", "minimum": 0]]
            case .automix: return ["enabled": ["type": "boolean"]]
            case .equalizer: return ["enabled": ["type": "boolean"]]
            case .quality: return ["quality": ["type": "string", "enum": ["LOW","MEDIUM","HIGH","LOSSLESS"]], "metered": ["type": "boolean"]]
            case .shuffle: return ["enabled": ["type": "boolean"]]
            default: return [:]
            }
        }

        var inputSchema: [String: Any] {
            ["type": "object", "properties": properties,
             "required": properties.keys.sorted(), "additionalProperties": false]
        }

        var descriptor: [String: Any] {
            ["name": rawValue, "description": description, "scope": scope.rawValue,
             "readOnly": scope == .status, "inputSchema": inputSchema]
        }
    }

    enum Invocation {
        case status, queue
        case transport(RedBitTransportCommand)
        case adjustment(RedBitAdjustment)
        case preference(RedBitAutomationPreference)
    }

    enum InputError: Error, Equatable {
        case unknownTool, invalidArguments
    }

    static func catalogJSON() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "version": 1, "app": "red-bit", "transport": "local-app-intent",
            "remoteAvailable": false, "tools": Tool.allCases.map(\.descriptor)
        ], options: [.sortedKeys])
    }

    /// Keine String-/Bool-Konvertierung von Zahlen und keine unbekannten
    /// Felder. Argumente sind klein, nur JSON-Objekte und feste Typen erlaubt.
    static func parse(tool: Tool, arguments: String) throws -> Invocation {
        guard arguments.utf8.count <= 4096,
              let object = try? JSONSerialization.jsonObject(with: Data(arguments.utf8)),
              let fields = object as? [String: Any],
              Set(fields.keys) == Set(tool.properties.keys) else {
            throw InputError.invalidArguments
        }
        func number(_ key: String) throws -> Double {
            guard let n = fields[key] as? NSNumber,
                  CFGetTypeID(n) != CFBooleanGetTypeID(),
                  n.doubleValue.isFinite else { throw InputError.invalidArguments }
            return n.doubleValue
        }
        func boolean(_ key: String) throws -> Bool {
            guard let n = fields[key] as? NSNumber,
                  CFGetTypeID(n) == CFBooleanGetTypeID() else { throw InputError.invalidArguments }
            return n.boolValue
        }
        switch tool {
        case .status: return .status
        case .queue: return .queue
        case .play: return .transport(.play)
        case .pause: return .transport(.pause)
        case .next: return .transport(.next)
        case .previous: return .transport(.previous)
        case .volume:
            let value = try number("percent")
            guard (0...100).contains(value) else { throw InputError.invalidArguments }
            return .adjustment(.volumePercent(value))
        case .seek:
            let value = try number("seconds")
            guard value >= 0 else { throw InputError.invalidArguments }
            return .adjustment(.seekSeconds(value))
        case .automix: return .adjustment(.automix(try boolean("enabled")))
        case .equalizer: return .preference(.equalizer(try boolean("enabled")))
        case .shuffle: return .preference(.shuffle(try boolean("enabled")))
        case .quality:
            guard let quality = fields["quality"] as? String,
                  RedBitAutomationPreference.Quality(rawValue: quality) != nil else { throw InputError.invalidArguments }
            return .preference(.streamQuality(quality, metered: try boolean("metered")))
        }
    }
}
