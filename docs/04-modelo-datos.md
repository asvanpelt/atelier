# 04 · Modelo de datos

Esquema completo de SQLite. Incluye el núcleo del producto + el sistema Organize Engine.

## Convenciones

- Timestamps en `INTEGER` (Unix epoch en segundos)
- Booleanos en `INTEGER` (0/1)
- IDs `INTEGER PRIMARY KEY` (alias de rowid)
- Soft delete con `deleted_at INTEGER` (null = activo)
- Migraciones numeradas, una por archivo, irrevocables

## Tablas núcleo

### `assets` — archivos físicos indexados

```sql
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
);

CREATE INDEX idx_assets_path ON assets(file_path);
CREATE INDEX idx_assets_hash ON assets(file_hash);
CREATE INDEX idx_assets_created ON assets(created_at DESC);
CREATE INDEX idx_assets_indexed ON assets(indexed_at) WHERE indexed_at IS NULL;
```

### `library_roots` — carpetas vigiladas

```sql
CREATE TABLE library_roots (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    bookmark_data BLOB NOT NULL,
    label TEXT,
    is_external BOOLEAN DEFAULT 0,
    last_scan_at INTEGER,
    enabled BOOLEAN DEFAULT 1
);
```

### `tags` — taxonomía con namespaces

```sql
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
);

CREATE INDEX idx_tags_namespace ON tags(namespace);
```

### `asset_tags` — relación N:M assets ↔ tags

```sql
CREATE TABLE asset_tags (
    asset_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    source TEXT NOT NULL,
    confidence REAL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (asset_id, tag_id),
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE INDEX idx_asset_tags_tag ON asset_tags(tag_id);
```

### `persons` y `face_observations`

```sql
CREATE TABLE persons (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    namespace TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL
);

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
);

CREATE INDEX idx_faces_asset ON face_observations(asset_id);
CREATE INDEX idx_faces_person ON face_observations(person_id);
```

## Tablas vectoriales (sqlite-vec)

sqlite-vec exige dimensión fija por tabla virtual. Separamos por tipo de embedding.

### Face embeddings (Apple Vision face print)

```sql
CREATE VIRTUAL TABLE face_embeddings USING vec0(
    embedding FLOAT[128]
);

CREATE TABLE face_embedding_map (
    face_observation_id INTEGER PRIMARY KEY,
    vec_rowid INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (face_observation_id) REFERENCES face_observations(id) ON DELETE CASCADE
);
```

### CLIP embeddings (búsqueda semántica)

```sql
CREATE VIRTUAL TABLE clip_embeddings USING vec0(
    embedding FLOAT[512]
);

CREATE TABLE clip_embedding_map (
    asset_id INTEGER PRIMARY KEY,
    vec_rowid INTEGER NOT NULL UNIQUE,
    model_version TEXT NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);
```

### Vision FeaturePrint (similitud visual)

```sql
CREATE VIRTUAL TABLE vision_embeddings USING vec0(
    embedding FLOAT[768]
);

CREATE TABLE vision_embedding_map (
    asset_id INTEGER PRIMARY KEY,
    vec_rowid INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);
```

## Búsqueda de texto (FTS5)

### OCR

```sql
CREATE VIRTUAL TABLE ocr_fts USING fts5(
    asset_id UNINDEXED,
    text,
    language UNINDEXED,
    tokenize='unicode61 remove_diacritics 2'
);
```

### Descripciones VLM (preparado para Fase 9)

```sql
CREATE VIRTUAL TABLE description_fts USING fts5(
    asset_id UNINDEXED,
    description,
    model_version UNINDEXED,
    tokenize='unicode61 remove_diacritics 2'
);
```

## Clasificaciones automáticas

```sql
CREATE TABLE vision_classifications (
    asset_id INTEGER NOT NULL,
    label TEXT NOT NULL,
    confidence REAL NOT NULL,
    PRIMARY KEY (asset_id, label),
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

CREATE INDEX idx_classifications_label ON vision_classifications(label, confidence DESC);
```

## Colecciones

```sql
CREATE TABLE collections (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    smart_query TEXT,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

CREATE TABLE collection_assets (
    collection_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (collection_id, asset_id),
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);
```

## Duplicados

```sql
CREATE TABLE duplicate_groups (
    id INTEGER PRIMARY KEY,
    primary_asset_id INTEGER NOT NULL,
    similarity_method TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (primary_asset_id) REFERENCES assets(id) ON DELETE CASCADE
);
```

```sql
CREATE TABLE duplicate_members (
    group_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    similarity REAL NOT NULL,
    PRIMARY KEY (group_id, asset_id),
    FOREIGN KEY (group_id) REFERENCES duplicate_groups(id) ON DELETE CASCADE,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);
```

## Organize Engine

### `organize_rules` — reglas guardadas

```sql
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
);
```

### `organize_runs` — ejecuciones

```sql
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
);
```

### `organize_operations` — una entrada por archivo afectado

```sql
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
);

CREATE INDEX idx_operations_run ON organize_operations(run_id);
CREATE INDEX idx_operations_asset ON organize_operations(asset_id);
CREATE INDEX idx_operations_status ON organize_operations(status);
```

### `asset_path_history` — audit log de rutas

```sql
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
);

CREATE INDEX idx_path_history_asset ON asset_path_history(asset_id, valid_from);
CREATE INDEX idx_path_history_current ON asset_path_history(asset_id) WHERE valid_to IS NULL;
```

## Configuración y metadata

```sql
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE app_metrics (
    id INTEGER PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    metadata TEXT,
    recorded_at INTEGER NOT NULL
);

CREATE INDEX idx_metrics_name_time ON app_metrics(metric_name, recorded_at DESC);
```

## Notas de diseño

### Hash como identidad secundaria
Si el usuario mueve un archivo por Finder, el `file_path` cambia pero el `file_hash` no. Al escanear, podemos reidentificar el asset y actualizar el path en lugar de reindexar todo.

### Versionado de indexación
`indexing_version` permite hacer reindexado selectivo cuando cambiamos modelos. Si subimos de CLIP ViT-B/32 a ViT-L/14, actualizamos `indexing_version` y procesamos solo los pendientes.

### Soft delete con embeddings preservados
No borramos rows físicamente. Si el archivo desaparece, marcamos `deleted_at`. Si reaparece (mismo hash), lo "resucitamos" sin reindexar. Solo limpiamos rows muy antiguos (90+ días) en mantenimiento.

### Pragmas recomendadas

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA cache_size = -64000;
PRAGMA mmap_size = 268435456;
PRAGMA temp_store = MEMORY;
```

### Ubicación física de la DB

```
~/Library/Application Support/Atelier/
├── atelier.db
├── atelier.db-wal
├── atelier.db-shm
├── thumbnails/
│   ├── 200/
│   ├── 400/
│   └── 800/
├── models/
└── organize-trash/
    └── run-{id}/
```
