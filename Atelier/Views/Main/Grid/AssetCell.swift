import AppKit
import UniformTypeIdentifiers

final class AssetCell: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("AssetCell")

    private let thumbnailView = NSImageView()
    private let videoBadge = NSTextField()
    private let selectionOverlay = NSView()
    private var trackingArea: NSTrackingArea?
    private var currentAsset: Asset?
    private var mouseDownLocation: NSPoint?
    private static let dragThreshold: CGFloat = 6

    var onShowInFinder: ((Asset) -> Void)?
    var onOpenWith: ((Asset) -> Void)?
    var onDoubleClick: ((Asset) -> Void)?
    var isBlurred = true

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true

        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailView)

        selectionOverlay.wantsLayer = true
        selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        selectionOverlay.layer?.borderColor = NSColor.controlAccentColor.cgColor
        selectionOverlay.layer?.borderWidth = 2
        selectionOverlay.layer?.cornerRadius = 6
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.isHidden = true
        view.addSubview(selectionOverlay)

        videoBadge.isEditable = false
        videoBadge.isBordered = false
        videoBadge.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        videoBadge.textColor = .white
        videoBadge.font = .systemFont(ofSize: 9, weight: .medium)
        videoBadge.alignment = .center
        videoBadge.translatesAutoresizingMaskIntoConstraints = false
        videoBadge.wantsLayer = true
        videoBadge.layer?.cornerRadius = 3
        videoBadge.isHidden = true
        view.addSubview(videoBadge)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: view.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectionOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            videoBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            videoBadge.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            videoBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])
    }

    override var isSelected: Bool {
        didSet {
            selectionOverlay.isHidden = !isSelected
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTrackingArea()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        videoBadge.isHidden = true
        selectionOverlay.isHidden = true
        currentAsset = nil
    }

    func configure(with asset: Asset) {
        currentAsset = asset

        if asset.mediaType == .video, let durationMs = asset.durationMs {
            let totalSec = durationMs / 1000
            let secs = totalSec % 60
            videoBadge.stringValue = " \(totalSec / 60):\(secs < 10 ? "0" : "")\(secs) "
            videoBadge.isHidden = false
        } else if asset.mediaType == .video {
            videoBadge.stringValue = " ▶ "
            videoBadge.isHidden = false
        } else {
            videoBadge.isHidden = true
        }

        updateBlur()

        let hashPrefix = String(asset.fileHash.prefix(8))
        let thumbPath = AppConstants.thumbnailsDir
            .appendingPathComponent("400")
            .appendingPathComponent(hashPrefix)
            .appendingPathComponent("\(asset.id ?? 0).jpg")

        let filePath = asset.filePath
        Task { @MainActor [weak self] in
            let image = await Self.loadImage(thumbPath: thumbPath, filePath: filePath)
            self?.thumbnailView.image = image
        }
    }

    nonisolated private static func loadImage(thumbPath: URL, filePath: String) async -> NSImage? {
        if FileManager.default.fileExists(atPath: thumbPath.path) {
            return NSImage(contentsOf: thumbPath)
        } else {
            let icon = NSWorkspace.shared.icon(forFile: filePath)
            icon.size = NSSize(width: 200, height: 200)
            return icon
        }
    }

    // MARK: - Blur

    func updateBlur() {
        if isBlurred {
            guard let filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 12]) else { return }
            thumbnailView.contentFilters = [filter]
        } else {
            thumbnailView.contentFilters = []
        }
    }

    // MARK: - Hover

    private func updateTrackingArea() {
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            view.animator().layer?.transform = CATransform3DMakeScale(1.04, 1.04, 1)
        }
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.15
        view.layer?.shadowRadius = 8
        view.layer?.shadowOffset = CGSize(width: 0, height: -2)
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            view.animator().layer?.transform = CATransform3DIdentity
        }
        view.layer?.shadowOpacity = 0
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        guard let asset = currentAsset else { return }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Mostrar en Finder", action: #selector(showInFinderAction), keyEquivalent: "")
        showItem.target = self
        showItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(showItem)

        let openItem = NSMenuItem(title: "Abrir con...", action: #selector(openWithAction), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
        menu.addItem(openItem)

        menu.addItem(.separator())

        let copyImage = NSMenuItem(title: "Copiar imagen", action: #selector(copyImageAction), keyEquivalent: "c")
        copyImage.target = self
        copyImage.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)
        copyImage.isEnabled = asset.mediaType == .image
        menu.addItem(copyImage)

        let copyPath = NSMenuItem(title: "Copiar ruta", action: #selector(copyPathAction), keyEquivalent: "")
        copyPath.target = self
        copyPath.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        menu.addItem(copyPath)

        if let w = asset.width, let h = asset.height {
            menu.addItem(.separator())
            let infoItem = NSMenuItem(title: "\(w)×\(h) · \(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))", action: nil, keyEquivalent: "")
            infoItem.isEnabled = false
            menu.addItem(infoItem)
        }

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func showInFinderAction() {
        guard let asset = currentAsset else { return }
        NSWorkspace.shared.selectFile(asset.filePath, inFileViewerRootedAtPath: "")
    }

    @objc private func openWithAction() {
        guard let asset = currentAsset else { return }
        NSWorkspace.shared.open(asset.fileURL)
    }

    @objc private func copyImageAction() {
        guard let asset = currentAsset, asset.mediaType == .image else { return }
        guard let image = NSImage(contentsOf: asset.fileURL) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    @objc private func copyPathAction() {
        guard let asset = currentAsset else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.filePath, forType: .string)
    }

    // MARK: - Drag

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let asset = currentAsset {
            mouseDownLocation = nil
            onDoubleClick?(asset)
            return
        }
        mouseDownLocation = event.locationInWindow
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
        super.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let asset = currentAsset, let start = mouseDownLocation else { return }
        let dx = event.locationInWindow.x - start.x
        let dy = event.locationInWindow.y - start.y
        guard (dx * dx + dy * dy) >= (Self.dragThreshold * Self.dragThreshold) else { return }

        let fileURL = asset.fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        mouseDownLocation = nil
        let dragItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let iconImage = thumbnailView.image ?? NSWorkspace.shared.icon(forFile: asset.filePath)
        dragItem.setDraggingFrame(view.bounds, contents: iconImage)
        view.beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

extension AssetCell: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : .move
    }
}
