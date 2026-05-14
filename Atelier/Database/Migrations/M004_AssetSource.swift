import GRDB

enum M004_AssetSource {
    static func migrate(_ db: GRDB.Database) throws {
        try db.execute(sql: "ALTER TABLE assets ADD COLUMN source TEXT")
        try db.execute(sql: "ALTER TABLE assets ADD COLUMN source_account TEXT")
        try db.execute(sql: "CREATE INDEX idx_assets_source ON assets(source)")
        try db.execute(sql: "CREATE INDEX idx_assets_source_account ON assets(source_account)")
    }
}
