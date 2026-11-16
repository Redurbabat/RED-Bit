#if os(iOS)
import SwiftUI

/// Small, accessible play-state indicator with subtle kinetic bars.
struct GlassBloomSignalBars: View {
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rising = false

    private let low: [CGFloat] = [5, 8, 5, 7]
    private let high: [CGFloat] = [12, 8, 15, 10]

    private var motionAllowed: Bool {
        playing && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(playing ? Color.primary : Color.secondary)
                    .frame(width: 2.7, height: rising ? high[index] : low[index])
            }
        }
        .frame(width: 24, height: 18)
        .accessibilityLabel(playing ? "Musik läuft" : "Musik pausiert")
        .onAppear(perform: updateAnimation)
        .onChange(of: playing) { _, _ in updateAnimation() }
        .onChange(of: reduceMotion) { _, _ in updateAnimation() }
        .animation(
            motionAllowed ? .easeInOut(duration: 0.86).repeatForever(autoreverses: true) : nil,
            value: rising
        )
    }

    private func updateAnimation() {
        rising = motionAllowed
    }
}

/// Distinct visual hierarchy underneath the cover/title:
/// audio status first, then transport controls, then optional deep links.
struct GlassBloomStatusRow: View {
    let playing: Bool

    var body: some View {
        HStack(spacing: 8) {
            GlassBloomSignalBars(playing: playing)
            Text(playing ? "JETZT LÄUFT" : "PAUSIERT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Image(systemName: "sparkle")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct GlassBloomSwipeHint: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right")
            Text("Wischen: Titel")
            Spacer()
            Image(systemName: "arrow.up.arrow.down")
            Text("Auf / Zu")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityLabel("Horizontal wischen wechselt Titel; nach oben ausklappen und nach unten schließen.")
    }
}
#endif
