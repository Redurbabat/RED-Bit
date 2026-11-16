#if os(iOS)
import SwiftUI
import UIKit

// Gekennzeichnete Beispielkarten für den Vorschau-Selbsttest (CI und
// Testzentrale). Synthetische Eingaben, keine echten App-Bildschirme.
enum LiquidPhotoFeature: Int, CaseIterable, Identifiable {
    case automix, lyrics, signal, eq, replay, queue, downloads, output, party
    case canvas, handoff, echo, island, dock, portal
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .automix: "Automix Weave"
        case .lyrics: "Lyrics Mirror"
        case .signal: "Signal Prism"
        case .eq: "EQ Membrane"
        case .replay: "Replay Time River"
        case .queue: "Queue Horizon"
        case .downloads: "Download Bloom"
        case .output: "Output Halo"
        case .party: "Party Constellation"
        case .canvas: "Canvas Veil"
        case .handoff: "Handoff Comet"
        case .echo: "Echo Trail"
        case .island: "Music Island"
        case .dock: "Player-Werkzeuge"
        case .portal: "Glass Portal"
        }
    }
    var location: String {
        switch self {
        case .automix: "Player · Automix"
        case .lyrics: "Player · Songtexte"
        case .signal: "Audio-Pipeline"
        case .eq: "Equalizer"
        case .replay: "Replay"
        case .queue: "Player · Warteschlange"
        case .downloads: "Download-Manager"
        case .output: "Player · Audioausgabe"
        case .party: "Listen Together"
        case .canvas: "Player · Canvas"
        case .handoff: "Handoff · Geräteübergabe"
        case .echo: "Player · Verlauf"
        case .island: "Startseite · Mini-Player"
        case .dock: "Player · Werkzeugleiste"
        case .portal: "Player · Queue-Portal"
        }
    }
    var symbol: String {
        switch self {
        case .automix, .signal: "waveform.path"
        case .lyrics: "text.quote"
        case .eq: "slider.vertical.3"
        case .replay: "chart.bar.xaxis"
        case .queue, .portal: "list.bullet.rectangle"
        case .downloads: "arrow.down.circle"
        case .output: "headphones"
        case .party: "person.3"
        case .canvas: "square.on.square.dashed"
        case .handoff: "arrow.right.circle"
        case .echo: "arrow.uturn.backward"
        case .island: "music.note"
        case .dock: "square.stack.3d.up"
        }
    }
}

struct LiquidPhotoCard: View {
    let feature: LiquidPhotoFeature

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("BBT-BIT", systemImage: "waveform")
                    .font(.caption.weight(.heavy)).tracking(2)
                Spacer()
                Text("DESIGN-FOTOS").font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "%02d / 15", feature.rawValue + 1))
                    .font(.caption.monospacedDigit()).foregroundStyle(.cyan)
                Text(feature.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Label(feature.location, systemImage: "mappin")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 20)
            preview
                .environment(\.liquidDesignSample, true)
                .frame(maxWidth: .infinity)
                .padding(15)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 6) {
                Label("DESIGN-VORSCHAU · BEISPIELDATEN", systemImage: "info.circle")
                    .font(.caption.weight(.bold))
                Text("Auf diesem iPhone gerendert. Kein echter Screenshot eines Songübergangs, einer Party oder eines Handoff-Ereignisses.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(width: 390, height: 780)
        .background {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.10)
                RadialGradient(colors: [.purple.opacity(0.35), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 460)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var preview: some View {
        switch feature {
        case .automix:
            AutomixWeave(start: 180, end: 200, position: 190,
                         tier: "Beat matched", reason: "Demo-Übergang", isMixing: true)
        case .lyrics:
            LyricsMirror(original: "Wir hören den Rhythmus", translation: "We hear the rhythm")
        case .signal:
            SignalPrism(source: "Beispiel-Stream", decoder: "AAC",
                        processing: "EQ · Stereo", output: "iPhone")
        case .eq:
            EQMembrane(bands: .constant([-2.0, 0, 3, 5, 2, -1, 1]), enabled: false)
        case .replay:
            ReplayTimeRiver(hourlyValues: (0..<24).map { Double(($0 * 21 + 11) % 65) * 60_000 })
        case .downloads:
            DownloadBloom(active: 2, finished: 3, failed: 0)
        case .output:
            VStack(spacing: 10) {
                OutputHaloGlyph(routeName: "iPhone", spatialEnabled: true)
                Text("Audioausgabe · iPhone").font(.caption)
            }
        case .handoff:
            HandoffComet(title: "Beispiel-Song")
        case .dock:
            InfinityDock(automixEnabled: true, onLyrics: {}, onQueue: {},
                         onOutput: {}, onEqualizer: {}, onPipeline: {}, onAutomix: {})
        case .queue:
            illustration(title: "ON THE HORIZON", icon: "music.note.list", names: ["Song 1", "Song 2", "Song 3"])
        case .party:
            illustration(title: "LISTENER CONSTELLATION", icon: "person.3.fill", names: ["Host", "Gast 1", "Gast 2"])
        case .canvas:
            illustration(title: "COVER ↔ CANVAS", icon: "square.on.square.dashed", names: ["Albumcover", "Canvas"])
        case .echo:
            illustration(title: "ECHO TRAIL", icon: "arrow.uturn.backward", names: ["Vorheriger Song"])
        case .island:
            illustration(title: "MUSIC ISLAND", icon: "waveform", names: ["Beispiel-Song", "Play / Pause"])
        case .portal:
            illustration(title: "QUEUE PORTAL", icon: "list.bullet", names: ["Song 1", "Song 2", "Warteschlange öffnen"])
        }
    }

    private func illustration(title: String, icon: String, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon).foregroundStyle(.cyan)
                Text(title).font(.caption.weight(.bold)).tracking(1.1)
            }
            ForEach(names, id: \.self) { name in
                HStack {
                    Image(systemName: "music.note")
                        .frame(width: 32, height: 32)
                        .background(.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                    Text(name).font(.subheadline)
                    Spacer()
                }
                .padding(8)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            }
            Text("Schematische Darstellung")
                .font(.caption2).foregroundStyle(.white.opacity(0.56))
        }
        .padding(10)
    }
}
#endif
