import SwiftUI
import AppKit

struct FaceThumbnailView: View {
    let face: FaceObservation
    let assetRepo: AssetRepository
    let thumbnailService: ThumbnailService
    let size: CGFloat

    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.45 : 0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovering ? 0.25 : 0.10), radius: isHovering ? 8 : 3, y: 2)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .task(id: face.id) { await load() }
    }

    private func load() async {
        guard let asset = (try? await assetRepo.find(id: face.assetId)) ?? nil else { return }
        let cached = await thumbnailService.thumbnail(for: asset, size: 512)
        let url: URL?
        if let cached {
            url = cached
        } else {
            url = (try? await thumbnailService.generateSingle(for: asset, size: 512)) ?? nil
        }
        let source = url ?? asset.fileURL
        let cropped = await Self.crop(source: source, face: face, output: size * 2)
        await MainActor.run { self.image = cropped }
    }

    nonisolated static func crop(source: URL, face: FaceObservation, output: CGFloat) async -> NSImage? {
        guard let image = NSImage(contentsOf: source) else { return nil }
        let imgSize = image.size
        let pad: Double = 0.15
        let cx = face.bboxX + face.bboxW / 2
        let cy = face.bboxY + face.bboxH / 2
        let side = max(face.bboxW, face.bboxH) * (1 + pad)
        let nx = max(0, cx - side / 2)
        let ny = max(0, cy - side / 2)
        let nw = min(side, 1 - nx)
        let nh = min(side, 1 - ny)

        let rect = CGRect(
            x: nx * imgSize.width,
            y: ny * imgSize.height,
            width: nw * imgSize.width,
            height: nh * imgSize.height
        )

        let result = NSImage(size: NSSize(width: output, height: output))
        result.lockFocus()
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: output, height: output).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: output, height: output),
            from: rect,
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }
}
