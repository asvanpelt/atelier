import SwiftUI
import AppKit

struct PeopleManagerView: View {
    let personRepo: PersonRepository
    let visionRepo: VisionRepository
    let assetRepo: AssetRepository
    let thumbnailService: ThumbnailService

    @State private var persons: [Person] = []
    @State private var faceCounts: [Int64: Int] = [:]
    @State private var unassignedCount: Int = 0
    @State private var selectedPersonId: Int64?
    @State private var faces: [FaceObservation] = []
    @State private var representativeFace: FaceObservation?
    @State private var personAssets: [Asset] = []
    @State private var isLoadingFaces = false
    @State private var photosSheetPerson: Person?
    @State private var clusters: [(clusterId: Int64, count: Int, sample: FaceObservation)] = []
    @State private var soloUnassigned: [FaceObservation] = []
    @State private var assignClusterTarget: Int64?
    @State private var showAssignCluster = false
    @State private var newPersonForClusterName = ""
    @State private var clusterDetailItem: ClusterDetailSheet?

    private static let unassignedSentinel: Int64 = -1
    private var isUnassignedSelected: Bool { selectedPersonId == Self.unassignedSentinel }

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var showMerge = false
    @State private var mergeTargetId: Int64?
    @State private var showNewPerson = false
    @State private var newPersonName = ""

