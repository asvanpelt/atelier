# 05 · Pipeline de indexación

## Estados de un asset

```
DISCOVERED → HASHED → THUMBNAILED → ANALYZED → INDEXED
                                         │
                                         └─→ INDEXING_FAILED (retry con backoff)
```

| Estado | Condición |
|---|---|
| DISCOVERED | Archivo encontrado en filesystem, fila creada en `assets` |
| HASHED | Hash SHA256 calculado |
| THUMBNAILED | Thumbnails generados en tres tamaños |
| ANALYZED | Vision + CLIP completos |
| INDEXED | `indexed_at` poblado, listo para búsqueda |

## Flujo detallado

```swift
func processAsset(at url: URL) async throws {
    // 1. Hash y metadata básica (rápido, ~50ms)
    let hash = try await sha256(url)
    let metadata = try await extractMetadata(url)
    let assetId = try await db.upsertAsset(url: url, hash: hash, metadata: metadata)

    // 2. Thumbnail (rápido, ~100ms con QuickLook)
    try await generateThumbnails(for: assetId, sourceURL: url)

    // 3. Pipeline ML en paralelo
    async let ocr = visionService.runOCR(url)
    async let classification = visionService.runClassification(url)
    async let faces = visionService.runFaceDetection(url)
    async let featurePrint = visionService.runFeaturePrint(url)
    async let clipEmbedding = clipService.encode(url)

    let results = try await (ocr, classification, faces, featurePrint, clipEmbedding)

    // 4. Persistir todo en transacción
    try await db.writeTransaction { tx in
        try tx.saveOCR(assetId, results.0)
        try tx.saveClassifications(assetId, results.1)
        try tx.saveFaces(assetId, results.2)
        try tx.saveVisionEmbedding(assetId, results.3)
        try tx.saveCLIPEmbedding(assetId, results.4)
        try tx.markIndexed(assetId)
    }

    // 5. Matchear caras nuevas contra personas conocidas
    try await personService.matchFacesToPersons(assetId)
}
```

## Manejo de video

Los videos se tratan como **secuencia de imágenes representativas** más metadata propia.

### Frames extraídos por video

1. Frame del 10% de la duración
2. Frame del 50% (frame central, generalmente el más informativo)
3. Frame del 90%

Cada frame se procesa con el pipeline completo (Vision + CLIP) y los resultados se **fusionan**:

- **OCR**: concatenación de todos los frames (deduplicado por similaridad de texto)
- **Classifications**: unión, conservando la mayor confianza por label
- **Faces**: todas las observaciones, con timestamp del frame de origen
- **FeaturePrint y CLIP**: promedio de los embeddings (centroide)

### Thumbnail de video

- **Static**: el frame del 50% como thumbnail principal
- **Animated** (hover preview): GIF/MP4 chico de 2-3 segundos centrado en el momento más interesante (saliency-based)

## Estrategia de paralelización

| Operación | Concurrencia |
|---|---|
| Discovery (escaneo FS) | Serial (1 a la vez) |
| Hashing | Hasta `processorCount` paralelos |
| Vision tasks | Hasta `processorCount` (usan Neural Engine) |
| CLIP encoding | 2-3 paralelos máximo (más caro en RAM) |
| Thumbnail generation | Hasta `processorCount / 2` |
| DB writes | Serial (DatabaseQueue de GRDB) |

### Pseudocódigo del coordinator

```swift
actor IndexingCoordinator {
    private var pending: [URL] = []
    private var inFlight: Set<URL> = []
    private let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount

    func tick() async {
        while inFlight.count < maxConcurrent, let url = pending.popFirst() {
            inFlight.insert(url)
            Task.detached(priority: .background) {
                do {
                    try await self.processAsset(at: url)
                } catch {
                    await self.recordFailure(url, error: error)
                }
                await self.finish(url)
            }
        }
    }

    private func finish(_ url: URL) {
        inFlight.remove(url)
        Task { await tick() }
    }
}
```

