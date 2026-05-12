# 10 · Roadmap

Desarrollo por fases con hitos verificables. Cada fase deja la app en estado funcional y testeable.

## Fase 0 · Setup (3-5 días)

**Objetivo**: proyecto compilable con dependencias y esquema base.

- [ ] Proyecto Xcode con configuración multi-target (app + tests)
- [ ] Estructura de carpetas según `13-estructura-repo.md`
- [ ] Dependencias vía SPM: GRDB, MLX Swift
- [ ] sqlite-vec compilado como xcframework (o vía SPM si hay binding)
- [ ] CI básico: build verification en cada push (GitHub Actions o local)
- [ ] Migraciones SQLite versionadas
- [ ] Esquema completo creado por migrations
- [ ] Logging estructurado (os_log) por subsistema

**Hito**: app compila, abre ventana vacía, DB se crea correctamente al primer boot.

## Fase 1 · Esqueleto funcional (1-2 semanas)

**Objetivo**: indexar y mostrar archivos sin ML.

- [ ] Window principal con sidebar + grid placeholder
- [ ] Library roots: agregar carpeta, security-scoped bookmarks persistidos
- [ ] File watcher con FSEvents + debounce
- [ ] Scan inicial: comparar FS vs DB, encolar nuevos/modificados
- [ ] Hashing (SHA256) async con cola de prioridad
- [ ] Extracción metadata básica (dimensiones, duración, mime)
- [ ] Thumbnail generation con Quick Look para imágenes
- [ ] Thumbnail de video con AVAssetImageGenerator (frame del 50%)
- [ ] Caché de thumbnails en tres tamaños (200/400/800)
- [ ] Grid básico con NSCollectionView + thumbnails
- [ ] Detail view / lightbox con navegación teclado
- [ ] Manejo de mount/unmount de discos externos

**Hito**: la app indexa una carpeta de 10k archivos y los muestra en grid scrolleable a 60fps. Sin búsqueda inteligente todavía.

## Fase 2 · Apple Vision pipeline (1-2 semanas)

**Objetivo**: extracción de información local con Vision framework.

- [ ] IndexingService con cola async y paralelismo configurable
- [ ] VisionService: OCR multilingüe
- [ ] Persistencia de OCR en FTS5
- [ ] VisionService: image classification
- [ ] Persistencia de clasificaciones
- [ ] VisionService: face detection + face prints
- [ ] Persistencia de faces y face embeddings (sqlite-vec)
- [ ] VisionService: FeaturePrint para similitud
- [ ] Persistencia de feature prints (sqlite-vec)
- [ ] Búsqueda básica por texto OCR
- [ ] Búsqueda por classification label
- [ ] Búsqueda "similar to this" usando FeaturePrint

**Hito**: podés buscar "perro" y aparecen fotos con perros sin haberlas tagueado. Funciona OCR de memes en español e inglés.

## Fase 3 · Sistema de tags y personas (1 semana)

**Objetivo**: organización manual robusta.

- [ ] CRUD de tags con namespaces
- [ ] Sidebar muestra tags jerárquicos
- [ ] Tagging manual (multi-select en grid, popover de tags)
- [ ] Drag-to-tag desde sidebar
- [ ] Autocomplete de tags al tipear
- [ ] Tag suggestions basadas en classifications
- [ ] CRUD de personas
- [ ] Asignación de caras de referencia
- [ ] Face matching automático con threshold configurable
- [ ] Review queue para matches en zona gris
- [ ] Smart collections: queries guardadas en sidebar

**Hito**: podés crear "Anya Taylor-Joy", asignar 5 fotos de referencia, y la app la encuentra correctamente en el resto de la biblioteca.

## Fase 4 · CLIP integration (1 semana)

**Objetivo**: búsqueda semántica en lenguaje natural.

- [ ] MLX Swift setup + carga modelo CLIP ViT-B/32
- [ ] Encoder de imagen en el pipeline de indexación
- [ ] Persistencia de embeddings CLIP (sqlite-vec)
- [ ] Encoder de texto para queries
- [ ] Búsqueda híbrida: CLIP + filtros estructurados
- [ ] UI de searchbar con autocomplete y chips
- [ ] Parser de queries con operadores (`tag:`, `persona:`, `tipo:`)
- [ ] Ranking combinado de fuentes
- [ ] Debounce y cache de queries

**Hito**: "memes de programación con gato" devuelve resultados visuales relevantes incluso si los assets no tienen esos tags.

## Fase 5 · Pulido visual (1 semana)

**Objetivo**: la app se siente premium.

- [ ] Materiales translúcidos en sidebar/toolbar/inspector
- [ ] Animaciones spring en hover, selection, transitions
- [ ] Matched geometry: grid → lightbox
- [ ] Modo claro/oscuro completos y diferenciados
- [ ] Iconografía con SF Symbols 6+
- [ ] Empty states ilustrados
- [ ] Onboarding al primer uso
- [ ] Preferencias (General, Libraries, Performance, Search, Advanced)
- [ ] Keyboard shortcuts completos
- [ ] Accessibility: VoiceOver, Dynamic Type, Reduce Motion

**Hito**: la app se siente como una Apple app de primera categoría. Capturas de pantalla bonitas.

## Fase 6 · Estabilización · v1.0 (1 semana)

**Objetivo**: usable en producción para uso real.

