import Foundation
import GRDB

struct Tag: Codable {
    var id: Int64?
    var namespace: String?
    var value: String
    var parentId: Int64?
    var color: String?
    var tagDescription: String?
    var createdAt: Date

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let namespace = Column(CodingKeys.namespace)
        static let value = Column(CodingKeys.value)
        static let parentId = Column(CodingKeys.parentId)
        static let color = Column(CodingKeys.color)
        static let tagDescription = Column(CodingKeys.tagDescription)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case namespace
        case value
        case parentId = "parent_id"
        case color
        case tagDescription = "description"
        case createdAt = "created_at"
    }
}

extension Tag: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "tags"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Tag {
    var displayName: String {
        if let ns = namespace {
            return "\(ns):\(value)"
        }
        return value
    }

    var displayColor: (hue: Double, saturation: Double, brightness: Double) {
        if let color, let hue = Double(color) {
            return (hue, 0.6, 0.8)
        }
        guard let ns = namespace else {
            return (0.0, 0.0, 0.7)
        }
        let hash = abs(ns.hashValue)
        let hue = Double(hash % 360) / 360.0
        return (hue, 0.6, 0.8)
    }
}
