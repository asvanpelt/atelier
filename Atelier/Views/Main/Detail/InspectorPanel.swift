import SwiftUI

struct InspectorPanel: View {
    let asset: Asset
    let tagRepo: TagRepository
    let visionRepo: VisionRepository
    let personRepo: PersonRepository

    @State private var assetTags: [(tag: Tag, source: String, confidence: Double?)] = []
    @State private var classifications: [VisionClassification] = []
    @State private var ocrText: String?
    @State private var faceObservations: [FaceObservation] = []
    @State private var allPersons: [Person] = []
    @State private var showAddTag = false
    @State private var newTagText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                fileInfo
                sourceSection
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
                .clipShape(.rect(cornerRadius: 8))
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
    private var sourceSection: some View {
        if let sourceRaw = asset.source {
            let kind = AssetSource(rawValue: sourceRaw) ?? .unknown
            HStack(spacing: 10) {
                Image(systemName: kind.symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.label)
                        .font(.subheadline.weight(.medium))
                    if let account = asset.sourceAccount {
                        Text("@\(account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
            }
            .padding(10)
            .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Button("Agregar tag", systemImage: "plus.circle", action: { showAddTag.toggle() })
                    .labelStyle(.iconOnly)
                    .font(.caption)
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
        let hasData = !classifications.isEmpty || ocrText != nil || !faceObservations.isEmpty

        if hasData {
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
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.tertiary)
                                    .clipShape(.rect(cornerRadius: 4))
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

                if !faceObservations.isEmpty {
                    faceSection
                }
            }
        }
    }

    @ViewBuilder
    private var faceSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(faceObservations.count) cara\(faceObservations.count == 1 ? "" : "s") detectada\(faceObservations.count == 1 ? "" : "s")")
                .font(.caption.weight(.medium))

            ForEach(Array(faceObservations.enumerated()), id: \.element.id) { index, face in
                faceRow(index: index, face: face)
            }
        }
    }

    @ViewBuilder
    private func faceRow(index: Int, face: FaceObservation) -> some View {
        HStack(spacing: 6) {
            Text("Cara \(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            if face.isConfirmed, let personId = face.personId,
               let person = allPersons.first(where: { $0.id == personId }) {
                assignedFaceLabel(person: person, face: face)
            } else {
                unassignedFacePicker(face: face)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func assignedFaceLabel(person: Person, face: FaceObservation) -> some View {
        Label(person.name, systemImage: "person.crop.circle.fill")
            .font(.caption)
            .foregroundStyle(.green)

        Menu {
            ForEach(allPersons, id: \.id) { p in
                Button(p.name) {
                    Task { await confirmFace(face, person: p) }
                }
            }
            Divider()
            Button("Desasignar", role: .destructive) {
                Task { await rejectFace(face) }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 16)
    }

    @ViewBuilder
    private func unassignedFacePicker(face: FaceObservation) -> some View {
        Menu {
            ForEach(allPersons, id: \.id) { person in
                Button(person.name) {
                    Task { await confirmFace(face, person: person) }
                }
            }
            if allPersons.isEmpty {
                Text("No hay personas creadas")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Asignar persona", systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .disabled(allPersons.isEmpty)
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
            faceObservations = try await visionRepo.facesFor(assetId: assetId)
            allPersons = try await personRepo.findAll()
        } catch {
            Logger.ui.error("Error cargando datos de Vision: \(error)")
        }
    }

    private func confirmFace(_ face: FaceObservation, person: Person) async {
        guard let faceId = face.id, let personId = person.id else { return }
        do {
            try await visionRepo.confirmFace(id: faceId, personId: personId)
            await loadVisionData()
        } catch {
            Logger.ui.error("Error asignando cara a persona: \(error)")
        }
    }

    private func rejectFace(_ face: FaceObservation) async {
        guard let faceId = face.id else { return }
        do {
            try await visionRepo.rejectFace(id: faceId)
            await loadVisionData()
        } catch {
            Logger.ui.error("Error desasignando cara: \(error)")
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
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
