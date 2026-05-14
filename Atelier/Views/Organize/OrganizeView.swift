import SwiftUI
import AppKit

struct OrganizeView: View {
    let organizeService: OrganizeService

    @State private var template: OrganizeTemplate = .sourceAccountYear
    @State private var filter = OrganizeFilter()
    @State private var destinationRoot: URL?
    @State private var plan: [OrganizePlanItem] = []
    @State private var isBuilding = false
    @State private var isApplying = false
    @State private var lastSummary: OrganizeRunSummary?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            controlPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
            previewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, idealWidth: 1180, minHeight: 600, idealHeight: 720)
        .navigationTitle("Organizar biblioteca")
    }

    // MARK: - Control panel

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Plantilla") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(OrganizeTemplate.allCases) { tmpl in
                            templateRow(tmpl)
                        }
                    }
                }

                section("Filtros") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Imágenes", isOn: $filter.includeImages)
                        Toggle("Videos", isOn: $filter.includeVideos)
                        Divider()
                        Toggle("Solo con origen detectado", isOn: $filter.onlyWithSource)
                            .disabled(filter.onlyWithoutSource)
                        Toggle("Solo sin origen", isOn: $filter.onlyWithoutSource)
                            .disabled(filter.onlyWithSource)
                    }
                }

                section("Destino") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let dest = destinationRoot {
                            Text(dest.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        } else {
                            Text("Sin elegir")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            pickDestination()
                        } label: {
                            Label(destinationRoot == nil ? "Elegir carpeta…" : "Cambiar…", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                    }
                }

                section("Acciones") {
                    VStack(spacing: 8) {
                        Button {
                            Task { await build() }
                        } label: {
                            Label("Simular", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.bordered)
                        .disabled(destinationRoot == nil || isBuilding || isApplying)

                        Button {
                            Task { await apply() }
                        } label: {
                            Label("Aplicar (\(selectedCount))", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .disabled(plan.isEmpty || selectedCount == 0 || isApplying)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let summary = lastSummary {
                    section("Última ejecución") {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(summary.succeeded) movidas", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            if summary.failed > 0 {
                                Label("\(summary.failed) fallaron", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            if let id = summary.runId {
                                Text("Run #\(id)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                        .font(.caption)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
    }

    private func templateRow(_ tmpl: OrganizeTemplate) -> some View {
        let selected = tmpl == template
        return Button {
            template = tmpl
            plan = []
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tmpl.label).font(.body.weight(selected ? .semibold : .regular))
                    Text(tmpl.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.20)), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Preview panel

    @ViewBuilder
    private var previewPanel: some View {
        if isBuilding {
            VStack {
                Spacer()
                ProgressView("Calculando preview…")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if plan.isEmpty {
            ContentUnavailableView(
                "Sin preview todavía",
                systemImage: "wand.and.stars",
                description: Text(destinationRoot == nil ? "Elegí una carpeta destino y tocá ‘Simular’ para ver el plan." : "Tocá ‘Simular’ para generar el plan de movimientos.")
            )
        } else {
            previewList
        }
    }

    private var previewList: some View {
        let groups = Dictionary(grouping: plan) { item in
            (item.destinationPath as NSString).deletingLastPathComponent
        }
        let sortedKeys = groups.keys.sorted()

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(plan.count) archivos · \(selectedCount) seleccionados · \(conflictCount) conflictos")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Seleccionar todos") { setAll(true) }
                    .disabled(plan.isEmpty)
                Button("Deseleccionar todos") { setAll(false) }
                    .disabled(plan.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedKeys, id: \.self) { folder in
                        folderHeader(folder, count: groups[folder]?.count ?? 0)
                        ForEach(groups[folder] ?? []) { item in
                            row(for: item)
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private func folderHeader(_ folder: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill").foregroundStyle(.tint)
            Text(folder)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
    }

    private func row(for item: OrganizePlanItem) -> some View {
        let idx = plan.firstIndex(where: { $0.id == item.id }) ?? 0
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { plan[idx].selected },
                set: { plan[idx].selected = $0 }
            ))
            .labelsHidden()
            .disabled(item.conflict)

            VStack(alignment: .leading, spacing: 2) {
                Text((item.sourcePath as NSString).lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.sourcePath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()

            if item.conflict {
                Label("Conflicto", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private var selectedCount: Int { plan.filter(\.selected).count }
    private var conflictCount: Int { plan.filter(\.conflict).count }

    private func setAll(_ value: Bool) {
        for i in plan.indices where !plan[i].conflict {
            plan[i].selected = value
        }
    }

    private func pickDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Elegí la carpeta donde se va a reorganizar la biblioteca"
        panel.prompt = "Elegir"
        if panel.runModal() == .OK, let url = panel.url {
            destinationRoot = url
            plan = []
        }
    }

    private func build() async {
        guard let root = destinationRoot else { return }
        isBuilding = true
        errorMessage = nil
        defer { isBuilding = false }
        do {
            plan = try await organizeService.buildPlan(template: template, destinationRoot: root, filter: filter)
        } catch {
            errorMessage = "Error generando preview: \(error.localizedDescription)"
        }
    }

    private func apply() async {
        isApplying = true
        defer { isApplying = false }
        let summary = await organizeService.apply(plan, template: template)
        lastSummary = summary
        plan = []
    }
}
