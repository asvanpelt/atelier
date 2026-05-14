import SwiftUI
import Observation

@MainActor
@Observable
final class GridViewModel {
    var assets: [Asset] = []
    var isLoading = false
    var isScanning = false
    var scanProgress: String = ""
    var totalCount: Int = 0
    var filterRootPath: String?
    var searchQuery: String = ""
    var cellSize: CGFloat = 200

    private let assetRepo: AssetRepository
    private let thumbnailService: ThumbnailService

    init(assetRepo: AssetRepository, thumbnailService: ThumbnailService) {
        self.assetRepo = assetRepo
        self.thumbnailService = thumbnailService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if !searchQuery.isEmpty {
                assets = try await assetRepo.search(query: searchQuery, rootPath: filterRootPath)
            } else if let rootPath = filterRootPath {
                assets = try await assetRepo.findByRoot(rootPath)
            } else {
                assets = try await assetRepo.findAll(excludeDeleted: true)
            }
            totalCount = try await assetRepo.totalCount()
        } catch {
            Logger.ui.error("Error cargando assets: \(error)")
        }
    }

    func filterByRoot(_ rootPath: String?) async {
        filterRootPath = rootPath
        await load()
    }

    func search(_ query: String) async {
        searchQuery = query
        await load()
    }

    func refresh() async {
        await load()
    }

    func addAsset(_ asset: Asset) {
        assets.insert(asset, at: 0)
        totalCount = assets.count
    }

    func thumbnailURL(for asset: Asset, size: Int = 400) -> URL? {
        let cache = AppConstants.thumbnailsDir
        let hashPrefix = String(asset.fileHash.prefix(8))
        let url = cache
            .appendingPathComponent("\(size)")
            .appendingPathComponent(hashPrefix)
            .appendingPathComponent("\(asset.id ?? 0).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
