# 06 · Sistema de búsqueda

## Tipos de query

```swift
enum SearchQuery {
    case text(String)                          // texto libre, va a CLIP
    case tag(namespace: String?, value: String)
    case person(personId: Int64)
    case ocrText(String)
    case similarTo(assetId: Int64)
    case dateRange(from: Date, to: Date)
    case mediaType(MediaType)
    case folder(rootId: Int64)
    case classification(label: String, minConfidence: Double)
    case combined([SearchQuery], op: BoolOp)
}

enum BoolOp { case and, or, not }
```

## Pipeline de resolución

```
Input: "anya en alfombra roja"
                │
       ┌────────┴─────────┐
       │   Parser/Lexer    │
       │ Detecta:          │
       │ - Operadores      │
       │ - Texto libre     │
       │ - Comillas        │
       └────────┬──────────┘
                │
       ┌────────▼──────────┐
       │  Matchers en paralelo
   ┌───┼───┬───────────┬───┴──────┐
   │   │   │           │          │
   ▼   ▼   ▼           ▼          ▼
 Tag  Person  OCR    CLIP    Classification
                     encoder
   │   │   │           │          │
   └───┴───┴─────┬─────┴──────────┘
                 ▼
       Combinador + Ranking
                 ▼
            Resultados
```

## Sintaxis de búsqueda

### Texto libre
> `memes de gatos en cocina`

Va completo a CLIP encoder de texto. Devuelve top-N por similaridad.

### Operadores estructurados

```
tag:tema:programacion           → filtro por tag exacto
tag:tema                        → todos los assets con cualquier tag de namespace tema
persona:Anya                    → filtro por persona
texto:"this is fine"            → búsqueda FTS en OCR (entre comillas: exacto)
tipo:video                      → media type
tipo:imagen
desde:2024-01-01                → date range
hasta:2024-12-31
carpeta:Memes                   → library root específico
similar:asset:1234              → similar a otro asset
clase:perro                     → classification de Vision
```

### Combinaciones

```
tag:tema:programacion -plataforma:tiktok          → AND con negación
"memes de gatos" tipo:video                       → CLIP + filtro
persona:Anya desde:2024                           → person + date
```

Reglas del parser:
- Espacios entre términos = AND implícito
- Prefijo `-` = NOT
- Pipe `|` o palabra `or` entre términos = OR explícito
- Paréntesis para agrupar (futuro, fase 7+)

## Implementación de matchers

### Tag matcher

```swift
func matchTags(namespace: String?, value: String) async throws -> [Int64] {
    let sql: String
    let args: StatementArguments
    if let namespace {
        sql = """
            SELECT asset_id FROM asset_tags
            JOIN tags ON tags.id = asset_tags.tag_id
            WHERE tags.namespace = ? AND tags.value LIKE ?
            """
        args = [namespace, "%\(value)%"]
    } else {
        sql = "SELECT asset_id FROM asset_tags JOIN tags ON tags.id = asset_tags.tag_id WHERE tags.value LIKE ?"
        args = ["%\(value)%"]
    }
    return try await db.read { tx in try Int64.fetchAll(tx, sql: sql, arguments: args) }
}
```

### CLIP text search

```swift
func searchByText(_ query: String, limit: Int = 200) async throws -> [(Int64, Double)] {
    let textEmbedding = try await clipService.encodeText(query)
    let sql = """
        SELECT clip_embedding_map.asset_id, vec_distance_cosine(clip_embeddings.embedding, ?) AS score
        FROM clip_embeddings
        JOIN clip_embedding_map ON clip_embedding_map.vec_rowid = clip_embeddings.rowid
        ORDER BY score ASC
        LIMIT ?
        """
    return try await db.read { tx in
        try Row.fetchAll(tx, sql: sql, arguments: [textEmbedding.serialize(), limit])
            .map { ($0["asset_id"] as Int64, $0["score"] as Double) }
    }
}
```

### Similar to

```swift
func similarTo(assetId: Int64, limit: Int = 50) async throws -> [Int64] {
    // Usa Vision FeaturePrint, mejor para "se ve parecida" que CLIP
    // Implementación con sqlite-vec vec_search
}
```

### OCR full-text

```swift
func searchOCR(_ text: String, exact: Bool = false) async throws -> [Int64] {
    let ftsQuery = exact ? "\"\(text)\"" : text
    let sql = "SELECT asset_id FROM ocr_fts WHERE ocr_fts MATCH ? ORDER BY rank"
    return try await db.read { tx in
        try Int64.fetchAll(tx, sql: sql, arguments: [ftsQuery])
    }
}
```

## Ranking y combinación

Cuando hay múltiples matchers, calculamos scores y combinamos:

```swift
struct ScoredAsset {
    let id: Int64
    let scores: [SourceScore]
    var combinedScore: Double { ... }
}
```

Pesos default (ajustables):

| Fuente | Peso |
|---|---|
| Tag manual exacto | 1.0 |
| Person match confirmado | 0.95 |
| OCR exacto (comillas) | 0.9 |
| Tag automático alta confianza | 0.85 |
| CLIP similarity | 0.75 |
| OCR fuzzy | 0.7 |
| Classification | 0.6 |
| FeaturePrint similar | 0.5 |
| Recency boost | +0.05 si <7 días, +0.02 si <30 días |

## UX de la searchbar

### Comportamiento

- **Debounce 200ms** entre teclas para no spamear CLIP
- **Autocomplete** de tags y personas mientras escribís
- **Pills/chips** para queries estructurados convertidas
- **Texto libre** queda como prefijo antes de los chips
- **Historial** de búsquedas recientes accesible con flecha abajo en searchbar vacía

### Vista de resultados

- **Grid principal** se actualiza progresivamente (results streaming)
- **Faceted filters** en sidebar derecha cuando hay resultados
- **Total count** visible: "1,247 resultados"
- **Sort options**: relevance (default), date desc, date asc, name, size, dimensions

## Smart Collections

Búsquedas guardadas como entidad de primer nivel.

```json
{
  "operator": "and",
  "filters": [
    { "type": "tag", "namespace": "tema", "value": "programacion" },
    { "type": "tag", "namespace": "formato", "value": "meme" },
    { "type": "dateRange", "from": "2024-01-01" }
  ],
  "sort": "date_desc"
}
```

UI:
- En sidebar bajo sección "Smart"
- Click ejecuta la query
- Edición visual del query builder
- Útil para reglas de Organize Engine (mismo formato de matcher)

## Performance esperada

Sobre biblioteca de 50,000 assets en M4:

| Tipo de query | Latencia esperada |
|---|---|
| Tag exact | <10ms |
| Tag fuzzy LIKE | 20-50ms |
| Person match | <20ms |
| OCR FTS | 30-100ms |
| CLIP text → KNN | 200-400ms (incluye encoding) |
| FeaturePrint similar | 50-150ms |
| Combinado complejo | 300-600ms |

Cache de queries recientes en memoria para repetidas idénticas (TTL 5 min).
