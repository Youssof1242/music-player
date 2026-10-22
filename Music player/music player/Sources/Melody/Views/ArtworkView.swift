import SwiftUI
import AppKit

struct ArtworkView: View {
    let track: Track?
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 8

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: track?.id) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .quaternaryLabelColor),
                Color(nsColor: .tertiaryLabelColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage() async {
        guard let track else {
            image = nil
            return
        }
        if let data = track.artworkData, let img = NSImage(data: data) {
            image = img
            return
        }
        let id = track.id
        let data = await Task.detached(priority: .utility) {
            ArtworkCache.load(for: id)
        }.value
        if let data {
            image = NSImage(data: data)
        } else {
            image = nil
        }
    }
}
