import Foundation
import GRDB

struct Person: Codable {
    var id: Int64?
    var name: String
    var namespace: String?
    var notes: String?
    var createdAt: Date

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let namespace = Column(CodingKeys.namespace)
        static let notes = Column(CodingKeys.notes)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case namespace
        case notes
        case createdAt = "created_at"
    }
}

extension Person: Identifiable {}

extension Person: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "persons"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
