import Foundation
import GRDB

struct AssetTag: Codable {
    var assetId: Int64
    var tagId: Int64
    var source: String
    var confidence: Double?
    var createdAt: Date

    enum Columns {
        static let assetId = Column(CodingKeys.assetId)
        static let tagId = Column(CodingKeys.tagId)
        static let source = Column(CodingKeys.source)
        static let confidence = Column(CodingKeys.confidence)
    }

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case tagId = "tag_id"
        case source
        case confidence
        case createdAt = "created_at"
    }
}

extension AssetTag: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "asset_tags"
}

enum TagSource: String {
    case manual
    case autoVision = "auto-vision"
    case autoClip = "auto-clip"
    case autoVlm = "auto-vlm"
    case autoRule = "auto-rule"
}
