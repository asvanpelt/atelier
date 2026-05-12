import SwiftUI

struct PreferencesView: View {
    var libraryRoots: [LibraryRoot]
    @Bindable var glassTheme: GlassTheme
    var onAddFolder: () -> Void
    var onRemoveRoot: ((Int64) -> Void)?

    @AppStorage("thumbnailCacheLimitMB") private var cacheLimitMB: Int = 5000
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 30
    @AppStorage("gridCellSize") private var defaultCellSize: Double = 200

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

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
                HStack {
                    Text("Tamaño de celda por defecto")
                    Spacer()
                    Slider(value: $defaultCellSize, in: 80...400, step: 10)
                        .frame(width: 200)
                    Text("\(Int(defaultCellSize))px")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var appearanceTab: some View {
        Form {
            Section("Color del tema") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tono")
                        Spacer()
                        Slider(value: $glassTheme.tintHue, in: 0...1)
                            .frame(width: 200)
                    }

                    ColorPicker("Previsualización", selection: Binding(
                        get: { Color(hue: glassTheme.tintHue, saturation: 0.65, brightness: 0.95) },
                        set: { newColor in
                            let nsColor = NSColor(newColor)
                            glassTheme.tintHue = Double(nsColor.hueComponent)
                        }
                    ))
                    .disabled(true)
                }
            }

            Section("Transparencia") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacidad")
                        Spacer()
                        Slider(value: $glassTheme.opacity, in: 0.02...0.40)
                            .frame(width: 200)
                        Text("\(Int(glassTheme.opacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                    Text("A menor porcentaje, más sutil el efecto glass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                HStack {
                    Text("Límite de caché de thumbnails")
                    Spacer()
                    TextField("MB", value: $cacheLimitMB, format: .number)
                        .frame(width: 80)
                    Text("MB")
                }

                HStack {
                    Text("Intervalo de escaneo automático")
                    Spacer()
                    TextField("segundos", value: $scanInterval, format: .number)
                        .frame(width: 80)
                    Text("seg")
                }
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