    private let thumbSize: CGFloat = 110
    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 14)]

    var body: some View {
        HSplitView {
            personList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            faceGallery
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await reloadPersons() }
        .sheet(isPresented: $showRename) { renameSheet }
        .sheet(isPresented: $showMerge) { mergeSheet }
        .sheet(isPresented: $showNewPerson) { newPersonSheet }
        .sheet(isPresented: $showAssignCluster) {
            VStack(spacing: 16) {
                Text("Crear persona y asignar cluster").font(.headline)
                TextField("Nombre", text: $newPersonForClusterName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await commitAssignClusterToNewPerson() } }
                HStack {
                    Button("Cancelar") { showAssignCluster = false }
                    Spacer()
                    Button("Crear y asignar") { Task { await commitAssignClusterToNewPerson() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(newPersonForClusterName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 360)
        }
        .sheet(item: $photosSheetPerson) { person in
            PersonPhotosSheet(
                person: person,
                assets: personAssets,
                thumbnailService: thumbnailService,
                onClose: { photosSheetPerson = nil }
            )
        }
        .confirmationDialog(
            "¿Eliminar persona?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let person = selectedPerson {
                Text("\"\(person.name)\" será eliminada. Sus caras quedarán sin asignar.")
            }
        }
    }

    // MARK: - Person list

    private var personList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Personas")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    newPersonName = ""
                    showNewPerson = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Nueva persona")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            List(selection: $selectedPersonId) {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sin asignar")
                                .font(.body)
                            Text("\(unassignedCount) caras")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .tag(Self.unassignedSentinel)
                }

                if !persons.isEmpty {
                    Section("Personas") {
                        ForEach(persons, id: \.id) { person in
                            personRow(person)
                                .tag(person.id ?? 0)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(.ultraThinMaterial)
        .onChange(of: selectedPersonId) { _, _ in
            Task { await loadFacesForSelection() }
        }
    }

    private func personRow(_ person: Person) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.name)
                    .font(.body)
                Text("\(faceCounts[person.id ?? 0] ?? 0) caras")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Face gallery

    @ViewBuilder
    private var faceGallery: some View {
        if isUnassignedSelected {
            VStack(spacing: 0) {
                unassignedHeader
                Divider()
                facesGrid(emptyTitle: "No hay caras sin asignar",
                          emptySymbol: "checkmark.seal",
                          emptyDescription: "Todas las caras detectadas están asignadas a una persona.")
            }
        } else if let person = selectedPerson {
            VStack(spacing: 0) {
                galleryHeader(person)
                Divider()
                personRepresentativeView(person)
            }
        } else {
            ContentUnavailableView(
                "Seleccioná una persona",
                systemImage: "person.2.crop.square.stack",
                description: Text("Elegí una entrada de la lista para ver y administrar sus caras.")
            )
        }
    }

    @ViewBuilder
    private var unassignedContent: some View {
        if isLoadingFaces {
            Spacer()
            ProgressView()
            Spacer()
        } else if clusters.isEmpty && soloUnassigned.isEmpty {
            Spacer()
            ContentUnavailableView(
                "No hay caras sin asignar",
                systemImage: "checkmark.seal",
                description: Text("Todas las caras detectadas están asignadas. Si agregaste fotos nuevas, ejecutá ‘Reagrupar caras’ desde la toolbar.")
            )
            Spacer()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !clusters.isEmpty {
                        sectionTitle("Clusters detectados", subtitle: "Caras similares agrupadas. Asigná un cluster entero a una persona.")
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(clusters, id: \.clusterId) { entry in
                                clusterCell(entry)
                            }
                        }
                    }
                    if !soloUnassigned.isEmpty {
                        sectionTitle("Sin agrupar", subtitle: "Caras que aún no tienen embedding o no encajan en ningún cluster.")
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(soloUnassigned, id: \.id) { face in
                                faceCell(face)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func clusterCell(_ entry: (clusterId: Int64, count: Int, sample: FaceObservation)) -> some View {
        VStack(spacing: 6) {
            FaceThumbnailView(
                face: entry.sample,
                assetRepo: assetRepo,
                thumbnailService: thumbnailService,
                size: thumbSize
            )
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill").font(.caption2)
                    Text("\(entry.count)").font(.caption.weight(.semibold)).monospacedDigit()
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.black.opacity(0.7), in: Capsule())
                .foregroundStyle(.white)
                .padding(6)
            }
            .onTapGesture(count: 2) {
                Task { await openAssetInFinder(assetId: entry.sample.assetId) }
            }
            .onTapGesture {
                clusterDetailItem = ClusterDetailSheet(id: entry.clusterId, count: entry.count)
            }

            Menu {
                if persons.isEmpty {
                    Text("No hay personas creadas").foregroundStyle(.secondary)
                } else {
                    ForEach(persons, id: \.id) { person in
                        Button(person.name) {
                            Task { await assignCluster(entry.clusterId, to: person) }
                        }
                    }
                    Divider()
                    Button("Crear nueva persona…") {
                        assignClusterTarget = entry.clusterId
                        newPersonForClusterName = ""
                        showAssignCluster = true
                    }
                }
            } label: {
                Label("Asignar cluster", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .help("Cluster #\(entry.clusterId) · \(entry.count) caras similares · doble-click abre la foto")
    }

    @ViewBuilder
    private func personRepresentativeView(_ person: Person) -> some View {
        if isLoadingFaces {
            Spacer()
            ProgressView()
            Spacer()
        } else if let face = representativeFace {
            VStack(spacing: 18) {
                Spacer().frame(height: 12)

                Button {
                    photosSheetPerson = person
                } label: {
                    FaceThumbnailView(
                        face: face,
                        assetRepo: assetRepo,
                        thumbnailService: thumbnailService,
                        size: 220
                    )
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack.fill")
                                .font(.caption)
                            Text("\(personAssets.count)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.65), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { photosSheetPerson = person }
                )
                .help("Click para ver las \(personAssets.count) foto\(personAssets.count == 1 ? "" : "s") relacionada\(personAssets.count == 1 ? "" : "s")")
                .contextMenu {
                    Button("Ver fotos…") { photosSheetPerson = person }
                }

                VStack(spacing: 4) {
                    Text(person.name)
                        .font(.title3.weight(.semibold))
                    Text("\(personAssets.count) foto\(personAssets.count == 1 ? "" : "s") · \(faces.count) cara\(faces.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button {
                    photosSheetPerson = person
                } label: {
                    Label("Ver fotos", systemImage: "rectangle.grid.2x2")
                        .padding(.horizontal, 8)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(personAssets.isEmpty)

                Text("Click sobre el rostro o el botón para abrir las fotos relacionadas")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        } else {
            Spacer()
            ContentUnavailableView(
                "Sin caras confirmadas",
                systemImage: "person.crop.rectangle.stack",
                description: Text("Asigná caras a esta persona desde 'Sin asignar' o desde el inspector de cada foto.")
            )
            Spacer()
        }
    }

    @ViewBuilder
    private func facesGrid(emptyTitle: String, emptySymbol: String, emptyDescription: String) -> some View {
        if isLoadingFaces {
            Spacer()
            ProgressView()
            Spacer()
        } else if faces.isEmpty {
            Spacer()
            ContentUnavailableView(emptyTitle, systemImage: emptySymbol, description: Text(emptyDescription))
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(faces, id: \.id) { face in
                        faceCell(face)
                    }
                }
                .padding(20)
            }
        }
    }

    private var unassignedHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sin asignar")
                    .font(.title2.weight(.semibold))
                Text("\(faces.count) cara\(faces.count == 1 ? "" : "s") detectada\(faces.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                newPersonName = ""
                showNewPerson = true
            } label: {
                Label("Nueva persona", systemImage: "person.crop.circle.badge.plus")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func galleryHeader(_ person: Person) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.title2.weight(.semibold))
                Text("\(faces.count) cara\(faces.count == 1 ? "" : "s") confirmada\(faces.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()

            Button {
                renameText = person.name
                showRename = true
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }

            Button {
                mergeTargetId = persons.first(where: { $0.id != person.id })?.id
                showMerge = true
            } label: {
                Label("Fusionar", systemImage: "arrow.triangle.merge")
            }
            .disabled(persons.count < 2)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func faceCell(_ face: FaceObservation) -> some View {
        VStack(spacing: 6) {
            FaceThumbnailView(
                face: face,
                assetRepo: assetRepo,
                thumbnailService: thumbnailService,
                size: thumbSize
            )
            .onTapGesture(count: 2) {
                Task { await openAssetInFinder(assetId: face.assetId) }
            }
            .help("Doble-click para abrir la foto")

            if isUnassignedSelected {
                Menu {
                    if persons.isEmpty {
                        Text("No hay personas creadas")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(persons, id: \.id) { person in
                            Button(person.name) {
                                Task { await reassign(face: face, to: person) }
                            }
                        }
                    }
                } label: {
                    Label("Asignar a…", systemImage: "person.crop.circle.badge.plus")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .contextMenu {
            if !isUnassignedSelected {
                Menu("Mover a otra persona") {
                    ForEach(persons.filter { $0.id != selectedPersonId }, id: \.id) { other in
                        Button(other.name) {
                            Task { await reassign(face: face, to: other) }
                        }
                    }
                }
                Button("Quitar de esta persona", role: .destructive) {
                    Task { await unassign(face: face) }
                }
            } else {
                Menu("Asignar a") {
                    ForEach(persons, id: \.id) { person in
                        Button(person.name) {
                            Task { await reassign(face: face, to: person) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sheets

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Renombrar persona").font(.headline)
            TextField("Nombre", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await commitRename() } }
            HStack {
                Button("Cancelar") { showRename = false }
                Spacer()
                Button("Guardar") { Task { await commitRename() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private var mergeSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fusionar persona").font(.headline)
            if let person = selectedPerson {
                Text("Mover todas las caras de **\(person.name)** a:")
                    .font(.callout)
            }
            Picker("Destino", selection: $mergeTargetId) {
                ForEach(persons.filter { $0.id != selectedPersonId }, id: \.id) { p in
                    Text(p.name).tag(p.id as Int64?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Text("La persona original se eliminará.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancelar") { showMerge = false }
                Spacer()
                Button("Fusionar") { Task { await commitMerge() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(mergeTargetId == nil)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private var newPersonSheet: some View {
        VStack(spacing: 16) {
            Text("Nueva persona").font(.headline)
            TextField("Nombre", text: $newPersonName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await commitNewPerson() } }
            HStack {
                Button("Cancelar") { showNewPerson = false }
                Spacer()
                Button("Crear") { Task { await commitNewPerson() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    // MARK: - Helpers

    private var selectedPerson: Person? {
        persons.first { $0.id == selectedPersonId }
    }

    private func reloadPersons() async {
        do {
            persons = try await personRepo.findAll()
            var counts: [Int64: Int] = [:]
            for p in persons {
                guard let id = p.id else { continue }
                counts[id] = try await visionRepo.faceCountFor(personId: id)
            }
            faceCounts = counts
            unassignedCount = try await visionRepo.unassignedFaceCount()
            if selectedPersonId == nil {
                selectedPersonId = Self.unassignedSentinel
            }
            await loadFacesForSelection()
        } catch {
            Logger.ui.error("Error cargando personas: \(error)")
        }
    }

    private func loadFacesForSelection() async {
        guard let id = selectedPersonId else {
            faces = []
            representativeFace = nil
            personAssets = []
            return
        }
        isLoadingFaces = true
        defer { isLoadingFaces = false }
        do {
            if id == Self.unassignedSentinel {
                faces = try await visionRepo.unassignedFaces()
                clusters = []
                soloUnassigned = []
                representativeFace = nil
                personAssets = []
            } else {
                let confirmed = try await visionRepo.confirmedFacesFor(personId: id)
                faces = confirmed
                representativeFace = confirmed.first
                let assetIds = try await personRepo.assetIdsFor(personId: id)
                personAssets = try await assetRepo.findByIds(assetIds)
            }
        } catch {
            Logger.ui.error("Error cargando caras: \(error)")
            faces = []
            representativeFace = nil
            personAssets = []
        }
    }

    private func commitRename() async {
        guard var person = selectedPerson else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        person.name = trimmed
        do {
            try await personRepo.update(person)
            showRename = false
            await reloadPersons()
        } catch {
            Logger.ui.error("Error renombrando persona: \(error)")
        }
    }

    private func commitMerge() async {
        guard let sourceId = selectedPersonId, let targetId = mergeTargetId else { return }
        do {
            try await visionRepo.mergePersons(from: sourceId, into: targetId)
            showMerge = false
            selectedPersonId = targetId
            await reloadPersons()
        } catch {
            Logger.ui.error("Error fusionando personas: \(error)")
        }
    }

    private func commitNewPerson() async {
        let trimmed = newPersonName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let person = Person(id: nil, name: trimmed, namespace: nil, notes: nil, createdAt: Date())
        do {
            let created = try await personRepo.insert(person)
            showNewPerson = false
            await reloadPersons()
            selectedPersonId = created.id
        } catch {
            Logger.ui.error("Error creando persona: \(error)")
        }
    }

    private func deleteSelected() async {
        guard let id = selectedPersonId else { return }
        do {
            try await personRepo.delete(id: id)
            selectedPersonId = nil
            await reloadPersons()
        } catch {
            Logger.ui.error("Error eliminando persona: \(error)")
        }
    }

    private func reassign(face: FaceObservation, to person: Person) async {
        guard let faceId = face.id, let personId = person.id else { return }
        do {
            try await visionRepo.reassignFace(id: faceId, toPersonId: personId)
            await reloadPersons()
        } catch {
            Logger.ui.error("Error reasignando cara: \(error)")
        }
    }

    private func assignCluster(_ clusterId: Int64, to person: Person) async {
        guard let personId = person.id else { return }
        do {
            try await visionRepo.assignClusterToPerson(clusterId: clusterId, personId: personId)
            await reloadPersons()
        } catch {
            Logger.ui.error("Error asignando cluster: \(error)")
        }
    }

    private func commitAssignClusterToNewPerson() async {
        let trimmed = newPersonForClusterName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let clusterId = assignClusterTarget else { return }
        do {
            let created = try await personRepo.insert(Person(id: nil, name: trimmed, namespace: nil, notes: nil, createdAt: Date()))
            if let pid = created.id {
                try await visionRepo.assignClusterToPerson(clusterId: clusterId, personId: pid)
            }
            showAssignCluster = false
            assignClusterTarget = nil
            newPersonForClusterName = ""
            await reloadPersons()
        } catch {
            Logger.ui.error("Error creando persona desde cluster: \(error)")
        }
    }

    private func openAssetInFinder(assetId: Int64) async {
        do {
            guard let asset = try await assetRepo.find(id: assetId) else { return }
            await MainActor.run {
                NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
            }
        } catch {
            Logger.ui.error("Error abriendo foto: \(error)")
        }
    }

    private func unassign(face: FaceObservation) async {
        guard let faceId = face.id else { return }
        do {
            try await visionRepo.rejectFace(id: faceId)
            await reloadPersons()
        } catch {
            Logger.ui.error("Error desasignando cara: \(error)")
        }
    }
}
