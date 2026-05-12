# 13 · Estructura del repositorio

Layout propuesto del proyecto Xcode. Es una guía: Claude Code puede ajustarlo al generar.

## Árbol de carpetas

```
atelier/
├── README.md
├── .gitignore
├── docs/                       ← especificación (estos .md)
│   ├── 01-vision.md
│   ├── 02-stack.md
│   └── ...
├── Atelier.xcodeproj
├── Atelier/                    ← target principal de la app
│   ├── App/
│   │   ├── AtelierApp.swift           (@main, escena raíz)
│   │   ├── AppDelegate.swift          (lifecycle, init de servicios)
│   │   └── Environment.swift          (DI container, configuración)
│   │
│   ├── Models/                        ← structs de dominio
│   │   ├── Asset.swift
│   │   ├── Tag.swift
│   │   ├── Person.swift
│   │   ├── FaceObservation.swift
│   │   ├── LibraryRoot.swift
│   │   ├── Collection.swift
│   │   ├── OrganizeRule.swift
│   │   ├── OrganizeRun.swift
│   │   └── SearchQuery.swift
│   │
│   ├── Database/
│   │   ├── Database.swift             (GRDB setup, pragmas, sqlite-vec load)
│   │   ├── Migrations/
│   │   │   ├── M001_InitialSchema.swift
│   │   │   ├── M002_VectorTables.swift
│   │   │   ├── M003_OrganizeEngine.swift
│   │   │   └── ...
│   │   ├── Repositories/
│   │   │   ├── AssetRepository.swift
│   │   │   ├── TagRepository.swift
│   │   │   ├── PersonRepository.swift
│   │   │   └── OrganizeRepository.swift
│   │   └── Records/                   (structs con FetchableRecord)
│   │       ├── AssetRecord.swift
│   │       └── ...
│   │
│   ├── Services/
│   │   ├── LibraryService.swift
│   │   ├── IndexingService.swift
│   │   ├── ThumbnailService.swift
│   │   ├── SearchService.swift
│   │   ├── TagService.swift
│   │   ├── PersonService.swift
│   │   ├── ImportService.swift
│   │   └── OrganizeService.swift
```

```
│   │
│   ├── ML/
│   │   ├── VisionService.swift        (Apple Vision wrapper)
│   │   ├── CLIPService.swift          (MLX wrapper)
│   │   ├── VideoFrameService.swift    (extracción de frames)
│   │   └── ModelLoader.swift          (carga lazy, cache de modelos)
│   │
│   ├── FileSystem/
│   │   ├── FileWatcher.swift          (FSEvents wrapper)
│   │   ├── BookmarkManager.swift      (security-scoped bookmarks)
│   │   ├── VolumeMonitor.swift        (mount/unmount)
│   │   └── FileHasher.swift           (SHA256 async)
│   │
│   ├── Organize/
│   │   ├── PathTemplate.swift         (parser y renderer de templates)
│   │   ├── RuleMatcher.swift          (resolución de match conditions)
│   │   ├── PlanBuilder.swift          (genera OrganizePlan)
│   │   ├── PlanExecutor.swift         (aplica plan con atomicidad)
│   │   └── RollbackEngine.swift       (reversión de runs)
│   │
│   ├── Views/
│   │   ├── Main/
│   │   │   ├── MainWindow.swift
│   │   │   ├── Sidebar/
│   │   │   │   ├── SidebarView.swift
│   │   │   │   ├── LibrarySection.swift
│   │   │   │   ├── TagsSection.swift
│   │   │   │   ├── PeopleSection.swift
│   │   │   │   └── SmartCollectionsSection.swift
│   │   │   ├── Grid/
│   │   │   │   ├── AssetGridView.swift         (NSViewRepresentable)
│   │   │   │   ├── AssetGridController.swift   (NSCollectionView wrapper)
│   │   │   │   ├── AssetCell.swift
│   │   │   │   └── GridLayoutProvider.swift
│   │   │   ├── Detail/
│   │   │   │   ├── LightboxView.swift
│   │   │   │   ├── InspectorView.swift
│   │   │   │   └── MetadataPanel.swift
│   │   │   └── Toolbar/
│   │   │       ├── MainToolbar.swift
│   │   │       └── ViewModeSwitcher.swift
```

```
│   │   ├── Search/
│   │   │   ├── SearchBar.swift
│   │   │   ├── QueryParser.swift
│   │   │   ├── ChipsView.swift
│   │   │   └── SuggestionsPopover.swift
│   │   ├── Tags/
│   │   │   ├── TagPickerPopover.swift
│   │   │   ├── TagEditorView.swift
│   │   │   └── TagChip.swift
│   │   ├── People/
│   │   │   ├── PeopleView.swift
│   │   │   ├── PersonDetailView.swift
│   │   │   ├── ReviewQueueView.swift
│   │   │   └── PersonCreationFlow.swift
│   │   ├── Organize/
│   │   │   ├── RulesListView.swift
│   │   │   ├── RuleEditorView.swift
│   │   │   ├── PlanPreviewView.swift
│   │   │   ├── HistoryView.swift
│   │   │   └── QuickOrganizeModal.swift
│   │   ├── Preferences/
│   │   │   ├── PreferencesWindow.swift
│   │   │   ├── GeneralPane.swift
│   │   │   ├── LibrariesPane.swift
│   │   │   ├── PerformancePane.swift
│   │   │   └── AdvancedPane.swift
│   │   ├── Onboarding/
│   │   │   ├── WelcomeView.swift
│   │   │   └── TourView.swift
│   │   └── Components/                ← reutilizables
│   │       ├── BlurredBackground.swift
│   │       ├── EmptyStateView.swift
│   │       ├── LoadingShimmer.swift
│   │       └── ConfirmationDialog.swift
│   │
│   ├── ViewModels/
│   │   ├── GridViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   ├── InspectorViewModel.swift
│   │   ├── TagsViewModel.swift
│   │   ├── PeopleViewModel.swift
│   │   ├── OrganizeViewModel.swift
│   │   └── PreferencesViewModel.swift
```

