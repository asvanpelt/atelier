import Foundation
import UniformTypeIdentifiers

extension URL {
    var mimeType: String {
        if let type = UTType(filenameExtension: pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    var isImage: Bool {
        guard let type = UTType(filenameExtension: pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .heic) || type.conforms(to: .heif)
    }

    var isVideo: Bool {
        guard let type = UTType(filenameExtension: pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    var mediaType: MediaType {
        if isImage { return .image }
        if isVideo { return .video }
        return .unknown
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var fileSize: Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return 0
        }
        return (attrs[.size] as? Int64) ?? 0
    }

    var modificationDate: Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }

    var creationDate: Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attrs[.creationDate] as? Date
    }

    func isDescendant(of root: URL) -> Bool {
        let rootPath = root.standardized.path.hasSuffix("/")
            ? root.standardized.path
            : root.standardized.path + "/"
        return standardized.path.hasPrefix(rootPath)
    }
}
