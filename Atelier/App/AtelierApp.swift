import SwiftUI
import AppKit

@main
struct AtelierApp: App {
    let database: Database
    let libraryService: LibraryService
    let indexingService: IndexingService
    let thumbnailService: ThumbnailService
    let assetRepo: AssetRepository
    let rootRepo: LibraryRootRepository
    let tagRepo: TagRepository
    let personRepo: PersonRepository
    let visionRepo: VisionRepository
    let clusteringService: FaceClusteringService
    let organizeService: OrganizeService
    let fileWatcher: FileWatcher
    let volumeMonitor: VolumeMonitor
    let glassTheme = GlassTheme()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        let db = Database()
        do {
            try db.setup()
            Logger.database.info("Base de datos inicializada correctamente")
        } catch {
            Logger.database.fault("Error al inicializar la base de datos: \(error.localizedDescription)")
            fatalError("No se pudo inicializar la base de datos: \(error)")
        }
        self.database = db

        let bookmarkManager = BookmarkManager()
        let fileHasher = FileHasher()
        let assetRepo = AssetRepository(db: db)
        let rootRepo = LibraryRootRepository(db: db)
        let tagRepo = TagRepository(db: db)
        let personRepo = PersonRepository(db: db)
        let visionRepo = VisionRepository(db: db)
        self.assetRepo = assetRepo
        self.rootRepo = rootRepo
        self.tagRepo = tagRepo
        self.personRepo = personRepo
        self.visionRepo = visionRepo

        let thumbnailService = ThumbnailService()
        self.thumbnailService = thumbnailService

        let visionService = VisionService()

        self.organizeService = OrganizeService(assetRepo: assetRepo, tagRepo: tagRepo, db: db)

        let clusteringService = FaceClusteringService(
            visionRepo: visionRepo,
            assetRepo: assetRepo,
            visionService: visionService
        )
        self.clusteringService = clusteringService

        let indexingService = IndexingService(
            assetRepo: assetRepo,
            rootRepo: rootRepo,
            fileHasher: fileHasher,
            thumbnailService: thumbnailService,
            bookmarkManager: bookmarkManager,
            visionService: visionService,
            visionRepo: visionRepo,
            clusteringService: clusteringService
        )
        self.indexingService = indexingService

        let libraryService = LibraryService(
            rootRepo: rootRepo,
            assetRepo: assetRepo,
            bookmarkManager: bookmarkManager
        )
        self.libraryService = libraryService

        self.fileWatcher = FileWatcher(scanInterval: 30)
        self.volumeMonitor = VolumeMonitor()
    }

    var body: some Scene {
        WindowGroup {
            MainWindow(
                libraryService: libraryService,
                indexingService: indexingService,
                thumbnailService: thumbnailService,
                assetRepo: assetRepo,
                rootRepo: rootRepo,
                tagRepo: tagRepo,
                personRepo: personRepo,
                visionRepo: visionRepo,
                clusteringService: clusteringService,
                fileWatcher: fileWatcher,
                volumeMonitor: volumeMonitor,
                glassTheme: glassTheme
            )
        }
        .defaultSize(width: 1000, height: 700)

        Window("Organizar biblioteca", id: "organize") {
            OrganizeView(organizeService: organizeService)
        }
        .defaultSize(width: 1180, height: 720)

        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferencias...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            PreferencesView(
                libraryRoots: libraryService.roots,
                glassTheme: glassTheme,
                onAddFolder: {}
            )
        }
    }
}
