# 07 · UI y experiencia visual

## Estructura de ventana

```
┌─────────────────────────────────────────────────────────┐
│  ⟨ ⟩  [Search bar pill style]              ⚙  ⊞ ⊟ ⊡    │ ← Toolbar translúcida
├──────────┬──────────────────────────────────────────────┤
│ SIDEBAR  │  CONTENT GRID                                │
│          │  ┌──┬──┬──┬──┬──┬──┐                         │
│ Library  │  │  │  │  │  │  │  │                         │
│ ▸ Memes  │  ├──┼──┼──┼──┼──┼──┤                         │
│ ▸ Refs   │  │  │  │  │  │  │  │  ← LazyVGrid            │
│          │  ├──┼──┼──┼──┼──┼──┤    virtualizado         │
│ Smart    │  │  │  │  │  │  │  │                         │
│ ★ Recent │  └──┴──┴──┴──┴──┴──┘                         │
│ ⏱ Today  │                                              │
│ 📍 Geo   │                                              │
│          │                                              │
│ Tags     │                                              │
│ ▸ tema   │                                              │
│ ▸ formato│                                              │
│ ▸ persona│                                              │
│          │                                              │
│ People   │                                              │
│ • Anya   │                                              │
│ • Elle   │                                              │
└──────────┴──────────────────────────────────────────────┘
```

## Vistas principales

### 1. Grid view (vista principal)
- Tarjetas con aspect ratio preservado o cuadradas (toggleable)
- Slider de tamaño en toolbar (50px → 400px)
- Hover preview animado (escala 1.04, sombra suave)
- Para videos: scrubbing en hover (loops del frame central)
- Selección múltiple (Shift+click, Cmd+click, marquee)
- Drag&drop a Finder y otras apps

### 2. Inspector lateral derecho (toggleable)
- Metadata: dimensiones, tamaño, mime, fecha
- Tags asignados con namespace coloreado
- Personas detectadas
- OCR text (expandible)
- "Imágenes similares" (top 5 con click para ver más)
- Path original con botón "Show in Finder"
- Botón "Open with..." menu

### 3. Lightbox / Detail view
- Pantalla completa o ventana grande
- Navegación con flechas teclado y on-screen
- Video player con controles nativos AVPlayer
- Zoom y pan en imágenes (pinch, scroll, doble click)
- Info panel deslizable desde la derecha
- Botón compartir nativo

### 4. People view
- Grid de personas con cara representativa
- Conteo de matches por persona
- Click → grid filtrado por esa persona
- Modo "review queue" para confirmar matches dudosos
- Crear persona, editar, fusionar duplicados

### 5. Tags view
- Lista jerárquica por namespace
- Drag to merge, rename, recolor
- Conteo de assets por tag
- Click → grid filtrado

### 6. Map view (futuro, opcional)
- Assets con geotag plotteados en MKMapView
- Clusters automáticos
- Click en cluster → grid filtrado por área

## Materiales y look

### Translúcidos
- **Sidebar**: `NSVisualEffectView` con material `.sidebar` (vibrancy adaptativa)
- **Toolbar**: material `.titlebar`
- **Inspector**: material `.hudWindow` cuando sobre contenido
- **Popovers y menus**: material `.menu`

### Contextual darkening
- Cuando hay un asset seleccionado en lightbox, sidebar se atenúa sutilmente (overlay negro 10% opacity con animación)

### Acento dinámico
- Toma `NSColor.controlAccentColor` del sistema
- Aplica a chips de tags, selecciones, hover states
- Genera variantes: 100%, 60%, 30%, 10% opacity

### Modo oscuro y claro
- Ambos completamente pulidos, no solo invertido
- Paleta neutra cool en oscuro
- Paleta cálida sutil en claro

## Tipografía

| Uso | Font |
|---|---|
| UI general | SF Pro (system) |
| Headings | SF Pro Display Semibold |
| Metadata técnica (path, hash, dimensiones) | SF Mono |
| Números grandes (counters) | SF Pro Rounded |

## Iconografía

- **SF Symbols 6+** con weights variables (`thin`, `regular`, `semibold` según contexto)
- **Custom SVG** solo cuando SF Symbol no existe o no encaja
- Animar SF Symbols con `.symbolEffect()` cuando aplique (bounce, pulse, replace)

## Animaciones

### Principios
- **Spring** como default (no curves lineales)
- **Duración corta** (150-300ms) en transiciones de UI
- **Easing personalizado** para grid: `interpolatingSpring(stiffness: 200, damping: 25)`
- **Matched geometry** entre grid item → lightbox

### Casos específicos

