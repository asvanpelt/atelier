import Foundation
@preconcurrency import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

actor ThumbnailService {
    private let cacheDir: URL
    private let sizes = [200, 400, 800]

    init() {
        self.cacheDir = AppConstants.thumbnailsDir
        for size in sizes {
            try? FileManager.default.createDirectory(
                at: cacheDir.appendingPathComponent("\(size)", isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    func generate(for asset: Asset) async throws {
        guard asset.mediaType != .unknown else { return }
        let sourceURL = asset.fileURL

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            Logger.indexing.warning("Thumbnail: archivo origen no existe \(sourceURL.path)")
            return
        }

        for size in sizes {
            let destURL = cachePath(for: asset, size: size)
            if FileManager.default.fileExists(atPath: destURL.path) { continue }

            do {
                if asset.mediaType == .image {
                    try await generateImageThumbnail(source: sourceURL, destination: destURL, size: size)
                } else if asset.mediaType == .video {
                    try await generateVideoThumbnail(source: sourceURL, destination: destURL, size: size)
                }
            } catch {
                Logger.indexing.error("Thumbnail \(size) falló para \(sourceURL.lastPathComponent): \(error.localizedDescription)")
                throw error
            }
        }
    }

    func thumbnail(for asset: Asset, size: Int) -> URL? {
        let url = cachePath(for: asset, size: size)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func generateSingle(for asset: Asset, size: Int) async throws -> URL? {
        let destURL = cachePath(for: asset, size: size)
        if FileManager.default.fileExists(atPath: destURL.path) {
            return destURL
        }

        if asset.mediaType == .image {
            try await generateImageThumbnail(source: asset.fileURL, destination: destURL, size: size)
        } else if asset.mediaType == .video {
            try await generateVideoThumbnail(source: asset.fileURL, destination: destURL, size: size)
        }

        return FileManager.default.fileExists(atPath: destURL.path) ? destURL : nil
    }

    private func cachePath(for asset: Asset, size: Int) -> URL {
        let hashPrefix = String(asset.fileHash.prefix(8))
        let dir = cacheDir
            .appendingPathComponent("\(size)", isDirectory: true)
            .appendingPathComponent(hashPrefix, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(asset.id ?? 0).jpg")
    }

    private func generateImageThumbnail(source: URL, destination: URL, size: Int) async throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw ThumbnailError.invalidSource
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ThumbnailError.generationFailed
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)

        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw ThumbnailError.encodingFailed
        }

        try data.write(to: destination)
    }

    private func generateVideoThumbnail(source: URL, destination: URL, size: Int) async throws {
        let asset = AVAsset(url: source)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size, height: size)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 2)

        let duration = try await asset.load(.duration)
        let halfTime = CMTimeMultiplyByFloat64(duration, multiplier: 0.5)

        let cgImage = try await generator.image(at: halfTime).image
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)

        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw ThumbnailError.encodingFailed
        }

        try data.write(to: destination)
    }
}

enum ThumbnailError: Error {
    case invalidSource
    case generationFailed
    case encodingFailed
}
