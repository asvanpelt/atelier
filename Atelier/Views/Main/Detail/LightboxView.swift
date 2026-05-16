import SwiftUI
import AVKit
import AppKit

struct LightboxView: View {
    let assets: [Asset]
    @State var selectedIndex: Int
    var onClose: () -> Void
    var glassTint: Color = .clear

    @State private var player: AVPlayer?
    @FocusState private var isFocused: Bool
    @State private var zoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var panAtGestureStart: CGSize = .zero
    @State private var zoomAtGestureStart: CGFloat = 1.0
    @State private var isDraggingPan: Bool = false
    @State private var displayedImage: NSImage?
    @State private var displayedImageIsFull: Bool = false

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0

    var body: some View {
        if selectedIndex < assets.count {
            let asset = assets[selectedIndex]

            VStack(spacing: 0) {
                header(asset: asset)

                if asset.mediaType == .video {
                    videoPlayer(asset: asset)
                } else if let image = displayedImage {
                    zoomableImage(image)
                        .padding()
                        .layoutPriority(1)
                } else {
                    placeholder
                }

                infoBar(asset: asset)
            }
            .frame(width: idealSize(for: asset).width, height: idealSize(for: asset).height)
            .background(.ultraThickMaterial)
            .background(glassTint)
            .focusable()
            .focused($isFocused)
            .onAppear {
                isFocused = true
                Task { await loadFullImage(for: asset) }
            }
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
                resetZoom()
                let currentAsset = assets[selectedIndex]
                Task { await loadFullImage(for: currentAsset) }
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
    private func zoomableImage(_ image: NSImage) -> some View {
        GeometryReader { geo in
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoom)
                    .offset(pan)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: zoom)
                    .onHover { hovering in
                        if hovering && zoom > 1.0 {
                            (isDraggingPan ? NSCursor.closedHand : NSCursor.openHand).push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard zoom > 1.0 else { return }
                                if !isDraggingPan {
                                    isDraggingPan = true
                                    NSCursor.closedHand.push()
                                }
                                pan = CGSize(
                                    width: panAtGestureStart.width + value.translation.width,
                                    height: panAtGestureStart.height + value.translation.height
                                )
                                pan = clamp(pan: pan, viewSize: geo.size)
                            }
                            .onEnded { _ in
                                panAtGestureStart = pan
                                if isDraggingPan {
                                    isDraggingPan = false
                                    NSCursor.pop()
                                }
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newZoom = min(maxZoom, max(minZoom, zoomAtGestureStart * value))
                                zoom = newZoom
                                if zoom <= 1.0 {
                                    pan = .zero
                                } else {
                                    pan = clamp(pan: pan, viewSize: geo.size)
                                }
                            }
                            .onEnded { _ in
                                zoomAtGestureStart = zoom
                                panAtGestureStart = pan
                                if zoom <= 1.0 {
                                    resetZoom()
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        if zoom > 1.0 {
                            resetZoom()
                        } else {
                            zoom = 2.5
                            zoomAtGestureStart = 2.5
                        }
                    }

                ScrollWheelCatcher { deltaY, modifiers in
                    let sensitivity: CGFloat = 0.0035
                    let factor = 1 + deltaY * sensitivity
                    let newZoom = min(maxZoom, max(minZoom, zoom * factor))
                    zoom = newZoom
                    zoomAtGestureStart = newZoom
                    if zoom <= 1.0 {
                        pan = .zero
                        panAtGestureStart = .zero
                    } else {
                        pan = clamp(pan: pan, viewSize: geo.size)
                        panAtGestureStart = pan
                    }
                    _ = modifiers
                }
                .allowsHitTesting(true)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func clamp(pan: CGSize, viewSize: CGSize) -> CGSize {
        guard zoom > 1.0 else { return .zero }
        let maxX = (viewSize.width * (zoom - 1)) / 2
        let maxY = (viewSize.height * (zoom - 1)) / 2
        return CGSize(
            width: min(maxX, max(-maxX, pan.width)),
            height: min(maxY, max(-maxY, pan.height))
        )
    }

    private func resetZoom() {
        zoom = 1.0
        zoomAtGestureStart = 1.0
        pan = .zero
        panAtGestureStart = .zero
    }

    @ViewBuilder
    private func videoPlayer(asset: Asset) -> some View {
        VideoPlayer(player: playerForAsset(asset))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .onAppear {
                updatePlayer()
            }
    }

    @ViewBuilder
    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.largeTitle)
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

    @MainActor
    private func loadFullImage(for asset: Asset) async {
        guard asset.mediaType == .image else {
            displayedImage = nil
            displayedImageIsFull = false
            return
        }

        // 1) Placeholder instantáneo desde thumbnail.
        if let thumb = thumbnailImage(for: asset) {
            displayedImage = thumb
            displayedImageIsFull = false
        }

        let url = asset.fileURL
        let targetId = asset.id

        // 2) Cargar original en background.
        let full: NSImage? = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value

        // Sólo aplicar si el usuario no navegó a otro asset mientras tanto.
        guard selectedIndex < assets.count,
              assets[selectedIndex].id == targetId else { return }

        if let full {
            displayedImage = full
            displayedImageIsFull = true
        }
    }

    private func thumbnailImage(for asset: Asset) -> NSImage? {
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
        return nil
    }

    private func idealSize(for asset: Asset) -> CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let maxW = screen.width * 0.92
        let maxH = screen.height * 0.92
        let minW: CGFloat = 700
        let minH: CGFloat = 520
        let chrome: CGFloat = 96  // header + infoBar + paddings

        guard let w = asset.width, let h = asset.height, w > 0, h > 0 else {
            return CGSize(width: min(maxW, 1160), height: min(maxH, 850))
        }

        let aspect = CGFloat(w) / CGFloat(h)
        let availableImageH = maxH - chrome

        // Empezamos con la imagen llenando vertical, escalando ancho con aspecto.
        var imageH = availableImageH
        var imageW = imageH * aspect

        // Si no cabe horizontalmente, recortamos por ancho.
        if imageW > maxW {
            imageW = maxW
            imageH = imageW / aspect
        }

        let width = max(minW, min(maxW, imageW))
        let height = max(minH, min(maxH, imageH + chrome))
        return CGSize(width: width, height: height)
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

private struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (CGFloat, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollCatcherView: NSView {
    var onScroll: ((CGFloat, NSEvent.ModifierFlags) -> Void)?
    private var monitor: Any?

    // Transparente al mouse: hover, click y pinch atraviesan hacia la imagen.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard let myWindow = window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            guard event.window === myWindow else { return event }
            let viewFrameInWindow = self.convert(self.bounds, to: nil)
            let mouseInWindow = event.locationInWindow
            guard viewFrameInWindow.contains(mouseInWindow) else { return event }
            let delta = event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY
                : event.scrollingDeltaY * 12
            self.onScroll?(delta, event.modifierFlags)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    override func removeFromSuperview() {
        removeMonitor()
        super.removeFromSuperview()
    }
}
