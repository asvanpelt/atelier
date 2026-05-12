import GRDB

enum M002_VectorTables {
    static func migrate(_ db: GRDB.Database) throws {
        let vecAvailable = sqliteVecAvailable(db)
        if !vecAvailable {
            Logger.database.warning("sqlite-vec no está disponible. Las tablas vectoriales no se crearán.")
            return
        }

        try db.execute(sql: """
            CREATE VIRTUAL TABLE face_embeddings USING vec0(
                embedding FLOAT[128]
            )
            """)

        try db.execute(sql: """
            CREATE VIRTUAL TABLE clip_embeddings USING vec0(
                embedding FLOAT[512]
            )
            """)

        try db.execute(sql: """
            CREATE VIRTUAL TABLE vision_embeddings USING vec0(
                embedding FLOAT[768]
            )
            """)

        Logger.database.info("Tablas vectoriales creadas correctamente")
    }

    private static func sqliteVecAvailable(_ db: GRDB.Database) -> Bool {
        do {
            _ = try Row.fetchOne(db, sql: "SELECT vec_version()")
            return true
        } catch {
            return false
        }
    }
}
