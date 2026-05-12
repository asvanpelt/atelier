import SwiftUI
import AppKit

struct MainWindow: View {
    let libraryService: LibraryService
    let indexingService: IndexingService
    let thumbnailService: ThumbnailService
    let assetRepo: AssetRepository
    let rootRepo: LibraryRootRepository
    let tagRepo: TagRepository
    let personRepo: PersonRepository
    let visionRepo: VisionRepository
    let fileWatcher: FileWatcher
    let volumeMonitor: VolumeMonitor
    let glassTheme: GlassTheme

    @State private var gridVM: GridViewModel
    @State private var libraryRoots: [LibraryRoot] = []
    @State private var isScanning = false
    @State private var scanTotal = 0
    @State private var scanCurrent = 0
    @State private var selectedAsset: Asset?
    @State private var showLightbox = false
    @State private var lightboxIndex = 0
    @State private var selectedRootId: Int64?
    @State private var searchText = ""
    @State private var cellSize: CGFloat = 200
    @State private var showInspector = false
    @State private var inspectedAsset: Asset?
    @State private var showWelcome = false
    @State private var allTags: [Tag] = []
    @State private var allPersons: [Person] = []
    @State private var showTagPopover = false
    @State private var showNewTagSheet = false
    @State private var showNewPersonSheet = false
    @State private var newTagNamespace = ""
    @State private var newTagValue = ""
    @State private var newPersonName = ""
    @State private var isAnalyzing = false
    @State private var analyzeProgress = ""
    @State private var thumbnailsBlurred = true

