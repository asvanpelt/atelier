# Atelier

Aplicación nativa macOS para gestionar bibliotecas grandes de imágenes y videos descargados (memes, contenido de redes, referencias visuales), con experiencia visual fluida y búsqueda inteligente local.

Respeta la estructura física del disco, procesa todo localmente (Vision framework, sin nube) y agrega tags, personas y detección de origen sobre carpetas existentes.

## Estado actual

La especificación completa (visión, stack, arquitectura, roadmap) vive en `docs/`. Resumen de avance contra `docs/10-roadmap.md`:

| Fase | Estado | Notas |
|---|---|---|
| 0 · Setup | ✅ | SPM + GRDB, esquema versionado con 5 migraciones, logging por subsistema |
| 1 · Esqueleto funcional | ✅ | Library roots con security-scoped bookmarks, FSEvents watcher, scan async, hashing SHA256, thumbnails (Quick Look + AVAsset), grid con `NSCollectionView` masonry, lightbox con navegación por teclado, monitor de volúmenes |
| 2 · Apple Vision | ✅ mayormente | OCR, image classification, detección + embeddings de rostros y FeaturePrint corriendo sobre el pipeline. Búsqueda por OCR/clasificación pendiente de UI dedicada |
| 3 · Tags y personas | 🟡 parcial | CRUD de tags y personas, sidebar con namespaces, matching de caras + clustering automático con sheet de revisión, asignación de personas. Falta drag-to-tag, autocomplete y smart collections |
| 4 · CLIP / MLX | ❌ | Aún no integrado |
| 5 · Pulido visual | 🟡 en marcha | `GlassTheme` con materiales translúcidos, perfiles, blur toggle, welcome onboarding, preferencias básicas |
| 6.5 · Organize Engine v1 | 🟡 esquema y ventana iniciados | Migración `M003_OrganizeEngine`, `OrganizeService` y ventana dedicada. Falta cerrar plan/preview/rollback |
| · Extras fuera del roadmap original | ✅ | Multi-perfil (`ProfileStore`) y detección de origen por nombre de archivo (TikTok/IG/Twitter/etc.) con sidebar agrupado por plataforma y cuenta |

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/01-vision.md`](docs/01-vision.md) | Visión del producto, principios rectores y casos de uso |
| [`docs/02-stack.md`](docs/02-stack.md) | Stack técnico, dependencias y decisiones tecnológicas |
| [`docs/03-arquitectura.md`](docs/03-arquitectura.md) | Arquitectura general, capas y patrones |
| [`docs/04-modelo-datos.md`](docs/04-modelo-datos.md) | Esquema SQLite (núcleo + organize engine) |
| [`docs/05-indexacion.md`](docs/05-indexacion.md) | Pipeline de indexación, ML y watching de filesystem |
| [`docs/06-busqueda.md`](docs/06-busqueda.md) | Sistema de búsqueda híbrida (tags + CLIP + OCR + faces) |
| [`docs/07-ui-ux.md`](docs/07-ui-ux.md) | UI, vistas, materiales translúcidos y performance |
| [`docs/08-tags-personas.md`](docs/08-tags-personas.md) | Modelo de tags con namespaces y sistema de personas |
| [`docs/09-organize-engine.md`](docs/09-organize-engine.md) | Sistema de reorganización física de archivos |
| [`docs/10-roadmap.md`](docs/10-roadmap.md) | Roadmap por fases con hitos |
| [`docs/11-riesgos.md`](docs/11-riesgos.md) | Riesgos identificados y mitigaciones |
| [`docs/12-decisiones-pendientes.md`](docs/12-decisiones-pendientes.md) | Decisiones diferidas para discusión |
| [`docs/13-estructura-repo.md`](docs/13-estructura-repo.md) | Estructura propuesta del repositorio |
| [`docs/14-deteccion-origen.md`](docs/14-deteccion-origen.md) | Heurísticas para identificar origen y cuenta desde el nombre de archivo |
| [`docs/15-clustering-caras.md`](docs/15-clustering-caras.md) | Clustering automático de rostros y review queue |

## Arquitectura del repo

```
Atelier/
  App/                 # Entry point (AtelierApp.swift) y composición de servicios
  Database/            # GRDB stack, migraciones (M001..M005), repositorios
  FileSystem/          # BookmarkManager, FileHasher, FileWatcher, VolumeMonitor
  Models/              # Asset, Tag, Person, FaceObservation, LibraryRoot, Profile, ...
  Services/            # IndexingService, VisionService, FaceClusteringService,
                       # LibraryService, OrganizeService, ThumbnailService,
                       # SourceDetector, ProfileStore
  Utilities/           # GlassTheme, Logger, Debouncer, Constants, extensiones
  ViewModels/          # GridViewModel
  Views/               # MainWindow + Grid/Detail/Sidebar/Toolbar, People manager,
                       # Lightbox, Inspector, Onboarding, Preferences, Organize
  Resources/           # logo*.png, modelos
Scripts/install-local.sh
docs/
Package.swift
```

## Stack en uso hoy

- **Swift 6 + SwiftUI** sobre macOS 14+, con interop AppKit (`NSCollectionView` para el grid, `NSOpenPanel`, `NSVisualEffectView`)
- **GRDB.swift** para SQLite, migraciones versionadas
- **Apple Vision** (`VNRecognizeText`, `VNClassifyImage`, `VNDetectFaceRectangles`, `VNGenerateFaceCaptureQualityRequest`, `VNGenerateImageFeaturePrintRequest`) para todo el pipeline de ML actual
- **AVFoundation + Quick Look** para thumbnails de imagen y video
- **FSEvents** vía `FileWatcher`, security-scoped bookmarks persistidos

Dependencias declaradas en `Package.swift`: sólo `GRDB.swift` por ahora. MLX Swift / sqlite-vec se sumarán al entrar a Fase 4.

## Build local

El proyecto se construye con Swift Package Manager (no hay `.xcodeproj`).

- **Desarrollo en Xcode**: abrir `Package.swift` directamente con Xcode (File → Open…) y darle Run.
- **Build desde terminal**:
  ```
  swift build -c release
  ```
- **Instalar como app del sistema** (Spotlight/Dock, firma ad-hoc):
  ```
  ./Scripts/install-local.sh
  ```
  Compila en release, empaqueta el ejecutable en `/Applications/Atelier.app`, lo firma ad-hoc y lo registra en Launch Services + Spotlight.

## Quick start para contribuir

1. Leer [`docs/01-vision.md`](docs/01-vision.md) para entender el producto.
2. Revisar [`docs/02-stack.md`](docs/02-stack.md), [`docs/03-arquitectura.md`](docs/03-arquitectura.md) y la fase activa en [`docs/10-roadmap.md`](docs/10-roadmap.md).
3. Resolver las dudas pendientes en [`docs/12-decisiones-pendientes.md`](docs/12-decisiones-pendientes.md) antes de abrir trabajo nuevo.
