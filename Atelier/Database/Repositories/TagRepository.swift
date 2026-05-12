import Foundation
import GRDB

final class TagRepository: @unchecked Sendable {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func findAll() async throws -> [Tag] {
        let pool = try db.pool
        return try await pool.read { db in
            try Tag.order(Tag.Columns.namespace, Tag.Columns.value).fetchAll(db)
        }
    }

    func findByNamespace(_ namespace: String) async throws -> [Tag] {
        let pool = try db.pool
        return try await pool.read { db in
            try Tag
                .filter(Tag.Columns.namespace == namespace)
                .order(Tag.Columns.value)
                .fetchAll(db)
        }
    }

    func findOrCreate(namespace: String?, value: String) async throws -> Tag {
        let pool = try db.pool
        return try await pool.write { db in
            if let existing = try Tag
                .filter(Tag.Columns.namespace == namespace)
                .filter(Tag.Columns.value == value)
                .fetchOne(db) {
                return existing
            }
            var tag = Tag(
                id: nil,
                namespace: namespace,
                value: value,
                parentId: nil,
                color: nil,
                tagDescription: nil,
                createdAt: Date()
            )
            try tag.insert(db)
            return tag
        }
    }

    func insert(_ tag: Tag) async throws -> Tag {
        let pool = try db.pool
        return try await pool.write { db in
            var tag = tag
            try tag.insert(db)
            return tag
        }
    }

    func update(_ tag: Tag) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try tag.update(db)
        }
    }

    func delete(id: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(sql: "DELETE FROM tags WHERE id = ?", arguments: [id])
        }
    }

    func search(query: String) async throws -> [Tag] {
        let pool = try db.pool
        return try await pool.read { db in
            try Tag
                .filter(Tag.Columns.value.like("%\(query)%"))
                .order(Tag.Columns.namespace, Tag.Columns.value)
                .limit(20)
                .fetchAll(db)
        }
    }

    // MARK: - Asset Tags

    func tagsFor(assetId: Int64) async throws -> [(tag: Tag, source: String, confidence: Double?)] {
        let pool = try db.pool
        return try await pool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT t.*, at.source, at.confidence
                FROM tags t
                JOIN asset_tags at ON at.tag_id = t.id
                WHERE at.asset_id = ?
                ORDER BY at.confidence DESC NULLS FIRST
                """,
                arguments: [assetId]
            )
            return try rows.map { row in
                let tag = try Tag(row: row)
                let source: String = row["source"]
                let confidence: Double? = row["confidence"]
                return (tag, source, confidence)
            }
        }
    }

    func assignTag(assetId: Int64, tagId: Int64, source: TagSource, confidence: Double? = nil) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO asset_tags (asset_id, tag_id, source, confidence, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [assetId, tagId, source.rawValue, confidence, Date()]
            )
        }
    }

    func removeTag(assetId: Int64, tagId: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "DELETE FROM asset_tags WHERE asset_id = ? AND tag_id = ?",
                arguments: [assetId, tagId]
            )
        }
    }

    func assetCountFor(tagId: Int64) async throws -> Int {
        let pool = try db.pool
        return try await pool.read { db in
            try Int.fetchOne(db, sql:
                "SELECT COUNT(*) FROM asset_tags WHERE tag_id = ?",
                arguments: [tagId]
            ) ?? 0
        }
    }

    func assetsFor(tagId: Int64) async throws -> [Int64] {
        let pool = try db.pool
        return try await pool.read { db in
            try Int64.fetchAll(db, sql:
                "SELECT asset_id FROM asset_tags WHERE tag_id = ?",
                arguments: [tagId]
            )
        }
    }

    func allNamespaces() async throws -> [String] {
        let pool = try db.pool
        return try await pool.read { db in
            try String.fetchAll(db, sql:
                "SELECT DISTINCT namespace FROM tags WHERE namespace IS NOT NULL ORDER BY namespace"
            )
        }
    }
}
