# 01 · Visión del producto

## Concepto

Aplicación nativa macOS para gestionar bibliotecas grandes de imágenes y videos descargados (memes, contenido de redes, referencias visuales), con experiencia visual fluida y búsqueda inteligente local.

Inspirada en lo mejor de tres mundos:

- **Synology Photos / Picasa**: respeto a la estructura física de carpetas, timeline cronológico, UI pulida
- **Immich**: búsqueda semántica con CLIP local, OCR, face recognition, todo sin nube
- **Hydrus Network**: sistema profundo de tags con namespaces, deduplicación perceptual, filosofía hash-first

## Principios rectores

1. **Respeta la estructura física**: la app por default no mueve ni renombra archivos, solo los indexa donde estén. Existe un sistema opt-in (Organize Engine) para reorganizar con preview y rollback.
2. **Todo local, todo privado**: ningún archivo, embedding, descripción o cara sale del equipo.
3. **Disco como fuente de verdad**: si borrás archivos por Finder, la app se sincroniza. No mantenemos copias paralelas.
4. **Tags sobre carpetas**: las carpetas siguen siendo válidas como organización primaria. Los tags agregan ortogonalidad para buscar y filtrar.
5. **Velocidad antes que features**: una biblioteca de 100k archivos tiene que scrollear a 60fps.
6. **Belleza nativa**: aprovecha SwiftUI, materiales translúcidos, animaciones spring. No parece app multiplataforma genérica.
7. **Reversibilidad**: cualquier operación destructiva (mover, renombrar) es previsualizable y reversible.

## Casos de uso primarios

### Caso 1: Biblioteca de memes y contenido descargado
Usuario compila memes, reels y videos cortos descargados de TikTok, Instagram, Twitter, WhatsApp. Necesita:
- Indexarlos sin moverlos de su carpeta de descargas
- Búsqueda visual ("memes de programación con gato negro")
- Búsqueda por texto OCR ("este meme dice 'this is fine'")
- Detección de duplicados (el mismo meme bajado de 4 plataformas)
- Tags por plataforma, tema, mood, idioma

### Caso 2: Referencias visuales para trabajo creativo
Diseñador/desarrollador junta capturas de UIs, paletas, ilustraciones. Necesita:
- Buscar por similitud visual ("muestrame imágenes parecidas a esta")
- Tags por proyecto, estilo, color dominante
- Acceso rápido sin tener que recordar dónde guardó cada captura

### Caso 3: Compilados de personas / personajes
Usuario archiva contenido de actrices, músicos, personajes que le interesan. Necesita:
- Identificación facial entrenada con sus propias referencias
- Agrupación automática por persona
- Búsqueda combinada ("Anya Taylor-Joy en escenas de época")

### Caso 4 (futuro): Organización automática
Cuando la biblioteca crece, el usuario quiere que:
- Archivos taggeados con `plataforma:tiktok` y `tema:cocina` se muevan automáticamente a `/Memes/Cocina/TikTok/`
- Nuevos imports se clasifiquen y organicen según reglas declarativas
- Todo con preview, log de operaciones y rollback durante 30 días

## Casos de uso NO cubiertos

Para mantener foco, estos quedan explícitamente fuera del scope:

- **Edición de imágenes**: no es Photoshop ni Lightroom, no edita pixels
- **Cloud sync nativo**: no hay sincronización entre máquinas en v1 (se puede hacer manualmente con el SQLite)
- **Multi-usuario**: aplicación single-user, sin cuentas ni permisos compartidos
- **Compartir online**: no publica, no genera links públicos
- **Fotografía RAW pro**: no compite con Lightroom para flujos RAW/DAM profesionales (aunque maneja RAW si aparecen)
- **Backup**: no es responsabilidad de Atelier hacer backup de los archivos originales
