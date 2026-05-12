import Foundation
import GRDB

final class AssetRepository: @unchecked Sendable {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func findAll(excludeDeleted: Bool = true) async throws -> [Asset] {
        let pool = try db.pool
        return try await pool.read { db in
            var request = Asset.all()
            if excludeDeleted {
                request = request.filter(Asset.Columns.deletedAt == nil)
            }
            return try request.order(Asset.Columns.importedAt.desc).fetchAll(db)
        }
    }

    func findByPath(_ path: String) async throws -> Asset? {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset.filter(Asset.Columns.filePath == path).fetchOne(db)
        }
    }

    func findByHash(_ hash: String) async throws -> Asset? {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset.filter(Asset.Columns.fileHash == hash).fetchOne(db)
        }
    }

    func find(id: Int64) async throws -> Asset? {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset.fetchOne(db, key: id)
        }
    }

    func count(excludeDeleted: Bool = true) async throws -> Int {
        let pool = try db.pool
        return try await pool.read { db in
            var request = Asset.all()
            if excludeDeleted {
                request = request.filter(Asset.Columns.deletedAt == nil)
            }
            return try request.fetchCount(db)
        }
    }

    func insert(_ asset: Asset) async throws -> Asset {
        let pool = try db.pool
        return try await pool.write { db in
            var asset = asset
            try asset.insert(db)
            return asset
        }
    }

    func upsert(_ asset: Asset) async throws -> Asset {
        let pool = try db.pool
        return try await pool.write { db in
            if let existing = try Asset
                .filter(Asset.Columns.filePath == asset.filePath)
                .fetchOne(db) {
                var updated = asset
                updated.id = existing.id
                try updated.update(db)
                return updated
            } else {
                var new = asset
                try new.insert(db)
                return new
            }
        }
    }

    func updatePath(id: Int64, newPath: String) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE assets SET file_path = ? WHERE id = ?",
                arguments: [newPath, id]
            )
        }
    }

    func markDeleted(id: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE assets SET deleted_at = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    func markIndexed(id: Int64, version: Int = 1) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE assets SET indexed_at = ?, indexing_version = ? WHERE id = ?",
                arguments: [Date(), version, id]
            )
        }
    }

    func findByRoot(_ rootPath: String) async throws -> [Asset] {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset
                .filter(Asset.Columns.filePath.like("\(rootPath)%"))
                .filter(Asset.Columns.deletedAt == nil)
                .fetchAll(db)
        }
    }

    func pendingIndex(count: Int) async throws -> [Asset] {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset
                .filter(Asset.Columns.indexedAt == nil)
                .filter(Asset.Columns.deletedAt == nil)
                .order(Asset.Columns.importedAt.asc)
                .limit(count)
                .fetchAll(db)
        }
    }

    func totalCount() async throws -> Int {
        let pool = try db.pool
        return try await pool.read { db in
            try Asset
                .filter(Asset.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    func search(query: String, rootPath: String? = nil) async throws -> [Asset] {
        let pool = try db.pool
        return try await pool.read { db in
            var request = Asset
                .filter(Asset.Columns.deletedAt == nil)

            if let rootPath {
                request = request.filter(Asset.Columns.filePath.like("\(rootPath)%"))
            }

            let pattern = "%\(query)%"
            request = request.filter(Asset.Columns.filePath.like(pattern))

            return try request.order(Asset.Columns.importedAt.desc).fetchAll(db)
        }
    }

    func allPathsForRoot(_ rootPath: String) async throws -> Set<String> {
        let pool = try db.pool
        return try await pool.read { db in
            let paths = try String.fetchAll(db, sql:
                "SELECT file_path FROM assets WHERE file_path LIKE ? AND deleted_at IS NULL",
                arguments: ["\(rootPath)%"]
            )
            return Set(paths)
        }
    }
}
