import Foundation
import GRDB

final class Database {
    private var dbPool: DatabasePool?

    var pool: DatabasePool {
        get throws {
            guard let pool = dbPool else {
                throw DatabaseError.notSetup
            }
            return pool
        }
    }

    enum DatabaseError: Error {
        case notSetup
    }

    func setup() throws {
        let appSupport = AppConstants.appSupportDir

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: AppConstants.thumbnailsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: AppConstants.organizeTrashDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: AppConstants.backupsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: AppConstants.cachesDir, withIntermediateDirectories: true)

        let dbURL = AppConstants.databaseURL
        let pool = try DatabasePool(path: dbURL.path)

        try pool.writeWithoutTransaction { db in
            try applyPragmas(db)
        }

        var migrator = DatabaseMigrator()
        migrator.registerMigration("M001_InitialSchema") { db in
            try M001_InitialSchema.migrate(db)
        }
        migrator.registerMigration("M002_VectorTables") { db in
            try M002_VectorTables.migrate(db)
        }
        migrator.registerMigration("M003_OrganizeEngine") { db in
            try M003_OrganizeEngine.migrate(db)
        }
        migrator.registerMigration("M004_AssetSource") { db in
            try M004_AssetSource.migrate(db)
        }
        migrator.registerMigration("M005_FaceClustering") { db in
            try M005_FaceClustering.migrate(db)
        }

        try migrator.migrate(pool)
        self.dbPool = pool
    }

    private func applyPragmas(_ db: GRDB.Database) throws {
        try db.execute(sql: "PRAGMA journal_mode = WAL")
        try db.execute(sql: "PRAGMA synchronous = NORMAL")
        try db.execute(sql: "PRAGMA foreign_keys = ON")
        try db.execute(sql: "PRAGMA cache_size = -64000")
        try db.execute(sql: "PRAGMA mmap_size = 268435456")
        try db.execute(sql: "PRAGMA temp_store = MEMORY")
    }
}
