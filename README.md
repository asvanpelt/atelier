# Atelier

Aplicación nativa macOS para gestionar bibliotecas grandes de imágenes y videos descargados (memes, contenido de redes, referencias visuales), con experiencia visual fluida y búsqueda inteligente local.

**Nombre tentativo:** Atelier (placeholder, ajustable).

## Documentación

La especificación está dividida en documentos navegables:

| Documento | Contenido |
|---|---|
| [`docs/01-vision.md`](docs/01-vision.md) | Visión del producto, principios rectores y casos de uso |
| [`docs/02-stack.md`](docs/02-stack.md) | Stack técnico, dependencias y decisiones tecnológicas |
| [`docs/03-arquitectura.md`](docs/03-arquitectura.md) | Arquitectura general, capas y patrones |
| [`docs/04-modelo-datos.md`](docs/04-modelo-datos.md) | Esquema SQLite completo (núcleo + organize engine) |
| [`docs/05-indexacion.md`](docs/05-indexacion.md) | Pipeline de indexación, ML y watching de filesystem |
| [`docs/06-busqueda.md`](docs/06-busqueda.md) | Sistema de búsqueda híbrida (tags + CLIP + OCR + faces) |
| [`docs/07-ui-ux.md`](docs/07-ui-ux.md) | UI, vistas, materiales translúcidos y performance |
| [`docs/08-tags-personas.md`](docs/08-tags-personas.md) | Modelo de tags con namespaces y sistema de personas |
| [`docs/09-organize-engine.md`](docs/09-organize-engine.md) | Sistema de reorganización física de archivos |
| [`docs/10-roadmap.md`](docs/10-roadmap.md) | Roadmap por fases con hitos |
| [`docs/11-riesgos.md`](docs/11-riesgos.md) | Riesgos identificados y mitigaciones |
| [`docs/12-decisiones-pendientes.md`](docs/12-decisiones-pendientes.md) | Decisiones diferidas para discusión |
| [`docs/13-estructura-repo.md`](docs/13-estructura-repo.md) | Estructura propuesta del repositorio |

## Quick start

1. Leer [`docs/01-vision.md`](docs/01-vision.md) para entender el producto
2. Revisar [`docs/02-stack.md`](docs/02-stack.md) y [`docs/10-roadmap.md`](docs/10-roadmap.md)
3. Resolver [`docs/12-decisiones-pendientes.md`](docs/12-decisiones-pendientes.md) antes de empezar a codear

## Build local

El proyecto se construye con Swift Package Manager (sin `.xcodeproj`).

- **Desarrollo en Xcode**: abre `Package.swift` directamente con Xcode (File → Open…) y dale Run.
- **Build desde terminal**:
  ```
  swift build -c release
  ```
- **Instalar como app del sistema** (Spotlight/Dock, firma ad-hoc):
  ```
  ./Scripts/install-local.sh
  ```
  El script compila en release, empaqueta el ejecutable en `/Applications/Atelier.app`, lo firma ad-hoc y lo registra en Launch Services.
