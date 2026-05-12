import Foundation
import GRDB

struct FaceObservation: Codable {
    var id: Int64?
    var assetId: Int64
    var bboxX: Double
    var bboxY: Double
    var bboxW: Double
    var bboxH: Double
    var quality: Double?
    var personId: Int64?
    var confidence: Double?
    var isConfirmed: Bool
    var isReference: Bool

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let assetId = Column(CodingKeys.assetId)
        static let personId = Column(CodingKeys.personId)
        static let confidence = Column(CodingKeys.confidence)
        static let isConfirmed = Column(CodingKeys.isConfirmed)
        static let isReference = Column(CodingKeys.isReference)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxW = "bbox_w"
        case bboxH = "bbox_h"
        case quality
        case personId = "person_id"
        case confidence
        case isConfirmed = "is_confirmed"
        case isReference = "is_reference"
    }
}

extension FaceObservation: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "face_observations"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
