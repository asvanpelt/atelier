import SwiftUI
import AppKit

struct AssetThumbnailTile: View {
    let asset: Asset
    let thumbnailService: ThumbnailService
    let size: CGFloat

    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.4 : 0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovering ? 0.22 : 0.08), radius: isHovering ? 6 : 2, y: 1)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .task(id: asset.id) { await load() }
    }

    private func load() async {
        let cached = await thumbnailService.thumbnail(for: asset, size: 400)
        let url: URL?
        if let cached {
            url = cached
        } else {
            url = (try? await thumbnailService.generateSingle(for: asset, size: 400)) ?? nil
        }
        guard let url else { return }
        let loaded = await Self.loadImage(url: url)
        await MainActor.run { self.image = loaded }
    }

    nonisolated static func loadImage(url: URL) async -> NSImage? {
        NSImage(contentsOf: url)
    }
}
