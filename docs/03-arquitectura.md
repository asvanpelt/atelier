# 03 · Arquitectura

## Vista general

```
┌─────────────────────────────────────────────────┐
│                    UI Layer                     │
│  SwiftUI Views + AppKit interop puntual         │
│  Sidebar | Grid | Detail | Search bar           │
└────────────────────┬────────────────────────────┘
                     │ @Observable ViewModels
┌────────────────────▼────────────────────────────┐
│                Domain Layer                     │
│  - LibraryService    - SearchService            │
│  - TagService        - PersonService            │
│  - IndexingService   - ImportService            │
│  - OrganizeService   - ThumbnailService         │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐ ┌───▼──────┐ ┌───▼──────────┐
│  Data Layer  │ │ ML Layer │ │ FileSystem   │
│  GRDB+SQLite │ │ Vision   │ │ Watchers     │
│  sqlite-vec  │ │ MLX/CLIP │ │ Bookmarks    │
│  FTS5        │ │ AVFound. │ │ Permissions  │
└──────────────┘ └──────────┘ └──────────────┘
```

## Patrones

### Repository pattern
Cada entidad del dominio tiene un repositorio que abstrae la persistencia.

```swift
protocol AssetRepository {
    func find(id: Int64) async throws -> Asset?
    func search(query: SearchQuery) async throws -> [Asset]
    func upsert(_ asset: Asset) async throws -> Asset
    func markDeleted(id: Int64) async throws
    func observe(query: SearchQuery) -> AsyncStream<[Asset]>
}
```

Los repositorios son la única capa que toca la DB directamente. Los servicios consumen repositorios, los ViewModels consumen servicios.

### Services como actors
Los servicios mantienen estado interno y son thread-safe por construcción.

```swift
actor IndexingService {
    private var queue: [URL] = []
    private var inProgress: Set<URL> = []

    func enqueue(_ url: URL) { ... }
    func processNext() async { ... }
}
```

### ViewModels @Observable
Cada vista relevante tiene un ViewModel con el macro `@Observable` de Swift 6.

```swift
@Observable
final class GridViewModel {
    private(set) var assets: [Asset] = []
    private(set) var isLoading = false

    func load() async { ... }
    func applyFilter(_ filter: Filter) async { ... }
}
```

### Sin frameworks pesados de estado
No usamos TCA, Redux, ni similares en el MVP. Si la complejidad crece se puede evaluar después, pero `@Observable` + actors cubre 95% de casos sin la ceremonia de un framework.

## Capas detalladas

### UI Layer

- **SwiftUI primario**: vistas principales, sidebar, detail, modales
- **AppKit puntual**:
  - `NSCollectionView` envuelto en `NSViewRepresentable` para el grid principal
  - `NSVisualEffectView` para materiales que SwiftUI no expone bien
  - `NSWindowDelegate` para gestión avanzada de ventanas
- **Componentes reutilizables** en `Views/Components/`

### Domain Layer (Servicios)

| Servicio | Responsabilidad |
|---|---|
| `LibraryService` | Gestión de library roots, mount/unmount, permisos |
| `IndexingService` | Cola de indexación, orquesta Vision + CLIP + persistencia |
| `ThumbnailService` | Generación, caché y servido de thumbnails |
| `SearchService` | Resolución de queries híbridas |
| `TagService` | CRUD de tags, sugerencias, namespaces |
| `PersonService` | CRUD de personas, face matching, queue de confirmación |
| `ImportService` | Importación manual y drag&drop |
| `OrganizeService` | Plan/execute/rollback de reorganizaciones físicas |

### Data Layer

- **`Database.swift`**: setup GRDB, carga de sqlite-vec, configuración de pragmas
- **`Migrations/`**: cada migración es un archivo numerado, idempotente
- **`Repositories/`**: uno por entidad principal
- **`Records/`**: structs que mapean a tablas (conforman a `Codable`, `FetchableRecord`, `PersistableRecord`)

### ML Layer

- **`VisionService`**: wrapper sobre Apple Vision con API uniforme
- **`CLIPService`**: gestión del modelo MLX, encoder de imagen y texto
- **`VideoFrameService`**: extracción de frames representativos para indexar video como imagen

### FileSystem Layer

- **`FileWatcher`**: wrapper sobre FSEvents, debounce, batching
- **`BookmarkManager`**: serialización/resolución de security-scoped bookmarks
- **`VolumeMonitor`**: detección de mount/unmount

## Flujo de datos

### Ejemplo: usuario abre la app

```
1. AppDelegate inicializa Database
2. Database aplica migrations pendientes
3. LibraryService carga library_roots desde DB
4. Para cada root: resuelve bookmark, verifica acceso
5. FileWatcher arranca para roots accesibles
6. IndexingService levanta cola desde estado persistido
7. SwiftUI levanta vista principal con GridViewModel
8. GridViewModel pide a SearchService los últimos assets
9. SearchService → AssetRepository → GRDB → SQLite
10. Grid renderiza con thumbnails cacheados
```

### Ejemplo: usuario busca "memes de gatos"

```
1. SearchBarView captura input
2. SearchViewModel debounce 200ms
3. SearchService.search(text: "memes de gatos")
   a. Parser detecta texto libre, no estructurado
   b. TagService busca matches exactos → ["meme", "gato"]
   c. CLIPService encoder de texto → vector 512d
   d. AssetRepository.searchByEmbedding(vector, limit: 200)
   e. Filtros adicionales aplicados
4. Resultado ordenado por similitud + recency
5. GridViewModel actualiza @Observable assets
6. SwiftUI re-renderiza
```

## Concurrencia y threading

- **Main actor**: toda la UI
- **Default actors**: servicios de dominio
- **Background queue dedicada**: indexación pesada (Vision, CLIP)
- **GRDB DatabaseQueue**: serialización de escrituras
- **GRDB DatabasePool**: lecturas concurrentes

Regla: nunca bloquear el main actor con operaciones síncronas pesadas. Toda DB query desde UI usa `async`.

## Manejo de errores

- **Errores recuperables**: se propagan, UI muestra notificación sutil, operación se reintenta
- **Errores irrecuperables**: log estructurado (os_log), UI muestra alerta, app sigue funcionando con feature degradada
- **Errores de filesystem**: específicamente manejados (archivo no encontrado, sin permisos, disco lleno)
- **Errores de ML**: indexación se marca como `failed`, se reintenta con backoff exponencial

## Observabilidad

- **os_log** estructurado por subsistema (`indexing`, `search`, `ml`, `organize`)
- **Métricas internas** en tabla `app_metrics` para diagnóstico:
  - Tiempo de indexación por asset
  - Errores por servicio
  - Tamaño de caché
- **Panel de diagnóstico** en Preferences → Advanced (futuro)
