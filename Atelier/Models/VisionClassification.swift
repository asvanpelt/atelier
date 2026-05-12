import Foundation
import GRDB

struct VisionClassification: Codable {
    var assetId: Int64
    var label: String
    var confidence: Double

    enum Columns {
        static let assetId = Column(CodingKeys.assetId)
        static let label = Column(CodingKeys.label)
        static let confidence = Column(CodingKeys.confidence)
    }

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case label
        case confidence
    }
}

extension VisionClassification: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "vision_classifications"
}
