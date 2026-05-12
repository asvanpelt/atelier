import GRDB

enum M001_InitialSchema {
    static func migrate(_ db: GRDB.Database) throws {
        try db.execute(sql: """
            CREATE TABLE assets (
                id INTEGER PRIMARY KEY,
                file_path TEXT UNIQUE NOT NULL,
                file_hash TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                mime_type TEXT NOT NULL,
                media_type TEXT NOT NULL,
                width INTEGER,
                height INTEGER,
                duration_ms INTEGER,
                created_at INTEGER NOT NULL,
                modified_at INTEGER NOT NULL,
                imported_at INTEGER NOT NULL,
                indexed_at INTEGER,
                indexing_version INTEGER DEFAULT 0,
                deleted_at INTEGER
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_assets_path ON assets(file_path)")
        try db.execute(sql: "CREATE INDEX idx_assets_hash ON assets(file_hash)")
        try db.execute(sql: "CREATE INDEX idx_assets_created ON assets(created_at DESC)")
        try db.execute(sql: "CREATE INDEX idx_assets_indexed ON assets(indexed_at) WHERE indexed_at IS NULL")

        try db.execute(sql: """
            CREATE TABLE library_roots (
                id INTEGER PRIMARY KEY,
                path TEXT UNIQUE NOT NULL,
                bookmark_data BLOB NOT NULL,
                label TEXT,
                is_external BOOLEAN DEFAULT 0,
                last_scan_at INTEGER,
                enabled BOOLEAN DEFAULT 1
            )
            """)

        try db.execute(sql: """
            CREATE TABLE tags (
                id INTEGER PRIMARY KEY,
                namespace TEXT,
                value TEXT NOT NULL,
                parent_id INTEGER,
                color TEXT,
                description TEXT,
                created_at INTEGER NOT NULL,
                UNIQUE(namespace, value),
                FOREIGN KEY (parent_id) REFERENCES tags(id)
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_tags_namespace ON tags(namespace)")

        try db.execute(sql: """
            CREATE TABLE asset_tags (
                asset_id INTEGER NOT NULL,
                tag_id INTEGER NOT NULL,
                source TEXT NOT NULL,
                confidence REAL,
                created_at INTEGER NOT NULL,
                PRIMARY KEY (asset_id, tag_id),
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_asset_tags_tag ON asset_tags(tag_id)")

        try db.execute(sql: """
            CREATE TABLE persons (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                namespace TEXT,
                notes TEXT,
                created_at INTEGER NOT NULL
            )
            """)

        try db.execute(sql: """
            CREATE TABLE face_observations (
                id INTEGER PRIMARY KEY,
                asset_id INTEGER NOT NULL,
                bbox_x REAL NOT NULL,
                bbox_y REAL NOT NULL,
                bbox_w REAL NOT NULL,
                bbox_h REAL NOT NULL,
                quality REAL,
                person_id INTEGER,
                confidence REAL,
                is_confirmed BOOLEAN DEFAULT 0,
                is_reference BOOLEAN DEFAULT 0,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
                FOREIGN KEY (person_id) REFERENCES persons(id)
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_faces_asset ON face_observations(asset_id)")
        try db.execute(sql: "CREATE INDEX idx_faces_person ON face_observations(person_id)")

        try db.execute(sql: """
            CREATE TABLE face_embedding_map (
                face_observation_id INTEGER PRIMARY KEY,
                vec_rowid INTEGER NOT NULL UNIQUE,
                FOREIGN KEY (face_observation_id) REFERENCES face_observations(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE TABLE clip_embedding_map (
                asset_id INTEGER PRIMARY KEY,
                vec_rowid INTEGER NOT NULL UNIQUE,
                model_version TEXT NOT NULL,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE TABLE vision_embedding_map (
                asset_id INTEGER PRIMARY KEY,
                vec_rowid INTEGER NOT NULL UNIQUE,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE VIRTUAL TABLE ocr_fts USING fts5(
                asset_id UNINDEXED,
                text,
                language UNINDEXED,
                tokenize='unicode61 remove_diacritics 2'
            )
            """)

        try db.execute(sql: """
            CREATE VIRTUAL TABLE description_fts USING fts5(
                asset_id UNINDEXED,
                description,
                model_version UNINDEXED,
                tokenize='unicode61 remove_diacritics 2'
            )
            """)

        try db.execute(sql: """
            CREATE TABLE vision_classifications (
                asset_id INTEGER NOT NULL,
                label TEXT NOT NULL,
                confidence REAL NOT NULL,
                PRIMARY KEY (asset_id, label),
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_classifications_label ON vision_classifications(label, confidence DESC)")

        try db.execute(sql: """
            CREATE TABLE collections (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                smart_query TEXT,
                icon TEXT,
                sort_order INTEGER DEFAULT 0,
                created_at INTEGER NOT NULL
            )
            """)

        try db.execute(sql: """
            CREATE TABLE collection_assets (
                collection_id INTEGER NOT NULL,
                asset_id INTEGER NOT NULL,
                added_at INTEGER NOT NULL,
                PRIMARY KEY (collection_id, asset_id),
                FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE TABLE duplicate_groups (
                id INTEGER PRIMARY KEY,
                primary_asset_id INTEGER NOT NULL,
                similarity_method TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (primary_asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE TABLE duplicate_members (
                group_id INTEGER NOT NULL,
                asset_id INTEGER NOT NULL,
                similarity REAL NOT NULL,
                PRIMARY KEY (group_id, asset_id),
                FOREIGN KEY (group_id) REFERENCES duplicate_groups(id) ON DELETE CASCADE,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: """
            CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """)

        try db.execute(sql: """
            CREATE TABLE app_metrics (
                id INTEGER PRIMARY KEY,
                metric_name TEXT NOT NULL,
                metric_value REAL NOT NULL,
                metadata TEXT,
                recorded_at INTEGER NOT NULL
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_metrics_name_time ON app_metrics(metric_name, recorded_at DESC)")
    }
}