```
│   │
│   ├── Utilities/
│   │   ├── Debouncer.swift
│   │   ├── AsyncQueue.swift
│   │   ├── Logger.swift               (wrapper sobre os_log)
│   │   ├── Extensions/
│   │   │   ├── URL+Atelier.swift
│   │   │   ├── Date+Formatting.swift
│   │   │   ├── Color+Namespace.swift
│   │   │   └── NSImage+Async.swift
│   │   └── Constants.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.xcstrings       (i18n)
│       ├── Models/                     (CoreML/MLX checkpoints, .gitignored)
│       │   ├── clip-vit-b32.mlpackage
│       │   └── README.md (instrucciones de descarga)
│       └── Atelier.entitlements
│
├── AtelierTests/
│   ├── DatabaseTests/
│   │   ├── MigrationsTests.swift
│   │   └── RepositoryTests.swift
│   ├── ServicesTests/
│   │   ├── IndexingServiceTests.swift
│   │   ├── SearchServiceTests.swift
│   │   └── OrganizeServiceTests.swift
│   ├── MLTests/
│   │   ├── VisionServiceTests.swift
│   │   └── CLIPServiceTests.swift
│   ├── OrganizeTests/
│   │   ├── PathTemplateTests.swift
│   │   └── PlanExecutorTests.swift
│   └── Fixtures/
│       ├── sample-images/
│       ├── sample-videos/
│       └── golden-data/
│
├── AtelierUITests/
│   └── BasicFlowTests.swift
│
└── Scripts/
    ├── download-models.sh              (descarga CLIP, etc.)
    ├── build-sqlite-vec.sh             (compila la extensión)
    └── notarize.sh                     (cuando aplique)
```

## Principios de organización

### Separación por capa, no por feature

A diferencia de un layout estilo "feature folders", organizamos por capa arquitectónica (Views, Services, ML, Database). Razones:

- Más fácil ver el alcance completo de cada capa
- Refactors transversales (cambiar de GRDB a otra cosa) son localizados
- Las capas tienen reglas de import claras: UI puede importar Services pero no al revés

### Subagrupación por dominio dentro de cada capa

Dentro de `Views/`, subcarpetas por feature (`Tags/`, `People/`, `Organize/`).
Dentro de `Services/`, archivos planos (no hay tantos como para subagrupar).
Dentro de `Database/Migrations/`, una por archivo numerada.

### Tests espejados

`AtelierTests/` espeja la estructura del target principal donde corresponde. Cada servicio tiene su archivo de tests.

### Fixtures versionadas

`AtelierTests/Fixtures/` contiene:
- 20-30 imágenes y 5-10 videos pequeños representativos
- Una DB con datos golden para tests de búsqueda
- Estos archivos van al repo (con git-lfs si pasan de tamaño)

## .gitignore

```
# Xcode
build/
DerivedData/
*.xcuserstate
*.xcuserdatad/
xcuserdata/

# Swift Package Manager
.swiftpm/
Package.resolved

# macOS
.DS_Store

# Modelos descargados (grandes, se bajan vía script)
Atelier/Resources/Models/*.mlpackage
Atelier/Resources/Models/*.bin
Atelier/Resources/Models/*.safetensors
!Atelier/Resources/Models/README.md

# Logs locales
*.log

# Secrets (si aparecen)
.env
*.p12
*.cer
```

## Convenciones de naming

| Tipo | Convención | Ejemplo |
|---|---|---|
| Tipo de Swift (struct, class, enum, protocol) | PascalCase | `AssetRepository`, `SearchQuery` |
| Variables y funciones | camelCase | `processAsset`, `lastScanAt` |
| Constantes globales | camelCase | `defaultThumbnailSize` |
| Tipos de Database (Record) | sufijo `Record` | `AssetRecord` |
| Tipos de protocol | sin sufijo "able" | `AssetRepository` no `AssetRepositoryable` |
| Tipos de servicio | sufijo `Service` | `IndexingService` |
| Vistas SwiftUI | sufijo `View` | `SidebarView` |
| ViewModels | sufijo `ViewModel` | `GridViewModel` |
| Errores | sufijo `Error` | `IndexingError`, `OrganizeError` |
| Archivos | matchean tipo principal | `AssetRepository.swift` |
| Migraciones | prefijo `M{NNN}_` | `M001_InitialSchema.swift` |
| Tests | mismo nombre + `Tests` | `AssetRepositoryTests.swift` |

## Reglas de imports entre capas

```
UI Layer (Views, ViewModels)
    ↓ puede importar
Domain Layer (Services)
    ↓ puede importar
Data Layer + ML Layer + FileSystem Layer
    ↓ puede importar
Models + Utilities
```

Una capa NO importa la de arriba. ViewModels NO importan SwiftUI (los Views sí).

## Targets

| Target | Propósito |
|---|---|
| `Atelier` | App principal (binario macOS) |
| `AtelierTests` | Tests unitarios y de integración |
| `AtelierUITests` | Tests de UI con XCUITest |
| `AtelierKit` (futuro) | Si se separa lógica en framework reutilizable |

Por ahora un solo target principal; si crece o queremos compartir con app iOS companion (Fase 10+), se separa en framework.