| Acción | Animación |
|---|---|
| Hover en thumbnail | scale 1.0 → 1.04, shadow opacity 0 → 0.15 |
| Click en thumbnail | matched geometry expand a lightbox |
| Cerrar lightbox | reverso del matched geometry |
| Selección | overlay azul con scale 0.95 → 1.0 spring |
| Drag start | escala 1.0 → 1.1, opacity 1.0 → 0.7 |
| Tag chip aparece | scale 0 → 1 spring desde su posición de origen |
| Sidebar item hover | background fade-in 100ms |
| Loading skeleton | shimmer linear, no spinner |

## Performance del grid

### Decisión técnica
**NSCollectionView** envuelto en `NSViewRepresentable` para bibliotecas grandes (>5k), en lugar de LazyVGrid puro.

Razones:
- LazyVGrid de SwiftUI se traba con miles de items
- NSCollectionView tiene flow layout maduro, prefetching, recycling
- Permite control fino de scroll snapping y batch updates

### Thumbnail caching

```
~/Library/Caches/Atelier/thumbs/
├── 200/
│   └── {sha256_first8}/
│       └── {asset_id}.jpg
├── 400/
└── 800/
```

- **Tres tamaños cacheados**: 200, 400, 800px
- **Generación bajo demanda** según zoom actual del grid
- **JPEG quality 85** para balance tamaño/calidad
- **HEIC** opcional para Mac (mejor compresión)
- **Cleanup**: borrar thumbs de assets eliminados, LRU si excede límite (default 5GB)

### Decode async

```swift
final class ThumbnailLoader {
    func loadThumbnail(for asset: Asset, size: CGFloat) async -> NSImage? {
        // 1. Check memory cache (NSCache)
        // 2. Check disk cache
        // 3. Generate async (no bloquea main)
        // 4. Cancela si el cell salió del viewport
    }
}
```

### Pixel-perfect
- Detecta `NSScreen.backingScaleFactor` por monitor
- Sirve thumbnails al tamaño exacto requerido (2x en retina, 3x si aparece, 1x en monitores externos)
- Sin upscaling borroso

## Drag & drop

### Inbound
- Drag desde Finder → import a library root activo
- Drag desde browser (imagen web) → descarga + import
- Drag desde otra app → si es archivo, import

### Outbound
- Drag asset → Finder: exporta el archivo real (no thumbnail)
- Drag asset → Slack, Discord, browser: archivo original
- Drag selection múltiple: zip temporal o múltiples archivos según destino

## Keyboard shortcuts

| Shortcut | Acción |
|---|---|
| `⌘F` | Focus searchbar |
| `⌘L` | Focus searchbar (alternativo) |
| `Space` | Quick Look del asset seleccionado |
| `Enter` | Abrir en lightbox |
| `Esc` | Cerrar lightbox / deseleccionar |
| `←` `→` | Navegar entre assets |
| `⌘I` | Toggle inspector |
| `⌘1` `⌘2` `⌘3` | Cambiar vista (grid / lista / map) |
| `⌘+` `⌘-` | Zoom grid |
| `⌘T` | Tag selected (popover de tags) |
| `⌘D` | Mostrar duplicados del seleccionado |
| `⌘⌫` | Mover a Trash (con confirmación) |
| `⌘⌥⌫` | Eliminar permanentemente (con confirmación fuerte) |
| `⌘⇧F` | Show in Finder |

## Empty states y onboarding

### Primera ejecución
1. Splash con logo (no más de 1s)
2. Welcome window:
   - "Agregar primera carpeta" botón principal
   - Explicación corta: "Atelier indexa sin mover tus archivos"
   - Skip a app vacía
3. Tour opcional de 3 pasos: indexación / búsqueda / tags

### Empty states
- **Sin library roots**: ilustración + CTA "Agregar carpeta"
- **Búsqueda sin resultados**: sugerencias contextuales
- **Indexando**: progreso con assets parcialmente disponibles
- **Disco desconectado**: mensaje claro + qué hacer

## Preferencias

Ventana de preferencias con tabs:

1. **General**: idioma, theme override, behavior al abrir
2. **Libraries**: lista de roots, agregar/quitar/editar
3. **Performance**: límite caché, paralelismo máximo, modelos a usar
4. **Search**: pesos de ranking, idiomas OCR
5. **Organize**: ajustes default de reglas, retención de rollback
6. **Advanced**: paths, logs, export/import DB
7. **About**: versión, créditos, links

## Accesibilidad

- **VoiceOver**: labels descriptivos en todos los controles
- **Dynamic Type**: respetar preferencias de tamaño de texto del sistema
- **Reduce Motion**: sin matched geometry, fades simples
- **Increase Contrast**: opacidades aumentadas, bordes visibles
- **Color**: nunca solo color para señalar estado (también ícono o texto)
