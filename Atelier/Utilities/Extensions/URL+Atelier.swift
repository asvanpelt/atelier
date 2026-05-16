import Foundation
import UniformTypeIdentifiers

private let rawImageExtensions: Set<String> = [
    "dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "srf", "sr2",
    "raf", "orf", "rw2", "rwl", "pef", "ptx", "raw", "x3f",
    "3fr", "fff", "iiq", "mef", "mos", "mrw", "k25", "kdc", "dcr"
]

extension URL {
    var mimeType: String {
        if let type = UTType(filenameExtension: pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    var isRawImage: Bool {
        let ext = pathExtension.lowercased()
        if rawImageExtensions.contains(ext) { return true }
        if let type = UTType(filenameExtension: ext),
           type.conforms(to: .rawImage) {
            return true
        }
        return false
    }

    var isImage: Bool {
        guard !isRawImage else { return false }
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
