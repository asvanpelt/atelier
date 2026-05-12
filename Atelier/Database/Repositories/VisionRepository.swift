import Foundation
import GRDB

final class VisionRepository: @unchecked Sendable {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    // MARK: - Classifications

    func saveClassifications(_ classifications: [VisionClassification]) async throws {
        let pool = try db.pool
        try await pool.write { db in
            for item in classifications {
                try db.execute(
                    sql: """
                        INSERT OR REPLACE INTO vision_classifications (asset_id, label, confidence)
                        VALUES (?, ?, ?)
                        """,
                    arguments: [item.assetId, item.label, item.confidence]
                )
            }
        }
    }

    func classificationsFor(assetId: Int64) async throws -> [VisionClassification] {
        let pool = try db.pool
        return try await pool.read { db in
            try VisionClassification
                .filter(VisionClassification.Columns.assetId == assetId)
                .order(VisionClassification.Columns.confidence.desc)
                .fetchAll(db)
        }
    }

    func assetsByClassification(label: String, minConfidence: Double = 0.5) async throws -> [Int64] {
        let pool = try db.pool
        return try await pool.read { db in
            try Int64.fetchAll(db, sql:
                "SELECT asset_id FROM vision_classifications WHERE label = ? AND confidence >= ? ORDER BY confidence DESC",
                arguments: [label, minConfidence]
            )
        }
    }

    // MARK: - OCR

    func saveOCR(assetId: Int64, text: String, language: String?) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "DELETE FROM ocr_fts WHERE asset_id = ?",
                arguments: [assetId]
            )
            try db.execute(
                sql: "INSERT INTO ocr_fts (asset_id, text, language) VALUES (?, ?, ?)",
                arguments: [assetId, text, language ?? ""]
            )
        }
    }

    func ocrTextFor(assetId: Int64) async throws -> String? {
        let pool = try db.pool
        return try await pool.read { db in
            try String.fetchOne(db, sql:
                "SELECT text FROM ocr_fts WHERE asset_id = ?",
                arguments: [assetId]
            )
        }
    }

    func searchOCR(query: String) async throws -> [Int64] {
        let pool = try db.pool
        return try await pool.read { db in
            try Int64.fetchAll(db, sql:
                "SELECT asset_id FROM ocr_fts WHERE text MATCH ?",
                arguments: [query]
            )
        }
    }

    // MARK: - Face Observations

    func saveFaceObservations(_ faces: [FaceObservation]) async throws {
        let pool = try db.pool
        try await pool.write { db in
            for var face in faces {
                try face.insert(db)
            }
        }
    }

    func facesFor(assetId: Int64) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.assetId == assetId)
                .fetchAll(db)
        }
    }

    func unconfirmedFaces(limit: Int = 50) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.personId != nil)
                .filter(FaceObservation.Columns.isConfirmed == false)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func confirmFace(id: Int64, personId: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET person_id = ?, is_confirmed = 1 WHERE id = ?",
                arguments: [personId, id]
            )
        }
    }

    func rejectFace(id: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET person_id = NULL, is_confirmed = 0 WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func faceCountFor(personId: Int64) async throws -> Int {
        let pool = try db.pool
        return try await pool.read { db in
            try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM face_observations WHERE person_id = ? AND is_confirmed = 1",
                arguments: [personId]
            ) ?? 0
        }
    }
}
