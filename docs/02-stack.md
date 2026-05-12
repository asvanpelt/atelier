# 02 · Stack técnico

## Lenguaje y framework

- **Swift 6** + **SwiftUI** (base de UI)
- **AppKit** interop cuando SwiftUI se queda corto:
  - `NSCollectionView` para grid masivo (>5k items)
  - `NSVisualEffectView` para materiales translúcidos avanzados
  - `NSOpenPanel` para security-scoped bookmarks
- **Swift Concurrency** (async/await, actors) para todo el pipeline de indexación y servicios

## Persistencia

- **SQLite** vía **GRDB.swift**
  - Razón sobre SQLite.swift: mejor performance, soporte completo a transacciones, observación reactiva, type-safe records
  - Razón sobre Core Data: queries más expresivas, control total del esquema, mejor para joins complejos
- **sqlite-vec** como extensión cargada en runtime para búsqueda vectorial (KNN sobre embeddings)
  - Alternativa de respaldo si falla: faiss vía bridging C++, o LanceDB nativo
- **FTS5** (full-text search nativo de SQLite) para búsqueda de OCR y tags
  - Tokenizer `unicode61 remove_diacritics 2` para soporte español

## Machine Learning

### Apple Vision framework (nativo, gratuito, optimizado Apple Silicon)

- **Face detection**: `VNDetectFaceRectanglesRequest`, `VNDetectFaceLandmarksRequest`
- **Face embeddings**: `VNGenerateFeaturePrintRequest` aplicado a regiones de cara
- **OCR multilingüe**: `VNRecognizeTextRequest` con `recognitionLevel: .accurate`
- **Image classification**: `VNClassifyImageRequest` (miles de categorías)
- **Object detection**: `VNDetectAnimalRectanglesRequest`, `VNDetectHumanRectanglesRequest`
- **Saliency**: `VNGenerateAttentionBasedSaliencyImageRequest`
- **Feature print** (similarity): `VNGenerateImageFeaturePrintRequest`

Performance estimado en M4: 30-100ms por imagen para el pipeline completo de Vision, usando Neural Engine.

### MLX Swift (CLIP local para búsqueda semántica)

- **Modelo inicial**: `clip-vit-base-patch32`
  - Tamaño: ~150MB
  - Embedding: 512 dimensiones
  - Velocidad: ~200-400ms por imagen en M4
- **Upgrade futuro**: `clip-vit-large-patch14` (~900MB, mejor calidad, más lento)
- **Multilingual opcional**: `xlm-roberta-clip` si las queries en español dan resultados pobres

Plan B si MLX Swift no soporta el modelo: conversión a CoreML (existen scripts oficiales de Apple), o llama.cpp con bindings Swift.

## Video

- **AVFoundation** para extracción de frames clave (inicio, medio, fin)
- **VideoToolbox** para thumbnails acelerados por hardware
- **AVAssetImageGenerator** para preview frames

## Filesystem

- **FileManager** + **FSEvents** (`DispatchSource.FileSystemObject`) para watching
- **Security-scoped bookmarks** para acceso persistente a discos externos
- **NSWorkspace** notifications para mount/unmount

## Herramientas de desarrollo

- **Xcode 16+** (Swift 6 estable)
- **swift-format** para estilo consistente
- **swift-package-manager** para dependencias (GRDB, MLX, etc.)
- **Sparkle** para auto-updates (cuando sea relevante distribuir)
- **Instruments** para profiling (Time Profiler, Allocations, Core Animation)

## Dependencias principales

```swift
// Package.swift dependencies (preview)
.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
.package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
.package(url: "https://github.com/ml-explore/mlx-swift-examples.git", from: "1.16.0"),
// sqlite-vec: compilado como xcframework custom o vía SPM si hay binding
```

## Decisiones explícitas: lo que NO usamos

| Tecnología | Por qué no |
|---|---|
| Electron / Tauri / web tech | Sacrificamos performance, look nativo y acceso al Neural Engine |
| Core Data | SQLite directo con GRDB es más flexible para nuestras queries complejas |
| Servidor / Docker | Todo in-process, sin orquestación |
| Python runtime embebido | Swift + MLX cubren todo el ML necesario |
| React Native | No aporta nada en macOS-only, sería una capa extra inútil |
| Realm | GRDB es más maduro en Swift moderno, sin lock-in |
| Cloud (Firebase, Supabase) | Va contra principio "todo local" |

## Requisitos mínimos de sistema

- **macOS 14 Sonoma** o superior (por Swift 6 estable y Vision framework moderno)
- **Apple Silicon** (M1+) recomendado fuerte por MLX y Neural Engine; Intel funcionaría pero CLIP sería 10x más lento
- **RAM**: 8GB mínimo, 16GB recomendado para bibliotecas grandes
- **Disco**: 1GB para app + modelos, más espacio para caché de thumbnails (~5% del tamaño de la biblioteca)
