import SwiftUI
import AVKit

struct LightboxView: View {
    let assets: [Asset]
    @State var selectedIndex: Int
    var onClose: () -> Void

    @State private var player: AVPlayer?
    @FocusState private var isFocused: Bool

    var body: some View {
        if selectedIndex < assets.count {
            let asset = assets[selectedIndex]

            VStack(spacing: 0) {
                header(asset: asset)

                if asset.mediaType == .video {
                    videoPlayer(asset: asset)
                } else if let image = loadImage(for: asset) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    placeholder
                }

                infoBar(asset: asset)
            }
            .frame(minWidth: 700, minHeight: 500)
            .background(.ultraThinMaterial)
            .focusable()
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onKeyPress(.leftArrow) {
                navigate(by: -1)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                navigate(by: 1)
                return .handled
            }
            .onKeyPress(.escape) {
                onClose()
                return .handled
            }
            .onKeyPress(.space) {
                togglePlayPause()
                return .handled
            }
            .onCopyCommand {
                let asset = assets[selectedIndex]
                guard asset.mediaType == .image else { return [] }
                copyImage(asset: asset)
                return []
            }
            .onChange(of: selectedIndex) { _, _ in
                updatePlayer()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    @ViewBuilder
    private func header(asset: Asset) -> some View {
        HStack {
            Button("Anterior", systemImage: "chevron.left", action: { navigate(by: -1) })
            .labelStyle(.iconOnly)
            .disabled(selectedIndex == 0)
            .buttonStyle(.borderless)

            Spacer()

            Text(URL(fileURLWithPath: asset.filePath).lastPathComponent)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Text("\(selectedIndex + 1) de \(assets.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Siguiente", systemImage: "chevron.right", action: { navigate(by: 1) })
            .labelStyle(.iconOnly)
            .disabled(selectedIndex >= assets.count - 1)
            .buttonStyle(.borderless)

            Spacer().frame(width: 16)

            if asset.mediaType == .image {
                Button("Copiar imagen", systemImage: "doc.on.doc", action: { copyImage(asset: asset) })
                .labelStyle(.iconOnly)
                .font(.body)
                .buttonStyle(.borderless)
                .help("Copiar imagen (⌘C)")
            }

            Button("Cerrar", systemImage: "xmark.circle.fill", action: onClose)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func videoPlayer(asset: Asset) -> some View {
        VideoPlayer(player: playerForAsset(asset))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                updatePlayer()
            }
    }

    @ViewBuilder
    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 80))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func infoBar(asset: Asset) -> some View {
        HStack(spacing: 12) {
            if let width = asset.width, let height = asset.height {
                Label("\(width)×\(height)", systemImage: "aspectratio")
            }
            if let durationMs = asset.durationMs {
                Label(formatDuration(durationMs), systemImage: "clock")
            }
            Label(asset.mimeType, systemImage: "doc")
            Label(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file), systemImage: "internaldrive")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    private func navigate(by offset: Int) {
        let newIndex = selectedIndex + offset
        guard newIndex >= 0, newIndex < assets.count else { return }
        player?.pause()
        selectedIndex = newIndex
    }

    private func togglePlayPause() {
        guard let player, assets[selectedIndex].mediaType == .video else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func playerForAsset(_ asset: Asset) -> AVPlayer {
        if let player { return player }
        let newPlayer = AVPlayer(url: asset.fileURL)
        player = newPlayer
        return newPlayer
    }

    private func updatePlayer() {
        guard selectedIndex < assets.count else { return }
        let asset = assets[selectedIndex]
        if asset.mediaType == .video {
            let newPlayer = AVPlayer(url: asset.fileURL)
            player = newPlayer
            newPlayer.play()
        } else {
            player?.pause()
            player = nil
        }
    }

    private func copyImage(asset: Asset) {
        guard let image = NSImage(contentsOf: asset.fileURL) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    private func loadImage(for asset: Asset) -> NSImage? {
        let hashPrefix = String(asset.fileHash.prefix(8))
        for size in [800, 400, 200] {
            let url = AppConstants.thumbnailsDir
                .appendingPathComponent("\(size)")
                .appendingPathComponent(hashPrefix)
                .appendingPathComponent("\(asset.id ?? 0).jpg")
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return NSImage(contentsOf: asset.fileURL)
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
