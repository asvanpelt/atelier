import SwiftUI

struct InspectorPanel: View {
    let asset: Asset
    let tagRepo: TagRepository
    let visionRepo: VisionRepository

    @State private var assetTags: [(tag: Tag, source: String, confidence: Double?)] = []
    @State private var classifications: [VisionClassification] = []
    @State private var ocrText: String?
    @State private var faceCount = 0
    @State private var showAddTag = false
    @State private var newTagText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                fileInfo
                tagsSection
                visionSection
                metadataSection
                actionsSection
            }
            .padding()
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .task(id: asset.id) {
            await loadVisionData()
        }
    }

    @ViewBuilder
    private var preview: some View {
        let hashPrefix = String(asset.fileHash.prefix(8))
        let thumbURL = AppConstants.thumbnailsDir
            .appendingPathComponent("400")
            .appendingPathComponent(hashPrefix)
            .appendingPathComponent("\(asset.id ?? 0).jpg")

        if let image = NSImage(contentsOf: thumbURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(8)
                .contextMenu {
                    if asset.mediaType == .image {
                        Button("Copiar imagen") {
                            guard let fullImage = NSImage(contentsOf: asset.fileURL) else { return }
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.writeObjects([fullImage])
                        }
                    }
                    Button("Mostrar en Finder") {
                        showInFinder()
                    }
                }
        }
    }

    @ViewBuilder
    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(URL(fileURLWithPath: asset.filePath).lastPathComponent)
                .font(.headline)
                .lineLimit(2)

            Text(URL(fileURLWithPath: asset.filePath).deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Información")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, verticalSpacing: 4) {
                GridRow {
                    Text("Tipo").foregroundStyle(.secondary)
                    Text(asset.mimeType)
                }
                GridRow {
                    Text("Tamaño").foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))
                }
                if let w = asset.width, let h = asset.height {
                    GridRow {
                        Text("Dimensiones").foregroundStyle(.secondary)
                        Text("\(w) × \(h)")
                    }
                }
                if let ms = asset.durationMs {
                    GridRow {
                        Text("Duración").foregroundStyle(.secondary)
                        Text(formatDuration(ms))
                    }
                }
                GridRow {
                    Text("Creado").foregroundStyle(.secondary)
                    Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                GridRow {
                    Text("Modificado").foregroundStyle(.secondary)
                    Text(asset.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let indexedAt = asset.indexedAt {
                    GridRow {
                        Text("Indexado").foregroundStyle(.secondary)
                        Text(indexedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                GridRow {
                    Text("Hash").foregroundStyle(.secondary)
                    Text(String(asset.fileHash.prefix(16)) + "...")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { showAddTag.toggle() }) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            FlowLayout(spacing: 4) {
                ForEach(assetTags, id: \.tag.id) { item in
                    TagChip(
                        tag: item.tag,
                        source: item.source,
                        confidence: item.confidence,
                        onRemove: {
                            Task {
                                guard let assetId = asset.id, let tagId = item.tag.id else { return }
                                try? await tagRepo.removeTag(assetId: assetId, tagId: tagId)
                                await loadVisionData()
                            }
                        }
                    )
                }
            }

            if showAddTag {
                HStack {
                    TextField("namespace:valor", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { Task { await addTag() } }
                    Button("Agregar") { Task { await addTag() } }
                        .font(.caption)
                        .disabled(newTagText.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var visionSection: some View {
        if !classifications.isEmpty || ocrText != nil || faceCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vision")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !classifications.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clasificaciones")
                            .font(.caption.weight(.medium))
                        FlowLayout(spacing: 4) {
                            ForEach(classifications.prefix(10), id: \.label) { c in
                                Text(c.label)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(c.confidence * 0.4))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                if let text = ocrText, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Texto detectado (OCR)")
                            .font(.caption.weight(.medium))
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                            .textSelection(.enabled)
                    }
                }

                if faceCount > 0 {
                    Label("\(faceCount) cara\(faceCount == 1 ? "" : "s") detectada\(faceCount == 1 ? "" : "s")", systemImage: "person.crop.rectangle")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acciones")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: showInFinder) {
                Label("Mostrar en Finder", systemImage: "folder")
            }
            .buttonStyle(.borderless)

            Button(action: openWithDefault) {
                Label("Abrir con app predeterminada", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)

            Button(action: copyPath) {
                Label("Copiar ruta completa", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
    }

    private func showInFinder() {
        NSWorkspace.shared.selectFile(asset.filePath, inFileViewerRootedAtPath: "")
    }

    private func openWithDefault() {
        NSWorkspace.shared.open(asset.fileURL)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.filePath, forType: .string)
    }

    private func loadVisionData() async {
        guard let assetId = asset.id else { return }
        do {
            assetTags = try await tagRepo.tagsFor(assetId: assetId)
            classifications = try await visionRepo.classificationsFor(assetId: assetId)
            ocrText = try await visionRepo.ocrTextFor(assetId: assetId)
            let faces = try await visionRepo.facesFor(assetId: assetId)
            faceCount = faces.count
        } catch {
            Logger.ui.error("Error cargando datos de Vision: \(error)")
        }
    }

    private func addTag() async {
        guard let assetId = asset.id, !newTagText.isEmpty else { return }
        let parts = newTagText.split(separator: ":", maxSplits: 1)
        let namespace: String?
        let value: String
        if parts.count == 2 {
            namespace = String(parts[0])
            value = String(parts[1])
        } else {
            namespace = nil
            value = newTagText
        }

        do {
            let tag = try await tagRepo.findOrCreate(namespace: namespace, value: value)
            if let tagId = tag.id {
                try await tagRepo.assignTag(assetId: assetId, tagId: tagId, source: .manual)
            }
            newTagText = ""
            showAddTag = false
            await loadVisionData()
        } catch {
            Logger.ui.error("Error agregando tag: \(error)")
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: Tag
    let source: String
    let confidence: Double?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Text(tag.displayName)
            if source != TagSource.manual.rawValue {
                Image(systemName: "sparkles")
                    .font(.system(size: 7))
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7))
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chipColor)
        .cornerRadius(4)
    }

    private var chipColor: Color {
        let c = tag.displayColor
        if source == TagSource.manual.rawValue || (confidence ?? 0) > 0.9 {
            return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness).opacity(0.3)
        }
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness).opacity(0.15)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
