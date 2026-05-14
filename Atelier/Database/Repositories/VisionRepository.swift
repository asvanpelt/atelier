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

    func unassignedFaces(limit: Int = 500) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation.fetchAll(db, sql: """
                SELECT * FROM face_observations
                WHERE person_id IS NULL AND id IN (
                    SELECT MIN(id) FROM face_observations
                    WHERE person_id IS NULL
                    GROUP BY asset_id
                )
                ORDER BY asset_id DESC
                LIMIT ?
                """, arguments: [limit])
        }
    }

    func unassignedFaceCount() async throws -> Int {
        let pool = try db.pool
        return try await pool.read { db in
            try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM face_observations WHERE person_id IS NULL"
            ) ?? 0
        }
    }

    func confirmedFacesFor(personId: Int64) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.personId == personId)
                .filter(FaceObservation.Columns.isConfirmed == true)
                .fetchAll(db)
        }
    }

    func mergePersons(from sourceId: Int64, into targetId: Int64) async throws {
        guard sourceId != targetId else { return }
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET person_id = ? WHERE person_id = ?",
                arguments: [targetId, sourceId]
            )
            try db.execute(sql: "DELETE FROM persons WHERE id = ?", arguments: [sourceId])
        }
    }

    func updateEmbedding(id: Int64, data: Data) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET embedding = ? WHERE id = ?",
                arguments: [data, id]
            )
        }
    }

    func updateCluster(id: Int64, clusterId: Int64?) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET cluster_id = ? WHERE id = ?",
                arguments: [clusterId, id]
            )
        }
    }

    func facesWithEmbeddingUnassigned() async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.personId == nil)
                .filter(FaceObservation.Columns.embedding != nil)
                .fetchAll(db)
        }
    }

    func facesNeedingEmbedding(limit: Int = 5000) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.embedding == nil)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func confirmedFacesWithEmbedding() async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.personId != nil)
                .filter(FaceObservation.Columns.isConfirmed == true)
                .filter(FaceObservation.Columns.embedding != nil)
                .fetchAll(db)
        }
    }

    func nextClusterId() async throws -> Int64 {
        let pool = try db.pool
        return try await pool.read { db in
            (try Int64.fetchOne(db, sql: "SELECT COALESCE(MAX(cluster_id), 0) FROM face_observations") ?? 0) + 1
        }
    }

    func clusterSummary() async throws -> [(clusterId: Int64, count: Int, sampleFaceId: Int64)] {
        let pool = try db.pool
        return try await pool.read { db in
            try Row.fetchAll(db, sql: """
                SELECT cluster_id, COUNT(*) AS c, MIN(id) AS sample
                FROM face_observations
                WHERE person_id IS NULL AND cluster_id IS NOT NULL
                GROUP BY cluster_id
                ORDER BY c DESC
                """).map { row in
                (row["cluster_id"] as Int64, row["c"] as Int, row["sample"] as Int64)
            }
        }
    }

    func facesInCluster(_ clusterId: Int64) async throws -> [FaceObservation] {
        let pool = try db.pool
        return try await pool.read { db in
            try FaceObservation
                .filter(FaceObservation.Columns.clusterId == clusterId)
                .filter(FaceObservation.Columns.personId == nil)
                .fetchAll(db)
        }
    }

    func assignClusterToPerson(clusterId: Int64, personId: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET person_id = ?, is_confirmed = 1 WHERE cluster_id = ? AND person_id IS NULL",
                arguments: [personId, clusterId]
            )
        }
    }

    func resetClusters() async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(sql: "UPDATE face_observations SET cluster_id = NULL WHERE person_id IS NULL")
        }
    }

    func reassignFace(id: Int64, toPersonId: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE face_observations SET person_id = ?, is_confirmed = 1 WHERE id = ?",
                arguments: [toPersonId, id]
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
