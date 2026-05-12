import Foundation
import GRDB

final class PersonRepository: @unchecked Sendable {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func findAll() async throws -> [Person] {
        let pool = try db.pool
        return try await pool.read { db in
            try Person.order(Person.Columns.name).fetchAll(db)
        }
    }

    func find(id: Int64) async throws -> Person? {
        let pool = try db.pool
        return try await pool.read { db in
            try Person.fetchOne(db, key: id)
        }
    }

    func insert(_ person: Person) async throws -> Person {
        let pool = try db.pool
        return try await pool.write { db in
            var person = person
            try person.insert(db)
            return person
        }
    }

    func update(_ person: Person) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try person.update(db)
        }
    }

    func delete(id: Int64) async throws {
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(sql: "UPDATE face_observations SET person_id = NULL WHERE person_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM persons WHERE id = ?", arguments: [id])
        }
    }

    func assetIdsFor(personId: Int64) async throws -> [Int64] {
        let pool = try db.pool
        return try await pool.read { db in
            try Int64.fetchAll(db, sql:
                "SELECT DISTINCT asset_id FROM face_observations WHERE person_id = ? AND (is_confirmed = 1 OR confidence > 0.65)",
                arguments: [personId]
            )
        }
    }
}