- [ ] Tests unitarios para servicios críticos
- [ ] Tests de integración para pipeline de indexación
- [ ] Profiling con Instruments (CPU, memoria, disco, GPU)
- [ ] Manejo de archivos corruptos, formatos raros
- [ ] Recuperación de discos desconectados
- [ ] Backup/export de base de datos
- [ ] Crash reporting básico
- [ ] Documentación interna de arquitectura
- [ ] README de usuario

**Hito v1.0**: instalable como `.app` notarizado, usable en producción para tu biblioteca real de 50k+ assets.

## Fase 6.5 · Organize Engine v1 — Quick actions (1 semana)

**Objetivo**: operaciones ad-hoc con preview y rollback, sin reglas guardadas.

- [ ] Esquema DB de `organize_operations`, `organize_runs`, `asset_path_history`
- [ ] OrganizeService con plan + execute + rollback
- [ ] Path template engine con variables y funciones de transformación
- [ ] UI: click derecho → "Move/Rename...", modal con template
- [ ] Preview básico (lista de operaciones planeadas)
- [ ] Conflict resolution (skip/rename/replace/hash-suffix)
- [ ] Apply con barra de progreso y cancelación
- [ ] Rollback de runs recientes desde history view
- [ ] Atomicidad por archivo + recuperación de errores
- [ ] Cross-volume moves robustos (copy+verify+delete)

**Hito v1.1**: podés seleccionar 200 memes y moverlos con plantilla a una nueva estructura, con preview, apply y rollback completos.

## Fase 7 · Organize Engine v2 — Reglas guardadas (1-2 semanas)

**Objetivo**: reglas reutilizables y editables.

- [ ] CRUD de organize_rules
- [ ] Editor visual de reglas (matcher + action + policy)
- [ ] Condiciones complejas (AND/OR/NOT, grupos)
- [ ] Guardado, edición, duplicación, exportación de reglas
- [ ] Tab "History" con todos los runs y rollbacks
- [ ] Path templates avanzados con más funciones
- [ ] Conflict resolution avanzada (merge by hash, etc.)
- [ ] Priorización entre reglas (shadowing)

**Hito v1.2**: reglas reutilizables como Hazel pero conscientes de tags y personas.

## Fase 8 · Organize Engine v3 — Automatización (1 semana)

**Objetivo**: organización autónoma.

- [ ] Auto-run cuando assets matchean (con debounce)
- [ ] Triggers: on-import, on-tag, periódico
- [ ] Scheduling (cron-like, diario, semanal)
- [ ] Notificaciones del sistema: "47 archivos organizados por X"
- [ ] Reportes semanales/mensuales de actividad
- [ ] Modo "monitor": sugerir sin ejecutar

**Hito v1.3**: la app organiza automáticamente según se taggea.

## Fase 9 · VLM — Camino 3 (1-2 semanas)

**Objetivo**: descripciones ricas en lenguaje natural.

- [ ] Integración con Ollama local (opt-in, no requerido)
- [ ] Alternativa: modelo Qwen2-VL o LLaVA via MLX Swift
- [ ] Generación de descripción por asset (background job de baja prioridad)
- [ ] Indexación de descripciones en FTS5 (`description_fts`)
- [ ] Sugerencia automática de tags basada en descripción
- [ ] UI para revisar/aplicar tags sugeridos en batch
- [ ] Búsqueda triple híbrida: tags + CLIP + descripciones FTS
- [ ] Posibilidad de usar VLM como condición en reglas Organize

**Hito v2.0**: assets entran al sistema con descripciones ricas que enriquecen la búsqueda y permiten reglas más inteligentes.

## Fase 10+ · Futuro abierto

Ideas para evaluar cuando v2.0 esté maduro:

- **Importadores de redes**: yt-dlp embebido para descargar de TikTok/IG/Twitter directo desde la app
- **Sync entre máquinas**: protocolo P2P o vía iCloud Drive con resolución de conflictos
- **App iOS companion**: vista read-only de la biblioteca con backup desde móvil
- **Plugins / extensions**: scripting con AppleScript o JavaScript
- **Detección de duplicados perceptual**: pHash, dHash para imágenes; vpdq para videos
- **Finder integration**: Quick Look extension, tags de Finder sincronizados
- **Mapa interactivo**: vista geográfica con clusters
- **Editor de tags batch avanzado**: regex sobre nombres, find/replace en metadata

## Estimación total

| Fases | Duración | Resultado |
|---|---|---|
| 0-6 | 6-9 semanas | **v1.0** funcional |
| 6.5-8 | 3-4 semanas | **v1.x** con Organize Engine |
| 9 | 1-2 semanas | **v2.0** con VLM |

Total estimado para v2.0 completo: **10-15 semanas** de desarrollo activo con Claude Code.

## Sesiones sugeridas en Claude Code

Cada sesión deja la app testeable. Propuesta inicial:

1. **Sesión 1**: Setup proyecto + dependencias + esquema SQLite + primer test
2. **Sesión 2**: Ventana + sidebar + grid placeholder con datos hardcoded
3. **Sesión 3**: Library roots + bookmarks + scan + watch
4. **Sesión 4**: Thumbnails + integración con grid
5. **Sesión 5**: VisionService (OCR, classification)
6. **Sesión 6**: VisionService (faces, FeaturePrint) + sqlite-vec
7. **Sesión 7**: Tags + personas + UI básica
8. **Sesión 8**: CLIP integration (MLX Swift)
9. **Sesión 9**: Searchbar + parser + ranking
10. **Sesión 10**: Pulido visual + materiales translúcidos
11. **Sesión 11-12**: Estabilización + tests + profiling
12. **Sesión 13+**: Organize Engine y siguientes fases
