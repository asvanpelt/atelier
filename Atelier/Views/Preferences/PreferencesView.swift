import SwiftUI

struct PreferencesView: View {
    @Bindable var profileStore: ProfileStore
    var libraryRoots: [LibraryRoot]
    @Bindable var glassTheme: GlassTheme
    var onAddFolder: () -> Void
    var onRemoveRoot: ((Int64) -> Void)?

    @AppStorage("thumbnailCacheLimitMB") private var cacheLimitMB: Int = 5000
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 30
    @AppStorage("gridCellSize") private var defaultCellSize: Double = 200

    @State private var previewColor: Color = .blue

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            profilesTab
                .tabItem { Label("Perfiles", systemImage: "person.2.crop.square.stack") }

            appearanceTab
                .tabItem { Label("Apariencia", systemImage: "paintpalette") }

            librariesTab
                .tabItem { Label("Bibliotecas", systemImage: "folder") }

            performanceTab
                .tabItem { Label("Rendimiento", systemImage: "gauge.with.dots.needle.67percent") }

            advancedTab
                .tabItem { Label("Avanzado", systemImage: "wrench.adjustable") }
        }
        .frame(width: 500, height: 380)
        .padding()
    }

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section {
                LabeledContent("Tamaño de celda por defecto") {
                    HStack(spacing: 8) {
                        Slider(value: $defaultCellSize, in: 80...400, step: 10)
                            .frame(width: 150)
                        Text("\(Int(defaultCellSize))px")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var appearanceTab: some View {
        Form {
            Section("Color del tema") {
                LabeledContent("Tono") {
                    Slider(value: $glassTheme.tintHue, in: 0...1)
                        .frame(width: 200)
                }

                ColorPicker("Previsualización", selection: $previewColor)
                    .disabled(true)
                    .onChange(of: glassTheme.tintHue) { _, _ in previewColor = glassTheme.tintColor }
                    .onChange(of: glassTheme.opacity) { _, _ in previewColor = glassTheme.tintColor }
                    .task { previewColor = glassTheme.tintColor }
            }

            Section("Transparencia") {
                LabeledContent("Opacidad") {
                    HStack(spacing: 4) {
                        Slider(value: $glassTheme.opacity, in: 0.02...0.40)
                            .frame(width: 160)
                        Text("\(Int(glassTheme.opacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
                Text("A menor porcentaje, más sutil el efecto glass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var librariesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Carpetas indexadas")
                .font(.headline)

            List {
                ForEach(libraryRoots, id: \.id) { root in
                    HStack {
                        Image(systemName: root.exists ? "folder.fill" : "folder.badge.questionmark")
                            .foregroundStyle(root.exists ? .blue : .orange)
                        VStack(alignment: .leading) {
                            Text(root.label ?? root.url.lastPathComponent)
                                .font(.body)
                            Text(root.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let lastScan = root.lastScanAt {
                            Text(lastScan.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Button("Eliminar", systemImage: "trash") {
                            if let id = root.id {
                                onRemoveRoot?(id)
                            }
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Button(action: onAddFolder) {
                    Label("Agregar carpeta...", systemImage: "plus")
                }
                Spacer()
            }
        }
        .padding()
    }

    @ViewBuilder
    private var performanceTab: some View {
        Form {
            Section {
                LabeledContent("Límite de caché de thumbnails") {
                    HStack(spacing: 4) {
                        TextField("", value: $cacheLimitMB, format: .number)
                            .frame(width: 80)
                        Text("MB")
                    }
                }

                LabeledContent("Intervalo de escaneo automático") {
                    HStack(spacing: 4) {
                        TextField("", value: $scanInterval, format: .number)
                            .frame(width: 80)
                        Text("seg")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var profilesTab: some View {
        Form {
            Section("Perfil activo") {
                HStack(spacing: 10) {
                    Image(systemName: profileStore.activeProfile.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileStore.activeProfile.name).font(.headline)
                        Text(profileStore.activeProfile.id.uuidString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Todos los perfiles") {
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        Image(systemName: profile.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(profile.name)
                        if profile.id == profileStore.activeProfileID {
                            Text("(activo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.selectFile(
                                nil,
                                inFileViewerRootedAtPath: AppConstants.profileDir(for: profile.id).path
                            )
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Mostrar carpeta del perfil en Finder")
                    }
                }
            }

            Section {
                Text("Para crear, renombrar o eliminar perfiles, usa el selector en la parte superior del sidebar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var advancedTab: some View {
        Form {
            Section("Rutas") {
                LabeledContent("Base de datos") {
                    Text(AppConstants.databaseURL.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("Thumbnails") {
                    Text(AppConstants.thumbnailsDir.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("App Support") {
                    Text(AppConstants.appSupportDir.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section("Datos") {
                Button("Abrir carpeta de datos en Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.appSupportDir.path)
                }
            }
        }
        .formStyle(.grouped)
    }
}
