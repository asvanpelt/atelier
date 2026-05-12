# 08 · Tags y personas

## Sistema de tags con namespaces

Inspirado en Hydrus Network. Cada tag tiene opcionalmente un **namespace** (categoría) y un **value** (valor).

### Anatomía

```
tag = [namespace:]value
```

Ejemplos:
- `tema:programacion`
- `formato:meme`
- `plataforma:tiktok`
- `gato` (sin namespace, libre)

### Namespaces estándar sugeridos

| Namespace | Propósito | Ejemplos |
|---|---|---|
| `tema` | Contenido temático | `tema:programacion`, `tema:cocina`, `tema:politica` |
| `formato` | Tipo de pieza | `formato:meme`, `formato:reel`, `formato:foto`, `formato:gif` |
| `plataforma` | Origen | `plataforma:tiktok`, `plataforma:instagram`, `plataforma:twitter` |
| `idioma` | Texto en imagen | `idioma:espanol`, `idioma:ingles` |
| `persona` | Quién aparece (gestionado vía People) | `persona:anya-taylor-joy` |
| `mood` | Tono / sentimiento | `mood:gracioso`, `mood:melancolico` |
| `color` | Color dominante | `color:azul`, `color:monocromo`, `color:calido` |
| `calidad` | Calidad técnica | `calidad:alta`, `calidad:screenshot`, `calidad:original` |
| `proyecto` | Uso pretendido | `proyecto:blog-2024`, `proyecto:cliente-x` |
| `evento` | Evento específico | `evento:cumple-juan-2023` |

Los namespaces son **abiertos**: el usuario puede crear los suyos. La app sugiere los estándar en el primer uso pero no los impone.

### Jerarquías

Los tags pueden tener `parent_id`, formando árboles dentro de un namespace:

```
tema:tech
├── tema:tech:programacion
│   ├── tema:tech:programacion:python
│   └── tema:tech:programacion:javascript
├── tema:tech:diseno
│   ├── tema:tech:diseno:ui
│   └── tema:tech:diseno:ux
└── tema:tech:hardware
```

Búsqueda por padre incluye descendientes automáticamente.

### Colores por namespace

Default automático (hash determinístico del nombre del namespace → color):

```swift
func colorForNamespace(_ ns: String) -> Color {
    let hash = ns.hashValue
    let hue = Double(abs(hash) % 360) / 360.0
    return Color(hue: hue, saturation: 0.6, brightness: 0.8)
}
```

Usuario puede sobrescribir color por namespace o por tag individual.

## Tags automáticos

Cada tag asignado guarda `source` (origen) y `confidence`:

| Source | Origen | Confianza típica |
|---|---|---|
| `manual` | Usuario lo asignó | 1.0 (no se guarda) |
| `auto-vision` | Apple Vision classification | 0.7-0.95 |
| `auto-clip` | CLIP match con tag prototype | 0.5-0.85 |
| `auto-vlm` | VLM (Fase 9) | 0.6-0.9 |
| `auto-rule` | Asignado por regla de Organize | 1.0 |

### Display según confianza

| Confianza | Render |
|---|---|
| Manual o > 0.9 | Chip sólido, color del namespace |
| 0.7 - 0.9 | Chip sólido con badge ✨ (IA) |
| 0.5 - 0.7 | Chip outlined (sugerido, click para confirmar) |
| < 0.5 | Oculto por default, accesible en "Tags sugeridos" |

### Workflow de confirmación

```
Asset detail panel:
├── Tags confirmados
│   • tema:programacion       (manual)
│   • formato:meme            (manual)
│   • plataforma:tiktok       (auto-vision, 0.92) ✨
├── Sugeridos (3)
│   • mood:gracioso       [✓ Aceptar] [✗ Rechazar]
│   • idioma:espanol      [✓ Aceptar] [✗ Rechazar]
│   • color:azul          [✓ Aceptar] [✗ Rechazar]
```

Rechazar un tag sugerido lo marca como "no aplica" y no se vuelve a sugerir para ese asset.

## Tag suggestions inteligentes

Mientras el usuario tipea para agregar tag:

1. **Existentes** que matchean el prefijo
2. **Co-ocurrencias**: tags que suelen aparecer junto a los ya asignados
3. **Predicciones del modelo**: si CLIP / Vision detectó algo relevante
4. **Recientes**: últimos tags usados por el usuario

## Sistema de personas

Personas son una abstracción sobre face embeddings. Una persona = nombre + colección de face embeddings de referencia.

### Crear persona

```
1. Usuario abre "People" → "New Person"
2. Form: nombre, namespace (familia/amigos/famosos/etc), notas
3. Drag de assets (mínimo 3, idealmente 5) a la persona
4. Sistema extrae caras de esos assets
5. Si hay >1 cara por asset, modal "¿Cuál es {nombre}?"
6. Embeddings de referencia se guardan con is_reference=1
```

### Face matching

Para cada cara nueva detectada en indexación:

```swift
func matchFace(_ embedding: [Float]) async -> [PersonMatch] {
    let candidates = try await db.searchSimilarFaceEmbeddings(
        to: embedding,
        onlyReferences: true,
        limit: 5
    )
    return candidates.compactMap { candidate in
        let similarity = 1.0 - candidate.distance
        guard similarity > 0.5 else { return nil }
        return PersonMatch(personId: candidate.personId, confidence: similarity)
    }
}
```

### Thresholds

| Similarity | Acción |
|---|---|
| > 0.85 | Auto-asignación, `is_confirmed=0` |
| 0.65 - 0.85 | Queue de confirmación |
| 0.50 - 0.65 | Sugerencia opcional |
| < 0.50 | Sin match |

Configurable global en preferences.

### Review queue

UI dedicada en People:

```
Pending confirmation (47)

┌────────────────────────────────────┐
│  [cara recortada]                  │
│                                    │
│  ¿Es Anya Taylor-Joy?              │
│  Confianza: 78%                    │
│                                    │
│  [✓ Sí]  [✗ No]  [? Otra persona]  │
└────────────────────────────────────┘
```

Decisiones:
- **Sí**: marca `is_confirmed=1`, refuerza modelo (embedding entra al pool de referencia)
- **No**: marca como "not this person", no se vuelve a sugerir
- **Otra persona**: dropdown para elegir o crear nueva persona

### Fusionar / dividir personas

- **Fusionar**: dos personas con embeddings → una persona, todos los matches consolidados
- **Dividir**: una persona con clusters internos distintos → separar en múltiples personas

### Privacidad

- Las caras y embeddings nunca salen del Mac
- Opción de exportar/borrar todas las caras de una persona específica
- "Forget person": elimina persona y todos sus face matches
- "Forget all faces": opción nuclear, borra todo el subsistema de personas

## Integración Tags ↔ Personas

Cada persona genera un tag virtual automáticamente:

```
Person "Anya Taylor-Joy" → tag virtual persona:anya-taylor-joy
```

Esto permite:
- Buscar igual que cualquier tag
- Usar en queries de Organize Engine
- Aparecer en sidebar bajo namespace `persona`

El tag se mantiene sincronizado con confirmaciones (solo se asigna cuando `is_confirmed=1` o confidence > umbral).
