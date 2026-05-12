import Foundation
import GRDB

final class LibraryRootRepository: @unchecked Sendable {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func findAll() async throws -> [LibraryRoot] {
        let pool = try db.pool
        return try await pool.read { db in
            try LibraryRoot
                .filter(LibraryRoot.Columns.enabled == true)
                .fetchAll(db)
        }
    }

    func find(id: Int64) async throws -> LibraryRoot? {
        let pool = try db.pool
        return try await pool.read { db in
            try LibraryRoot.fetchOne(db, key: id)
        }
    }

    func findByPath(_ path: String) async throws -> LibraryRoot? {
        let pool = try db.pool
        return try await pool.read { db in
            try LibraryRoot.filter(LibraryRoot.Columns.path == path).fetchOne(db)
        }
    }

    func insert(_ root: LibraryRoot) async throws -> LibraryRoot {
        let pool = try db.pool
        return try await pool.write { db in
            let root = root
            try root.insert(db)
            return root
        }
    }

    func updateLastScan(id: Int64, at date: Date) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE library_roots SET last_scan_at = ? WHERE id = ?",
                arguments: [date, id]
            )
        }
    }

    func setEnabled(id: Int64, enabled: Bool) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE library_roots SET enabled = ? WHERE id = ?",
                arguments: [enabled, id]
            )
        }
    }

    func delete(id: Int64) async throws {
        let pool = try db.pool
        _ = try await pool.write { db in
            try LibraryRoot.deleteOne(db, key: id)
        }
    }
}
