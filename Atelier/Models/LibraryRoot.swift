import Foundation
import GRDB

struct LibraryRoot: Codable {
    var id: Int64?
    var path: String
    var bookmarkData: Data
    var label: String?
    var isExternal: Bool
    var lastScanAt: Date?
    var enabled: Bool

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let path = Column(CodingKeys.path)
        static let bookmarkData = Column(CodingKeys.bookmarkData)
        static let label = Column(CodingKeys.label)
        static let isExternal = Column(CodingKeys.isExternal)
        static let lastScanAt = Column(CodingKeys.lastScanAt)
        static let enabled = Column(CodingKeys.enabled)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case bookmarkData = "bookmark_data"
        case label
        case isExternal = "is_external"
        case lastScanAt = "last_scan_at"
        case enabled
    }
}

extension LibraryRoot: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "library_roots"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension LibraryRoot {
    var url: URL {
        URL(fileURLWithPath: path)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
