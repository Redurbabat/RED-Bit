#if os(iOS)
import SwiftUI
import RedBitShared
import UIKit

/// A single color sampling path for the mini-player and its full-screen
/// destination. Uses the existing artwork cache instead of fetching artwork
/// every frame, and never invents an audio-progress value.
@MainActor
private enum CoverMorphArtwork {
    static func colors(for entry: QueueEntry?) -> ArtworkPalette.PageTint {
        ArtworkPalette.pageTint(
            from: entry?.artworkData,
            seed: entry?.id.hashValue ?? 0
        )
    }

    static func artworkBytes(for entry: QueueEntry?) async -> Data? {
        guard let entry else { return nil }
        if let bytes = entry.artworkData { return bytes }
        guard let url = entry.thumbnailUrl else { return nil }
        let sized = SharedArtwork.sized(url, 120) ?? url
        guard let image = await ArtworkCache.shared.load(sized) else { return nil }
        return image.jpegData(compressionQuality: 0.60)
    }
}

/// The expanded player must receive the *same actual artwork palette* as the
/// mini-player. Existing MeshBackdrop handles the full-page motion and allows
/// the native zoom to morph between two visually related surfaces.
struct CoverMorphFullBackdrop: View {
    let entry: QueueEntry?
    @State private var artwork: Data?

    var body: some View {
        MeshBackdrop(
            seed: entry?.id.hashValue ?? 0,
            artwork: artwork ?? entry?.artworkData
        )
        .task(id: entry?.id) {
            artwork = nil
            guard let bytes = await CoverMorphArtwork.artworkBytes(for: entry) else { return }
            guard !Task.isCancelled else { return }
            artwork = bytes
        }
    }
}
#endif
