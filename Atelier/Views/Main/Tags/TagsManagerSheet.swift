import SwiftUI

struct TagsManagerSheet: View {
    let tagRepo: TagRepository
    let onClose: () -> Void
    let onFilterByTag: (Tag) -> Void

    @State private var tags: [Tag] = []
    @State private var assetCounts: [Int64: Int] = [:]
    @State private var selectedNamespace: String? = ""
    @State private var selectedTagId: Int64?
    @State private var searchText = ""

    @State private var showRename = false
    @State private var renameValue = ""
    @State private var renameNamespace = ""
    @State private var renameColor: Color = .gray

    @State private var showMerge = false
    @State private var mergeTargetId: Int64?

    @State private var showDelete = false

    @State private var showRenameNamespace = false
    @State private var newNamespaceName = ""

    @State private var showNew = false
    @State private var newValue = ""
    @State private var newNamespace = ""

    private let unknownNamespace = "—"

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HSplitView {
                namespaceList
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

                tagDetail
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 480, idealHeight: 540)
        .task { await reload() }
        .sheet(isPresented: $showRename) { renameSheet }
        .sheet(isPresented: $showMerge) { mergeSheet }
        .sheet(isPresented: $showRenameNamespace) { renameNamespaceSheet }
        .sheet(isPresented: $showNew) { newTagSheet }
        .confirmationDialog(
            "¿Eliminar tag?",
            isPresented: $showDelete,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let tag = selectedTag {
                Text("\"\(tag.displayName)\" será eliminado de \(assetCounts[tag.id ?? 0] ?? 0) archivos.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            Text("Administrar tags")
                .font(.title3.weight(.semibold))
            Spacer()

            TextField("Buscar tag…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Button {
                newValue = ""
                newNamespace = selectedNamespace == "" ? "" : (selectedNamespace ?? "")
                showNew = true
            } label: {
                Label("Nuevo tag", systemImage: "plus")
            }

            Button("Cerrar", action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - Namespace list

    private var namespaceList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedNamespace) {
                Section("Categorías") {
                    namespaceRow(label: "Todos", icon: "rectangle.3.group", value: "", count: tags.count)

                    ForEach(namespaces, id: \.self) { ns in
                        namespaceRow(
                            label: ns ?? "Sin categoría",
                            icon: ns == nil ? "tag" : "folder.fill",
                            value: ns ?? unknownNamespace,
                            count: tags.filter { $0.namespace == ns }.count
                        )
                        .contextMenu {
                            if ns != nil {
                                Button("Renombrar categoría…") {
                                    newNamespaceName = ns ?? ""
                                    selectedNamespace = ns ?? unknownNamespace
                                    showRenameNamespace = true
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(.ultraThinMaterial)
    }

    private func namespaceRow(label: String, icon: String, value: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 1)
        .tag(value)
    }

    // MARK: - Tag detail

    @ViewBuilder
    private var tagDetail: some View {
        if filteredTags.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? "Sin tags en esta categoría" : "Sin resultados",
                systemImage: searchText.isEmpty ? "tag.slash" : "magnifyingglass",
                description: Text(searchText.isEmpty ? "Creá un tag con el botón de arriba." : "Probá con otro término.")
            )
        } else {
            HStack(spacing: 0) {
                tagsList
                    .frame(width: 280)
                Divider()
                inspector
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var tagsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredTags, id: \.id) { tag in
                    tagRow(tag)
                }
            }
            .padding(8)
        }
        .background(.background.opacity(0.3))
    }

    private func tagRow(_ tag: Tag) -> some View {
        let isSelected = tag.id == selectedTagId
        return HStack(spacing: 10) {
            Circle()
                .fill(color(for: tag))
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(tag.value)
                    .font(.body)
                if let ns = tag.namespace {
                    Text(ns)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(assetCounts[tag.id ?? 0] ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedTagId = tag.id }
    }

    @ViewBuilder
    private var inspector: some View {
        if let tag = selectedTag {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(color(for: tag))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tag.value)
                            .font(.title2.weight(.semibold))
                        if let ns = tag.namespace {
                            Text(ns)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Label("\(assetCounts[tag.id ?? 0] ?? 0) archivos", systemImage: "photo.stack")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        onFilterByTag(tag)
                        onClose()
                    } label: {
                        Label("Ver fotos con este tag", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 8) {
                        Button {
                            renameValue = tag.value
                            renameNamespace = tag.namespace ?? ""
                            renameColor = color(for: tag)
                            showRename = true
                        } label: {
                            Label("Editar", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            mergeTargetId = filteredTags.first(where: { $0.id != tag.id })?.id
                                ?? tags.first(where: { $0.id != tag.id })?.id
                            showMerge = true
                        } label: {
                            Label("Fusionar", systemImage: "arrow.triangle.merge")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(tags.count < 2)

                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        } else {
            ContentUnavailableView(
                "Seleccioná un tag",
                systemImage: "tag",
                description: Text("Elegí un tag de la lista para editarlo.")
            )
        }
    }

    // MARK: - Sheets

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar tag").font(.headline)

            Form {
                TextField("Valor", text: $renameValue)
                TextField("Categoría (opcional)", text: $renameNamespace)
                ColorPicker("Color", selection: $renameColor, supportsOpacity: false)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancelar") { showRename = false }
                Spacer()
                Button("Guardar") { Task { await commitRename() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var mergeSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fusionar tag").font(.headline)
            if let tag = selectedTag {
                Text("Mover los archivos de **\(tag.displayName)** al tag:")
            }
            Picker("Destino", selection: $mergeTargetId) {
                ForEach(tags.filter { $0.id != selectedTagId }, id: \.id) { t in
                    Text(t.displayName).tag(t.id as Int64?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Text("El tag original se eliminará.")
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
        .padding(20)
        .frame(width: 380)
    }

    private var renameNamespaceSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Renombrar categoría").font(.headline)
            TextField("Nombre", text: $newNamespaceName)
                .textFieldStyle(.roundedBorder)
            Text("Todos los tags de esta categoría se actualizarán.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancelar") { showRenameNamespace = false }
                Spacer()
                Button("Guardar") { Task { await commitRenameNamespace() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newNamespaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var newTagSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nuevo tag").font(.headline)
            Form {
                TextField("Valor", text: $newValue)
                TextField("Categoría (opcional)", text: $newNamespace)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancelar") { showNew = false }
                Spacer()
                Button("Crear") { Task { await commitNew() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    // MARK: - Helpers

    private var namespaces: [String?] {
        var seen = Set<String?>()
        var result: [String?] = []
        for t in tags where !seen.contains(t.namespace) {
            seen.insert(t.namespace)
            result.append(t.namespace)
        }
        return result.sorted { ($0 ?? "~") < ($1 ?? "~") }
    }

    private var filteredTags: [Tag] {
        var result = tags
        if let ns = selectedNamespace, !ns.isEmpty {
            if ns == unknownNamespace {
                result = result.filter { $0.namespace == nil }
            } else {
                result = result.filter { $0.namespace == ns }
            }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.value.lowercased().contains(q) ||
                ($0.namespace?.lowercased().contains(q) ?? false)
            }
        }
        return result
    }

    private var selectedTag: Tag? {
        tags.first { $0.id == selectedTagId }
    }

    private func color(for tag: Tag) -> Color {
        let c = tag.displayColor
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness)
    }

    private func reload() async {
        do {
            tags = try await tagRepo.findAll()
            var counts: [Int64: Int] = [:]
            for t in tags {
                guard let id = t.id else { continue }
                counts[id] = try await tagRepo.assetCountFor(tagId: id)
            }
            assetCounts = counts
            if selectedTagId == nil {
                selectedTagId = filteredTags.first?.id
            }
        } catch {
            Logger.ui.error("Error cargando tags: \(error)")
        }
    }

    private func commitRename() async {
        guard var tag = selectedTag else { return }
        let value = renameValue.trimmingCharacters(in: .whitespaces)
        let ns = renameNamespace.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        tag.value = value
        tag.namespace = ns.isEmpty ? nil : ns
        tag.color = "\(Double(NSColor(renameColor).hueComponent))"
        do {
            try await tagRepo.update(tag)
            showRename = false
            await reload()
        } catch {
            Logger.ui.error("Error actualizando tag: \(error)")
        }
    }

    private func commitMerge() async {
        guard let sourceId = selectedTagId, let targetId = mergeTargetId else { return }
        do {
            try await tagRepo.merge(from: sourceId, into: targetId)
            showMerge = false
            selectedTagId = targetId
            await reload()
        } catch {
            Logger.ui.error("Error fusionando tags: \(error)")
        }
    }

    private func commitRenameNamespace() async {
        let trimmed = newNamespaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let oldNs: String?
        if let sel = selectedNamespace, sel != "", sel != unknownNamespace {
            oldNs = sel
        } else if selectedNamespace == unknownNamespace {
            oldNs = nil
        } else {
            return
        }
        do {
            try await tagRepo.renameNamespace(from: oldNs, to: trimmed)
            showRenameNamespace = false
            selectedNamespace = trimmed
            await reload()
        } catch {
            Logger.ui.error("Error renombrando categoría: \(error)")
        }
    }

    private func commitNew() async {
        let value = newValue.trimmingCharacters(in: .whitespaces)
        let ns = newNamespace.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        do {
            let created = try await tagRepo.findOrCreate(namespace: ns.isEmpty ? nil : ns, value: value)
            showNew = false
            await reload()
            selectedTagId = created.id
        } catch {
            Logger.ui.error("Error creando tag: \(error)")
        }
    }

    private func deleteSelected() async {
        guard let id = selectedTagId else { return }
        do {
            try await tagRepo.delete(id: id)
            selectedTagId = nil
            await reload()
        } catch {
            Logger.ui.error("Error eliminando tag: \(error)")
        }
    }
}
