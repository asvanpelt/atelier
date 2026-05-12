# 12 · Decisiones pendientes

Lista de decisiones que conviene aterrizar antes de empezar (o en las primeras semanas). No bloquean el inicio del proyecto, pero conviene tener postura al llegar a las fases relevantes.

## Producto

### 1. Nombre del producto
- **Estado actual**: "Atelier" como placeholder
- **A definir**: nombre final, bundle identifier (`com.tuusuario.atelier`), dominio si aplica
- **Cuándo**: antes de Fase 0 (afecta naming en código)

### 2. Idioma de la UI
- **Opciones**: español (es-AR), inglés (en), ambos con switch
- **Cuándo**: antes de Fase 5 (pulido)
- **Recomendación**: empezar en español por ser para uso propio, agregar inglés después si se distribuye

### 3. Distribución
- **Opciones**:
  - Solo personal (no notarizar, build local)
  - DMG público notarizado en sitio propio
  - Mac App Store
  - Open source en GitHub
- **Cuándo**: antes de Fase 6 (estabilización)
- **Implicancias**: MAS tiene restricciones de sandbox que pueden afectar Organize Engine

## Arquitectura

### 4. Esquema físico de organización
- **Pregunta**: ¿una carpeta library raíz o múltiples desde el principio?
- **Default propuesto**: múltiples, una por contexto (ej: `Memes`, `Referencias`, `Personal`)
- **Cuándo**: Fase 1

### 5. Disco principal vs externo
- **Pregunta**: ¿la biblioteca principal vive en disco interno o externo?
- **Recomendación**: la DB en interno (`~/Library/Application Support/Atelier/`), los assets donde quieras (interno o externo, vía library_roots)
- **Cuándo**: al definir libraries en Fase 1

### 6. Formato de disco externo
- **Pregunta**: ¿exFAT (compatible cross-OS) o APFS (más rápido, solo Mac)?
- **Recomendación**: APFS si solo usás Mac; exFAT si querés leer desde Windows también
- **Cuándo**: antes de empezar a usar disco externo en producción

### 7. Sincronización entre máquinas
- **Pregunta**: ¿la app necesita funcionar en Mac casa + Mac laptop?
- **Opciones para v2**:
  - iCloud Drive de la DB (riesgo de conflicts)
  - Sync manual (export/import)
  - Servidor propio con API
  - P2P entre instancias de la app
- **Cuándo**: post v1.0

## ML y modelos

### 8. Modelo CLIP definitivo
- **Opciones**:
  - `clip-vit-base-patch32`: rápido, ~150MB, embedding 512d
  - `clip-vit-large-patch14`: mejor calidad, ~900MB, más lento, embedding 768d
  - `xlm-roberta-clip` (multilingual)
- **Recomendación**: empezar con base-patch32, evaluar large después con biblioteca real
- **Cuándo**: Fase 4

### 9. VLM para Fase 9
- **Opciones**:
  - Qwen2-VL-7B vía MLX (recomendado para Apple Silicon)
  - LLaVA 1.6 vía Ollama
  - Llama 3.2 Vision vía MLX
  - InternVL2
- **Cuándo**: Fase 9

### 10. Face detector
- **Opciones**:
  - Apple Vision (default, gratis, en M4 va volando)
  - InsightFace via Python embebido (mejor calidad en algunos casos, complejidad extra)
- **Recomendación**: Apple Vision en v1, evaluar InsightFace solo si la calidad no alcanza
- **Cuándo**: Fase 2

## Features

### 11. Importación desde redes (yt-dlp)
- **Pregunta**: ¿integrar descarga de TikTok/IG/Twitter desde la app?
- **Implicancia**: requiere embeber Python o llamar a binario yt-dlp externo
- **Recomendación**: NO en v1, evaluar en post-v2 si surge necesidad real
- **Cuándo**: post v2.0

### 12. Multi-window vs single-window
- **Pregunta**: ¿permitir varias ventanas con vistas distintas?
- **Recomendación**: single-window en v1 con tabs/sidebar para distintos contextos; multi-window post-v1
- **Cuándo**: Fase 1

### 13. Exportación
- **Pregunta**: ¿qué formatos de export?
- **Opciones**:
  - Carpeta plana con archivos copiados
  - ZIP de selección
  - HTML estático con galería
  - Markdown con thumbnails (para blogs)
