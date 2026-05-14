import Foundation
import GRDB

enum MediaType: String, Codable, DatabaseValueConvertible {
    case image
    case video
    case unknown
}

struct Asset: Codable {
    var id: Int64?
    var filePath: String
    var fileHash: String
    var fileSize: Int64
    var mimeType: String
    var mediaType: MediaType
    var width: Int?
    var height: Int?
    var durationMs: Int?
    var createdAt: Date
    var modifiedAt: Date
    var importedAt: Date
    var indexedAt: Date?
    var indexingVersion: Int
    var deletedAt: Date?
    var source: String?
    var sourceAccount: String?

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let filePath = Column(CodingKeys.filePath)
        static let fileHash = Column(CodingKeys.fileHash)
        static let fileSize = Column(CodingKeys.fileSize)
        static let mimeType = Column(CodingKeys.mimeType)
        static let mediaType = Column(CodingKeys.mediaType)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let durationMs = Column(CodingKeys.durationMs)
        static let createdAt = Column(CodingKeys.createdAt)
        static let modifiedAt = Column(CodingKeys.modifiedAt)
        static let importedAt = Column(CodingKeys.importedAt)
        static let indexedAt = Column(CodingKeys.indexedAt)
        static let indexingVersion = Column(CodingKeys.indexingVersion)
        static let deletedAt = Column(CodingKeys.deletedAt)
        static let source = Column(CodingKeys.source)
        static let sourceAccount = Column(CodingKeys.sourceAccount)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case filePath = "file_path"
        case fileHash = "file_hash"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case mediaType = "media_type"
        case width
        case height
        case durationMs = "duration_ms"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case importedAt = "imported_at"
        case indexedAt = "indexed_at"
        case indexingVersion = "indexing_version"
        case deletedAt = "deleted_at"
        case source
        case sourceAccount = "source_account"
    }
}

extension Asset: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "assets"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Asset {
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }
}
