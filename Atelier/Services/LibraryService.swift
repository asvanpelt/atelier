import Foundation

final class LibraryService: @unchecked Sendable {
    private let rootRepo: LibraryRootRepository
    private let assetRepo: AssetRepository
    private let bookmarkManager: BookmarkManager

    var roots: [LibraryRoot] = []
    var onRootsChanged: (([LibraryRoot]) -> Void)?

    init(
        rootRepo: LibraryRootRepository,
        assetRepo: AssetRepository,
        bookmarkManager: BookmarkManager
    ) {
        self.rootRepo = rootRepo
        self.assetRepo = assetRepo
        self.bookmarkManager = bookmarkManager
    }

    func loadRoots() async {
        do {
            let loaded = try await rootRepo.findAll()
            roots = loaded
            Logger.database.info("\(loaded.count) library roots cargadas")
            onRootsChanged?(loaded)
        } catch {
            Logger.database.error("Error cargando roots: \(error)")
        }
    }

    func addRoot(url: URL) async throws -> LibraryRoot {
        let path = url.standardized.path
        if let existing = try? await rootRepo.findByPath(path) {
            return existing
        }

        let bookmarkData = try bookmarkManager.createBookmark(for: url)

        let root = LibraryRoot(
            id: nil,
            path: path,
            bookmarkData: bookmarkData,
            label: url.lastPathComponent,
            isExternal: !path.hasPrefix("/Users/") && !path.hasPrefix("/System/"),
            lastScanAt: nil,
            enabled: true
        )

        let saved = try await rootRepo.insert(root)
        roots.append(saved)
        onRootsChanged?(roots)
        return saved
    }

    func removeRoot(id: Int64) async throws {
        try await rootRepo.delete(id: id)
        roots.removeAll { $0.id == id }
        onRootsChanged?(roots)
    }

    func resolveAccess(for root: LibraryRoot) -> URL? {
        do {
            let result = try bookmarkManager.resolveBookmark(root.bookmarkData)
            if bookmarkManager.startAccessing(result.url) {
                return result.url
            }
        } catch {
            Logger.filesystem.error("Error resolviendo bookmark para \(root.path): \(error)")
        }
        return nil
    }
}
