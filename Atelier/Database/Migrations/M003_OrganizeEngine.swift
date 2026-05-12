import GRDB

enum M003_OrganizeEngine {
    static func migrate(_ db: GRDB.Database) throws {
        try db.execute(sql: """
            CREATE TABLE organize_rules (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                match_query TEXT NOT NULL,
                action_type TEXT NOT NULL,
                destination_root TEXT,
                path_template TEXT NOT NULL,
                conflict_policy TEXT NOT NULL,
                requires_confirmation BOOLEAN DEFAULT 1,
                auto_run_on_new BOOLEAN DEFAULT 0,
                is_enabled BOOLEAN DEFAULT 1,
                priority INTEGER DEFAULT 100,
                created_at INTEGER NOT NULL,
                last_run_at INTEGER,
                run_count INTEGER DEFAULT 0
            )
            """)

        try db.execute(sql: """
            CREATE TABLE organize_runs (
                id INTEGER PRIMARY KEY,
                rule_id INTEGER,
                mode TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                finished_at INTEGER,
                status TEXT NOT NULL,
                total_assets INTEGER DEFAULT 0,
                succeeded INTEGER DEFAULT 0,
                failed INTEGER DEFAULT 0,
                skipped INTEGER DEFAULT 0,
                summary TEXT,
                rollback_available BOOLEAN DEFAULT 1,
                rollback_expires_at INTEGER,
                rolled_back_at INTEGER,
                FOREIGN KEY (rule_id) REFERENCES organize_rules(id) ON DELETE SET NULL
            )
            """)

        try db.execute(sql: """
            CREATE TABLE organize_operations (
                id INTEGER PRIMARY KEY,
                run_id INTEGER NOT NULL,
                asset_id INTEGER NOT NULL,
                operation_type TEXT NOT NULL,
                source_path TEXT NOT NULL,
                destination_path TEXT NOT NULL,
                source_hash_at_plan TEXT,
                source_existed_before BOOLEAN,
                destination_existed_before BOOLEAN,
                destination_replaced_hash TEXT,
                destination_replaced_trash_path TEXT,
                status TEXT NOT NULL,
                error TEXT,
                applied_at INTEGER,
                reverted_at INTEGER,
                FOREIGN KEY (run_id) REFERENCES organize_runs(id) ON DELETE CASCADE,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_operations_run ON organize_operations(run_id)")
        try db.execute(sql: "CREATE INDEX idx_operations_asset ON organize_operations(asset_id)")
        try db.execute(sql: "CREATE INDEX idx_operations_status ON organize_operations(status)")

        try db.execute(sql: """
            CREATE TABLE asset_path_history (
                id INTEGER PRIMARY KEY,
                asset_id INTEGER NOT NULL,
                path TEXT NOT NULL,
                valid_from INTEGER NOT NULL,
                valid_to INTEGER,
                changed_by TEXT NOT NULL,
                operation_id INTEGER,
                FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
                FOREIGN KEY (operation_id) REFERENCES organize_operations(id) ON DELETE SET NULL
            )
            """)

        try db.execute(sql: "CREATE INDEX idx_path_history_asset ON asset_path_history(asset_id, valid_from)")
        try db.execute(sql: "CREATE INDEX idx_path_history_current ON asset_path_history(asset_id) WHERE valid_to IS NULL")
    }
}