    init(
        libraryService: LibraryService,
        indexingService: IndexingService,
        thumbnailService: ThumbnailService,
        assetRepo: AssetRepository,
        rootRepo: LibraryRootRepository,
        tagRepo: TagRepository,
        personRepo: PersonRepository,
        visionRepo: VisionRepository,
        fileWatcher: FileWatcher,
        volumeMonitor: VolumeMonitor,
        glassTheme: GlassTheme
    ) {
        self.libraryService = libraryService
        self.indexingService = indexingService
        self.thumbnailService = thumbnailService
        self.assetRepo = assetRepo
        self.rootRepo = rootRepo
        self.tagRepo = tagRepo
        self.personRepo = personRepo
        self.visionRepo = visionRepo
        self.fileWatcher = fileWatcher
        self.volumeMonitor = volumeMonitor
        self.glassTheme = glassTheme
        self._gridVM = State(initialValue: GridViewModel(assetRepo: assetRepo, thumbnailService: thumbnailService))
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(glassTheme.tintColor)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            NavigationSplitView {
                sidebar
            } detail: {
                HStack(spacing: 0) {
                    content
                    if showInspector, let asset = inspectedAsset {
                        Divider()
                        InspectorPanel(
                            asset: asset,
                            tagRepo: tagRepo,
                            visionRepo: visionRepo
                        )
                    }
                }
            }
            .sheet(isPresented: $showLightbox) {
                LightboxView(
                    assets: gridVM.assets,
                    selectedIndex: lightboxIndex,
                    onClose: { showLightbox = false },
                    glassTint: glassTheme.tintColor
                )
            }
            .sheet(isPresented: $showNewTagSheet) {
                VStack(spacing: 16) {
                    Text("Nuevo Tag").font(.headline)
                    TextField("Namespace (opcional)", text: $newTagNamespace)
                        .textFieldStyle(.roundedBorder)
                    TextField("Valor", text: $newTagValue)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancelar") { showNewTagSheet = false }
                        Spacer()
                        Button("Crear") {
                            Task {
                                let ns = newTagNamespace.isEmpty ? nil : newTagNamespace
                                _ = try? await tagRepo.findOrCreate(namespace: ns, value: newTagValue)
                                newTagNamespace = ""
                                newTagValue = ""
                                showNewTagSheet = false
                                await loadTagsAndPersons()
                            }
                        }
                        .disabled(newTagValue.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .frame(width: 320)
            }
            .sheet(isPresented: $showNewPersonSheet) {
                VStack(spacing: 16) {
                    Text("Nueva Persona").font(.headline)
                    TextField("Nombre", text: $newPersonName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancelar") { showNewPersonSheet = false }
                        Spacer()
                        Button("Crear") {
                            Task {
                                let person = Person(id: nil, name: newPersonName, namespace: nil, notes: nil, createdAt: Date())
                                _ = try? await personRepo.insert(person)
                                newPersonName = ""
                                showNewPersonSheet = false
                                await loadTagsAndPersons()
                            }
                        }
                        .disabled(newPersonName.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .frame(width: 320)
            }
            .sheet(isPresented: $showWelcome) {
                WelcomeView(
                    onAddFolder: {
                        showWelcome = false
                        addFolder()
                    },
                    onSkip: { showWelcome = false }
                )
            }
            .searchable(text: $searchText, prompt: "Buscar por nombre...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await gridVM.search(newValue)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: addFolder) {
                        Label("Agregar carpeta", systemImage: "folder.badge.plus")
                    }
                    .disabled(isScanning)

                    Button(action: { Task { await scanAll() } }) {
                        Label("Escanear", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isScanning || libraryRoots.isEmpty)

                    Button(action: { Task { await analyzeWithVision() } }) {
                        Label("Analizar Vision", systemImage: "eye")
                    }
                    .disabled(isScanning || isAnalyzing || gridVM.assets.isEmpty)
                    .help("Ejecutar OCR, clasificación y detección de rostros")

                    Button(action: { showInspector.toggle() }) {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                    .help("Mostrar/ocultar inspector (⌘I)")

                    Button(action: { thumbnailsBlurred.toggle() }) {
                        Label("Blur", systemImage: thumbnailsBlurred ? "eye.slash" : "eye")
                    }
                    .help(thumbnailsBlurred ? "Mostrar miniaturas" : "Ocultar miniaturas")
                }

                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $cellSize, in: 80...400, step: 10)
                            .frame(width: 100)
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .status) {
                    if isScanning {
                        HStack(spacing: 6) {
                            ProgressView(value: Double(scanCurrent), total: Double(max(1, scanTotal)))
                                .frame(width: 80)
                            Text("\(scanCurrent)/\(scanTotal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if isAnalyzing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(analyzeProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("\(gridVM.assets.count) de \(gridVM.totalCount) archivos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await loadRoots()
                await gridVM.load()
                await loadTagsAndPersons()
                if libraryRoots.isEmpty {
                    let hasShownWelcome = UserDefaults.standard.bool(forKey: "hasShownWelcome")
                    if !hasShownWelcome {
                        showWelcome = true
                        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
                    }
                }
                startFileWatcher()
            }
            .focusable()
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedRootId) {
            LogoImage(size: nil)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            Section("Biblioteca") {
                Label("Todos los archivos", systemImage: "photo.on.rectangle")
                    .badge(gridVM.totalCount)
                    .tag(Int64(-1))
            }

            Section("Carpetas") {
                ForEach(libraryRoots, id: \.id) { root in
                    Label(root.label ?? root.url.lastPathComponent, systemImage: root.exists ? "folder" : "folder.badge.questionmark")
                        .tag(root.id ?? Int64(0))
                        .contextMenu {
                            Button("Mostrar en Finder") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: root.path)
                            }
                            Button("Escanear esta carpeta") {
                                Task { await scanSingle(root) }
                            }
                            Divider()
                            Button("Eliminar de la biblioteca", role: .destructive) {
                                Task { await removeRoot(root) }
                            }
                        }
                }
                Button(action: addFolder) {
                    Label("Agregar carpeta...", systemImage: "plus")
                }
            }

            Section("Tags") {
                ForEach(allTags, id: \.id) { tag in
                    Label(tag.displayName, systemImage: "tag")
                        .tag((tag.id ?? 0) + 10000)
                        .contextMenu {
                            Button("Eliminar tag", role: .destructive) {
                                Task {
                                    guard let id = tag.id else { return }
                                    try? await tagRepo.delete(id: id)
                                    await loadTagsAndPersons()
                                }
                            }
                        }
                }
                Button(action: { showNewTagSheet = true }) {
                    Label("Nuevo tag...", systemImage: "plus")
                }
            }

            Section("Personas") {
                ForEach(allPersons, id: \.id) { person in
                    Label(person.name, systemImage: "person.crop.circle")
                        .tag((person.id ?? 0) + 20000)
                        .contextMenu {
                            Button("Eliminar persona", role: .destructive) {
                                Task {
                                    guard let id = person.id else { return }
                                    try? await personRepo.delete(id: id)
                                    await loadTagsAndPersons()
                                }
                            }
                        }
                }
                Button(action: { showNewPersonSheet = true }) {
                    Label("Nueva persona...", systemImage: "plus")
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .onChange(of: selectedRootId) { _, newValue in
            Task {
                if newValue == nil || newValue == -1 {
                    await gridVM.filterByRoot(nil)
                } else if let rootId = newValue,
                          let root = libraryRoots.first(where: { $0.id == rootId }) {
                    await gridVM.filterByRoot(root.path)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if libraryRoots.isEmpty && !showWelcome {
            emptyState
        } else if gridVM.assets.isEmpty && !gridVM.isLoading && !searchText.isEmpty {
            noSearchResults
        } else if gridVM.assets.isEmpty && !gridVM.isLoading {
            noResultsState
        } else {
            AssetGridView(
                assets: $gridVM.assets,
                cellSize: cellSize,
                isBlurred: thumbnailsBlurred,
                onSelect: { asset in
                    inspectedAsset = asset
                    showInspector = true
                },
                onDoubleClick: { asset in
                    if let idx = gridVM.assets.firstIndex(where: { $0.id == asset.id }) {
                        lightboxIndex = idx
                        showLightbox = true
                    }
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            LogoImage(size: 64)
            Text("Atelier")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Agregá una carpeta para empezar a indexar")
                .font(.body)
                .foregroundStyle(.tertiary)
            Button(action: addFolder) {
                Label("Agregar carpeta...", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()
            LogoImage(size: 48)
            Text("Carpeta agregada")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Hacé clic en Escanear para indexar los archivos")
                .font(.body)
                .foregroundStyle(.tertiary)
            Button(action: { Task { await scanAll() } }) {
                Label("Escanear ahora", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var noSearchResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Sin resultados para \"\(searchText)\"")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Probá con otro término de búsqueda")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Seleccioná las carpetas que querés indexar en Atelier"
        panel.prompt = "Agregar"

        if panel.runModal() == .OK {
            for url in panel.urls {
                Task {
                    do {
                        let root = try await libraryService.addRoot(url: url)
                        libraryRoots.append(root)
                    } catch {
                        Logger.ui.error("Error agregando root: \(error)")
                    }
                }
            }
        }
    }

    private func loadRoots() async {
        await libraryService.loadRoots()
        let roots = libraryService.roots
        libraryRoots = roots
    }

    private func scanAll() async {
        isScanning = true
        scanCurrent = 0
        scanTotal = 0

        indexingService.onProgress = { current, total in
            Task { @MainActor in
                scanCurrent = current
                scanTotal = total
            }
        }

        for root in libraryRoots {
            await indexingService.scanRoot(root)
        }

        indexingService.onProgress = nil
        isScanning = false
        await gridVM.refresh()
    }

    private func scanSingle(_ root: LibraryRoot) async {
        isScanning = true
        scanCurrent = 0
        scanTotal = 0

        indexingService.onProgress = { current, total in
            Task { @MainActor in
                scanCurrent = current
                scanTotal = total
            }
        }

        await indexingService.scanRoot(root)

        indexingService.onProgress = nil
        isScanning = false
        await gridVM.refresh()
    }

    private func removeRoot(_ root: LibraryRoot) async {
        guard let id = root.id else { return }
        do {
            try await libraryService.removeRoot(id: id)
            libraryRoots.removeAll { $0.id == id }
            if selectedRootId == id {
                selectedRootId = Int64(-1)
            }
            await gridVM.refresh()
        } catch {
            Logger.ui.error("Error eliminando root: \(error)")
        }
    }

    private func analyzeWithVision() async {
        isAnalyzing = true
        let assets = gridVM.assets.filter { $0.mediaType == .image }
        let total = assets.count

        for (index, asset) in assets.enumerated() {
            guard let id = asset.id else { continue }
            analyzeProgress = "Analizando \(index + 1)/\(total)..."
            await indexingService.runVisionPipeline(asset: asset, id: id)
        }

        analyzeProgress = ""
        isAnalyzing = false
        await loadTagsAndPersons()
    }

    private func loadTagsAndPersons() async {
        do {
            allTags = try await tagRepo.findAll()
            allPersons = try await personRepo.findAll()
        } catch {
            Logger.ui.error("Error cargando tags/personas: \(error)")
        }
    }

    // MARK: - FileWatcher

    private func startFileWatcher() {
        let urls = libraryRoots.map(\.url)
        guard !urls.isEmpty else { return }

        fileWatcher.onChange = { [indexingService, gridVM] _ in
            Task {
                for root in libraryService.roots {
                    await indexingService.scanRoot(root)
                }
                await gridVM.refresh()
            }
        }
        fileWatcher.watch(urls: urls)
    }
}
