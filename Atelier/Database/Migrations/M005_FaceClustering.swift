import GRDB

enum M005_FaceClustering {
    static func migrate(_ db: GRDB.Database) throws {
        try db.execute(sql: "ALTER TABLE face_observations ADD COLUMN embedding BLOB")
        try db.execute(sql: "ALTER TABLE face_observations ADD COLUMN cluster_id INTEGER")
        try db.execute(sql: "CREATE INDEX idx_face_cluster ON face_observations(cluster_id) WHERE cluster_id IS NOT NULL")
        try db.execute(sql: "CREATE INDEX idx_face_person_embed ON face_observations(person_id) WHERE embedding IS NOT NULL")
    }
}
