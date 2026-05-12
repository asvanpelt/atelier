import Foundation
import ImageIO
@preconcurrency import AVFoundation

final class IndexingService: @unchecked Sendable {
    private let assetRepo: AssetRepository
    private let rootRepo: LibraryRootRepository
    private let fileHasher: FileHasher
    private let thumbnailService: ThumbnailService
    private let bookmarkManager: BookmarkManager
    private let visionService: VisionService
    private let visionRepo: VisionRepository

    var onProgress: ((_ current: Int, _ total: Int) -> Void)?
    var onAssetIndexed: ((Asset) -> Void)?

    init(
        assetRepo: AssetRepository,
        rootRepo: LibraryRootRepository,
        fileHasher: FileHasher,
        thumbnailService: ThumbnailService,
        bookmarkManager: BookmarkManager,
        visionService: VisionService,
        visionRepo: VisionRepository
    ) {
        self.assetRepo = assetRepo
        self.rootRepo = rootRepo
        self.fileHasher = fileHasher
        self.thumbnailService = thumbnailService
        self.bookmarkManager = bookmarkManager
        self.visionService = visionService
        self.visionRepo = visionRepo
    }

    func scanRoot(_ root: LibraryRoot) async {
        guard root.exists else {
            Logger.indexing.warning("Root no accesible: \(root.path)")
            return
        }

        let url = root.url
        _ = bookmarkManager.startAccessing(url)
        defer { bookmarkManager.stopAccessing(url) }

        let fsItems = enumerateMediaFiles(in: url)
        let totalCount = fsItems.count

        Logger.indexing.info("Escaneando \(root.path): \(totalCount) archivos encontrados")

        for (index, fileURL) in fsItems.enumerated() {
            onProgress?(index + 1, totalCount)

            let path = fileURL.path
            let existing = try? await assetRepo.findByPath(path)

            let currentMod = fileURL.modificationDate ?? Date()
            let currentSize = fileURL.fileSize

            if let existing {
                if existing.modifiedAt != currentMod || existing.fileSize != currentSize {
                    do {
                        let asset = try await indexFile(url: fileURL, existing: existing)
                        onAssetIndexed?(asset)
                    } catch {
                        Logger.indexing.error("Error reindexando \(path): \(error)")
                    }
                }
            } else {
                do {
                    let asset = try await indexFile(url: fileURL, existing: nil)
                    onAssetIndexed?(asset)
                } catch {
                    Logger.indexing.error("Error indexando \(path): \(error)")
                }
            }
        }

        let fsPaths = Set(fsItems.map(\.path))
        await detectDeletedOrMoved(rootPath: root.path, fsPaths: fsPaths)

        if let rootId = root.id {
            try? await rootRepo.updateLastScan(id: rootId, at: Date())
        }
    }

    func runVisionPipeline(asset: Asset, id: Int64) async {
        let url = asset.fileURL

        do {
            async let ocrTask = visionService.runOCR(url: url)
            async let classTask = visionService.runClassification(url: url)
            async let faceTask = visionService.runFaceDetection(url: url)

            let ocrResults = try await ocrTask
            let classifications = try await classTask
            let faces = try await faceTask

            let fullText = ocrResults.map(\.text).joined(separator: " ")
            if !fullText.isEmpty {
                let language = ocrResults.first?.language
                try await visionRepo.saveOCR(assetId: id, text: fullText, language: language)
            }

            if !classifications.isEmpty {
                let records = classifications.map {
                    VisionClassification(assetId: id, label: $0.label, confidence: $0.confidence)
                }
                try await visionRepo.saveClassifications(records)
            }

            if !faces.isEmpty {
                let records = faces.map {
                    FaceObservation(
                        id: nil, assetId: id,
                        bboxX: $0.bboxX, bboxY: $0.bboxY,
                        bboxW: $0.bboxW, bboxH: $0.bboxH,
                        quality: $0.quality, personId: nil,
                        confidence: nil, isConfirmed: false, isReference: false
                    )
                }
                try await visionRepo.saveFaceObservations(records)
            }

            Logger.indexing.info("Vision completado para \(url.lastPathComponent): OCR=\(ocrResults.count) Class=\(classifications.count) Faces=\(faces.count)")
        } catch {
            Logger.indexing.warning("Vision falló para \(url.path): \(error)")
        }
    }

    private func detectDeletedOrMoved(rootPath: String, fsPaths: Set<String>) async {
        do {
            let dbPaths = try await assetRepo.allPathsForRoot(rootPath)
            let missing = dbPaths.subtracting(fsPaths)

            for path in missing {
                guard let asset = try? await assetRepo.findByPath(path) else { continue }

                if let match = try? await assetRepo.findByHash(asset.fileHash),
                   match.id != asset.id,
                   fsPaths.contains(match.filePath) {
                    Logger.indexing.info("Archivo movido: \(path)")
                } else {
                    if let id = asset.id {
                        try? await assetRepo.markDeleted(id: id)
                        Logger.indexing.info("Archivo eliminado: \(path)")
                    }
                }
            }
        } catch {
            Logger.indexing.error("Error detectando eliminados: \(error)")
        }
    }

    private func indexFile(url: URL, existing: Asset? = nil) async throws -> Asset {
        let now = Date()

        let hash = try await fileHasher.hash(url: url)
        let fileSize = url.fileSize
        let mimeType = url.mimeType
        let mediaType = url.mediaType
        let createdAt = url.creationDate ?? now
        let modifiedAt = url.modificationDate ?? now

        var asset = Asset(
            id: existing?.id,
            filePath: url.path,
            fileHash: hash,
            fileSize: fileSize,
            mimeType: mimeType,
            mediaType: mediaType,
            width: nil,
            height: nil,
            durationMs: nil,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            importedAt: existing?.importedAt ?? now,
            indexedAt: now,
            indexingVersion: 1,
            deletedAt: nil
        )

        if mediaType == .image {
            if let dims = extractImageDimensions(url: url) {
                asset.width = dims.width
                asset.height = dims.height
            }
        } else if mediaType == .video {
            let meta = extractVideoMetadata(url: url)
            asset.width = meta.width
            asset.height = meta.height
            asset.durationMs = meta.durationMs
        }

        let saved = try await assetRepo.upsert(asset)

        do {
            try await thumbnailService.generate(for: saved)
        } catch {
            Logger.indexing.warning("Thumbnail falló para \(url.path): \(error)")
        }

        if saved.mediaType == .image, let savedId = saved.id {
            await runVisionPipeline(asset: saved, id: savedId)
        }

        return saved
    }

    private func enumerateMediaFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.isImage || fileURL.isVideo {
                files.append(fileURL)
            }
        }
        return files
    }

    private func extractImageDimensions(url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        return (w > 0 && h > 0) ? (w, h) : nil
    }

    private func extractVideoMetadata(url: URL) -> (width: Int?, height: Int?, durationMs: Int?) {
        let asset = AVAsset(url: url)
        var width: Int?
        var height: Int?
        var durationMs: Int?

        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            width = Int(abs(size.width))
            height = Int(abs(size.height))
        }

        let duration = CMTimeGetSeconds(asset.duration)
        if duration.isFinite && duration > 0 {
            durationMs = Int(duration * 1000)
        }

        return (width, height, durationMs)
    }
}