## Indexación incremental

### Trigger 1: scan al abrir la app

```swift
func quickScan(root: URL) async throws {
    let fsItems = try await listFiles(root)
    let dbItems = try await db.assetsUnderRoot(root.path)

    let dbByPath = Dictionary(uniqueKeysWithValues: dbItems.map { ($0.path, $0) })

    for fsItem in fsItems {
        if let existing = dbByPath[fsItem.path] {
            if existing.modifiedAt != fsItem.modifiedAt || existing.fileSize != fsItem.size {
                await enqueueReindex(existing.id, url: fsItem.url)
            }
        } else {
            await enqueueIndex(url: fsItem.url)
        }
    }
}
```

### Trigger 2: FSEvents en vivo

```swift
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let debouncer = Debouncer(delay: 0.5)

    func watch(root: URL) {
        // Usa FSEventStreamCreate vía CoreFoundation o DispatchSource
        // Eventos: created, modified, renamed, removed
        // Batchea con debounce de 500ms
    }
}
```

### Trigger 3: scan periódico de safety

FSEvents puede perder eventos en condiciones extremas. Por eso:

- Scan completo de cada library_root cada 6 horas en background
- Compara mtime + size, no hashes (rápido)
- Solo encola lo que cambió

## Manejo de archivos movidos

Cuando vemos un archivo "nuevo" en una ruta, antes de encolar:

```swift
let candidateHash = try await sha256(url)
if let existing = try await db.findAssetByHash(candidateHash) {
    if !FileManager.default.fileExists(atPath: existing.path) {
        // Es el mismo archivo que se movió
        try await db.updatePath(existing.id, newPath: url.path, source: "fs-detection")
        return
    }
}
// Realmente nuevo, encolar
```

## Reindex selectivo

Cuando se cambia un modelo (ej. CLIP ViT-B/32 → ViT-L/14):

1. Bump `indexing_version` globalmente
2. App detecta mismatch al abrir
3. Encola en background los assets con versión vieja
4. Procesa solo el pipeline que cambió (no rehace OCR si solo cambió CLIP)
5. UI muestra progreso sin bloquear

## Disco externo

### Detección

```swift
NotificationCenter.default.publisher(for: NSWorkspace.didMountNotification)
    .sink { notification in
        guard let path = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        Task { await self.handleVolumeMount(at: path) }
    }
```

### Reglas

- Library roots en disco no montado: ocultos de listings, marcados como `unavailable` en sidebar
- Bookmark data permite reconectar sin pedir permisos de nuevo
- Indexación pausa si root está offline, retoma al reconectar
- UI muestra estado claro: "Disco 'Memes-External' desconectado · 4,231 assets ocultos"

## Performance esperada en M4 16GB

| Fase | Tiempo por imagen | Tiempo por video (30s) |
|---|---|---|
| Hashing | 10-30ms | 50-200ms |
| Metadata | 5-10ms | 20-50ms |
| Thumbnails | 50-150ms | 200-500ms |
| Vision (full) | 50-100ms | 150-300ms |
| CLIP | 200-400ms | 600-1200ms |
| DB write | 5-15ms | 10-30ms |
| **Total** | **~500ms** | **~2s** |

Con 4-8 procesos paralelos: **biblioteca de 10k imágenes en ~15-20 minutos**.

## Failure modes

| Error | Estrategia |
|---|---|
| Archivo corrupto / formato desconocido | Marcar `indexing_failed`, registrar error, no reintentar automáticamente |
| OOM en CLIP | Reducir batch size, retry con prioridad baja |
| Disco lleno (caché thumbnails) | Pausar indexación, alertar usuario |
| Permisos perdidos | Marcar root como `requires_permission`, alertar |
| DB locked | Retry con backoff exponencial (raro con WAL) |
| Modelo no carga | Degradar feature: indexar sin CLIP si MLX falla, etc. |
