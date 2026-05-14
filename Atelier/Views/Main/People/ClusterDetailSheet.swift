import SwiftUI

struct ClusterDetailSheet: Identifiable {
    let id: Int64
    let count: Int
}

struct ClusterDetailView: View {
    let clusterId: Int64
    let visionRepo: VisionRepository
    let assetRepo: AssetRepository
    let thumbnailService: ThumbnailService
    let persons: [Person]
    let onClose: () -> Void
    let onChanged: () async -> Void

    @State private var faces: [FaceObservation] = []

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 14)]
    private let tileSize: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cluster #\(clusterId)").font(.title3.weight(.semibold))
                    Text("\(faces.count) cara\(faces.count == 1 ? "" : "s") agrupada\(faces.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()

                Menu {
                    if persons.isEmpty {
                        Text("No hay personas creadas").foregroundStyle(.secondary)
                    } else {
                        ForEach(persons, id: \.id) { person in
                            Button(person.name) {
                                Task { await assignAll(to: person) }
                            }
                        }
                    }
                } label: {
                    Label("Asignar todo a…", systemImage: "person.crop.circle.badge.plus")
                }
                .disabled(persons.isEmpty)

                Button("Cerrar", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if faces.isEmpty {
                Spacer()
                ContentUnavailableView("Sin caras", systemImage: "person.crop.rectangle.stack",
                    description: Text("Este cluster ya no tiene caras."))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(faces, id: \.id) { face in
                            VStack(spacing: 4) {
                                FaceThumbnailView(
                                    face: face,
                                    assetRepo: assetRepo,
                                    thumbnailService: thumbnailService,
                                    size: tileSize
                                )
                                .contextMenu {
                                    Button("Sacar del cluster") {
                                        Task { await remove(face: face) }
                                    }
                                }

                                Menu {
                                    ForEach(persons, id: \.id) { p in
                                        Button(p.name) {
                                            Task { await assign(face: face, to: p) }
                                        }
                                    }
                                } label: {
                                    Label("Asignar a…", systemImage: "person.crop.circle.badge.plus")
                                        .font(.caption2)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .disabled(persons.isEmpty)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 880, minHeight: 480, idealHeight: 600)
        .task { await load() }
    }

    private func load() async {
        do {
            faces = try await visionRepo.facesInCluster(clusterId)
        } catch {
            Logger.ui.error("Error cargando cluster: \(error)")
        }
    }

    private func assignAll(to person: Person) async {
        guard let pid = person.id else { return }
        do {
            try await visionRepo.assignClusterToPerson(clusterId: clusterId, personId: pid)
            await onChanged()
            onClose()
        } catch {
            Logger.ui.error("Error asignando cluster: \(error)")
        }
    }

    private func assign(face: FaceObservation, to person: Person) async {
        guard let fid = face.id, let pid = person.id else { return }
        do {
            try await visionRepo.confirmFace(id: fid, personId: pid)
            await load()
            await onChanged()
        } catch {
            Logger.ui.error("Error asignando cara: \(error)")
        }
    }

    private func remove(face: FaceObservation) async {
        guard let fid = face.id else { return }
        do {
            try await visionRepo.updateCluster(id: fid, clusterId: nil)
            await load()
            await onChanged()
        } catch {
            Logger.ui.error("Error sacando del cluster: \(error)")
        }
    }
}