- **Cuándo**: post v1.0, evaluar demanda real

### 14. Detección de duplicados perceptual
- **Pregunta**: ¿implementar pHash/dHash para imágenes similares-pero-no-idénticas?
- **Note**: ya tenemos FeaturePrint de Vision que ayuda
- **Cuándo**: post v1.0 si la demanda surge

## Organize Engine

### 15. Trash propio o Trash del sistema
- **Pregunta**: archivos reemplazados ¿van a `~/.Trash` (Trash de macOS, visible) o trash interno (`~/Library/Application Support/Atelier/organize-trash/`)?
- **Recomendación**: trash interno para auditoría y rollback, opción de "mover a Trash del sistema" como acción explícita
- **Cuándo**: Fase 6.5

### 16. Retención de rollback
- **Opciones**: 7, 14, 30, 60, 90 días
- **Default propuesto**: 30 días
- **Cuándo**: Fase 6.5

### 17. Rollback parcial
- **Pregunta**: ¿permitir rollback de solo algunos archivos de un run en vez de todos?
- **Recomendación**: sí, en Fase 7 (no en 6.5)
- **Cuándo**: Fase 7

### 18. Múltiples reglas sobre el mismo asset
- **Estrategia propuesta**: prioridad por orden en lista, primera regla wins, log de "shadowed"
- **Alternativa**: el usuario define explícitamente la prioridad numérica
- **Cuándo**: Fase 7

### 19. Reglas con acciones no-mover
- **Pregunta**: ¿reglas pueden tagear, agregar a colección, eliminar?
- **Recomendación**: empezar solo con move/copy/rename/symlink, agregar otras acciones en Fase 8
- **Cuándo**: Fase 8

### 20. Integración con tags de Finder
- **Pregunta**: ¿mostrar/escribir tags de macOS junto a los nuestros?
- **Implicancia**: sincronización bidireccional compleja
- **Recomendación**: solo lectura en v1 (mostrar tags de Finder como info), escritura post-v2
- **Cuándo**: post v1.0

### 21. Export/import de reglas
- **Pregunta**: ¿permitir compartir reglas entre instancias?
- **Formato**: JSON con schema versionado
- **Cuándo**: Fase 7 o más adelante

## UI/UX

### 22. Tema visual base
- **Decidido**: oscuro y claro, ambos pulidos
- **Pendiente**: paleta exacta, accent dinámico del sistema vs paleta fija propia
- **Cuándo**: Fase 5

### 23. Soporte de Apple Pencil / trackpad gestures avanzados
- **Pregunta**: ¿gestos de Force Touch, pinch en trackpad, etc?
- **Recomendación**: aprovechar gestos nativos sin pretender ser app específica de stylus
- **Cuándo**: Fase 5

## Datos sensibles

### 24. Bibliotecas con contenido NSFW
- **Pregunta**: ¿UI tiene modo "discreto" para esconder previews automáticamente?
- **Opciones**:
  - Sin nada especial (asumimos uso personal)
  - Tag `nsfw` que blurea thumbs por default
  - Library root marcable como "privado", requiere desbloqueo
- **Cuándo**: post v1.0 si surge necesidad

### 25. Auto-detección de contenido sensible
- **Pregunta**: ¿usar clasificador para detectar y auto-taggear NSFW?
- **Implicancia**: requiere modelo adicional, falsos positivos
- **Cuándo**: post v1.0

## Decisiones recomendadas para arrancar la Sesión 1

Si no querés trabarte en decisiones, estos defaults te dejan empezar ya:

| # | Decisión | Default sugerido para arrancar |
|---|---|---|
| 1 | Nombre | `Atelier`, bundle `com.jorgeveron.atelier` |
| 2 | Idioma UI | Español (es-AR) |
| 3 | Distribución | Personal, sin notarizar (hasta v1.0) |
| 4 | Library roots | Múltiples, configurables |
| 5 | DB ubicación | `~/Library/Application Support/Atelier/atelier.db` |
| 6 | Formato disco externo | APFS (solo Mac) |
| 8 | CLIP | `clip-vit-base-patch32` |
| 10 | Face detector | Apple Vision |
| 12 | Ventanas | Single-window |
| 15 | Trash Organize | Trash interno |
| 16 | Retención rollback | 30 días |

Estas decisiones pueden revisarse en cualquier momento, no son irreversibles.
