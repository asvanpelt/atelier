# 09 · Organize Engine

Sistema opt-in para **proponer y ejecutar reorganizaciones físicas** del filesystem basadas en reglas que combinan tags, personas, metadata y otras señales del índice.

## Principios

- **Nunca destructivo sin preview**: toda operación se previsualiza antes de ejecutarse
- **Siempre reversible**: cada operación queda en un journal con rollback durante ventana configurable
- **Atomicidad por archivo**: si falla mover uno, los otros siguen, pero el estado queda consistente
- **El índice se actualiza en la misma transacción**: nunca queda desincronizado con el disco
- **Reglas declarativas**: el usuario describe el "qué", la app resuelve el "cómo"
- **Trazabilidad total**: cada archivo recuerda dónde estuvo, por qué se movió, cuándo

## Casos de uso

### Caso A: Organización por taxonomía
> "Mové todos los assets con `tema:memes` y `plataforma:tiktok` a `/Memes/TikTok/` agrupados por mes"

### Caso B: Segregación de contenido
> "Todo lo que tenga `persona:familia` movélo de `/Descargas/Mezcla/` a `/Fotos-Personales/Familia/AAAA/MM/`"

### Caso C: Limpieza por confianza
> "Todo lo que tenga `auto-tag:nsfw` con confianza > 0.7 movélo a `/Privado/`"

### Caso D: Renombrado consistente
> "Renombrá todos los assets en esta carpeta usando el patrón `{fecha}_{plataforma}_{hash6}.{ext}`"

### Caso E: Deduplicación
> "Para cada grupo de duplicados, conservá la versión de mayor resolución, mové las otras a `/Trash-Dupes/`"

### Caso F: Aplanado o anidamiento
> "Tomá esta carpeta plana de 5000 memes y reorganizá en subcarpetas por tema principal"

### Caso G: Migración a disco externo
> "Todos los assets antiguos a más de 1 año movélos al disco externo conservando estructura relativa"

## Modelo conceptual

### Anatomía de una regla

```
ORGANIZE RULE
├── Match: ¿qué assets aplica?
│   ├── Tags requeridos / excluidos
│   ├── Personas
│   ├── Rango de fechas
│   ├── Carpeta de origen
│   ├── Tipo de media
│   ├── Resultado de query CLIP
│   └── Filtros custom
│
├── Action: ¿qué hacer con ellos?
│   ├── Move | Copy | Rename | Symlink
│   ├── Destination path template
│   ├── Filename template
│   └── Conflict resolution
│
└── Policy: ¿cómo ejecutar?
    ├── Dry-run vs Apply
    ├── Manual confirm vs Auto
    ├── Schedule (manual, on-tag, periódico)
    └── Rollback retention
```

## Path templates

Sistema de templates con variables, similar a Hazel o reglas de Lightroom.

### Variables disponibles

```
{year} {month} {day} {hour}              ← fecha de captura/creación
{indexed_year} {indexed_month}           ← fecha de indexación
{tag:namespace}                          ← primer tag de ese namespace
{tags:namespace:join(_)}                 ← todos los tags de ese namespace
{person:first}                           ← primera persona detectada
{persons:join(_)}                        ← todas las personas
{platform} {format} {theme}              ← shortcuts comunes
{ext} {hash6} {hash8}                    ← extensión, hash corto
{original_filename}                      ← nombre original sin extensión
{counter:start=1:digits=4}               ← contador 0001, 0002...
{width}x{height}                         ← dimensiones
{duration_seconds}                       ← para videos
{root_label}                             ← label del library root de origen
```

### Funciones de transformación

```
{tag:tema | lower | slug}                ← lowercase + slug (kebab-case ASCII)
{original_filename | truncate(40)}
{year | fallback("sin-fecha")}
{tag:tema | default("misc")}
{name | replace(" ","-")}
```

### Ejemplos

```
Template: /Memes/{platform}/{year}/{year}-{month}_{tag:tema}_{hash6}.{ext}
Resultado: /Memes/tiktok/2024/2024-03_programacion_a3f9c1.mp4

Template: {root_label}/{persons:join(-)}/{year}/{original_filename}.{ext}
Resultado: Fotos-Familia/maria-juan/2023/cumple-juan.heic

Template: {indexed_year}/{tag:tema | default("sin-tema")}/{counter:digits=5}.{ext}
Resultado: 2024/programacion/00042.png
```

## Conflict resolution

Cuando el destino ya existe:

| Policy | Comportamiento |
|---|---|
| `skip` | Dejar archivo en origen, loggear |
| `replace` | Sobrescribir destino (mover original reemplazado a trash interno) |
| `rename` | Agregar sufijo incremental `_2`, `_3` |
| `hash-suffix` | Si el destino tiene hash distinto, agregar sufijo `_a3f9c1` |
| `merge` | Si ambos tienen el mismo hash, conservar uno, registrar otro como duplicado |

## Arquitectura del engine

```
┌────────────────────────────────────────────────────┐
│              OrganizeService (actor)                │
│  - createRule, updateRule, listRules                │
│  - planRun(rule, mode) → OrganizePlan               │
│  - executePlan(plan) → OrganizeRun                  │
│  - rollback(run) → OrganizeRun                      │
└────────────────────────────────────────────────────┘
```

## Flujo paso a paso

```swift
// 1. PLAN (siempre primero, nunca destructivo)
let rule = OrganizeRule(
    name: "Memes TikTok",
    match: .all([
        .tag(namespace: "plataforma", value: "tiktok"),
        .tag(namespace: "formato", value: "meme")
    ]),
    action: .move(
        destinationRoot: "/Users/me/Library/Memes",
        pathTemplate: "{platform}/{year}/{tag:tema}/{hash6}.{ext}",
        conflictPolicy: .rename
    )
)

let plan = try await organizeService.plan(rule: rule)
// → OrganizePlan { operations: [PlannedOperation], warnings: [...], stats: {...} }

// 2. PREVIEW
//    UI muestra plan: 234 archivos van a moverse, 12 conflicts, 3 paths inválidos
//    Usuario puede editar regla o aprobar

// 3. EXECUTE
let run = try await organizeService.execute(plan: plan, mode: .apply)
// → cada operación atómica: FS move + DB update en orden seguro

// 4. ROLLBACK (opcional)
try await organizeService.rollback(run: run)
```

## Atomicidad por operación

Para cada archivo, el orden seguro es:

```
1. Verificar source aún existe y es el archivo esperado (hash check vs snapshot)
2. Crear directorios destino si no existen
3. Verificar destino, aplicar conflict policy
4. Si reemplazo: mover destino actual a trash interno
5. mv en filesystem (FileManager.moveItem, atómico en mismo volumen)
6. UPDATE assets SET file_path = newPath WHERE id = assetId
7. INSERT INTO asset_path_history (...)
8. UPDATE organize_operations SET status = 'applied', applied_at = now()
```

Si falla algún paso después del `mv`, intentamos `mv` inverso. Si falla el inverso (muy raro), marcamos `failed` con error detallado: el archivo queda en limbo conocido, no perdido.

## Cruzar volúmenes (disco externo)

`mv` entre volúmenes distintos no es atómico (es copy + delete). Estrategia:

1. Copy a destino con sufijo `.atelier-tmp`
2. Verificar hash en destino
3. Rename `.atelier-tmp` → nombre final (atómico en mismo volumen)
4. Delete source
5. Si algo falla antes del delete, source queda intacto

## UI

### Pantalla "Organize"

Sección nueva en sidebar con tres tabs:

#### Tab 1: Rules
Lista de reglas guardadas con:
- Estado (activa/inactiva, auto/manual)
- Última corrida
- Botones: editar, duplicar, "Run preview", "Run now"

#### Tab 2: Rule Editor

```
┌─────────────────────────────────────────────────┐
│ Nombre: [Memes TikTok                       ]   │
│                                                 │
│ MATCH                                           │
│ Match all of:                                   │
│ • Tag is plataforma:tiktok          [×]         │
│ • Tag is formato:meme               [×]         │
│ • Date is in last 30 days           [×]         │
│ [+ Add condition]                               │
│                                                 │
│ → 247 assets match this query [Preview]         │
│                                                 │
│ ACTION                                          │
│ ⦿ Move   ◯ Copy   ◯ Rename only   ◯ Symlink    │
│                                                 │
│ Destination: [Browse...] /Memes                 │
│                                                 │
│ Path template:                                  │
│ [{platform}/{year}/{tag:tema}/{hash6}.{ext}  ]  │
│                                                 │
│ Preview path:                                   │
│ /Memes/tiktok/2024/programacion/a3f9c1.mp4      │
│                                                 │
│ On conflict: [Rename with suffix ▼]             │
│                                                 │
│ POLICY                                          │
│ ☑ Require confirmation before applying          │
│ ☐ Auto-run when assets get matching tags        │
│                                                 │
│        [Cancel]   [Save rule]   [Preview run]   │
└─────────────────────────────────────────────────┘
```

#### Tab 3: Preview / Execution

```
┌─────────────────────────────────────────────────┐
│ Plan: Memes TikTok           Dry-run            │
│ 247 assets · 12 GB · 8 conflicts                │
│                                                 │
│ ⚠️ 8 conflicts detected — see below             │
│ ⚠️ 3 assets have ambiguous template values      │
│                                                 │
│ ┌─────┬─────────────────────┬─────────────────┐ │
│ │     │ From                │ To              │ │
│ ├─────┼─────────────────────┼─────────────────┤ │
│ │ [✓] │ /Mezcla/abc.mp4     │ /Memes/tiktok/  │ │
│ │ [⚠] │ /Mezcla/xyz.mp4     │ ... CONFLICT    │ │
│ │ [✓] │ /Mezcla/def.mp4     │ /Memes/tiktok/  │ │
│ └─────┴─────────────────────┴─────────────────┘ │
│                                                 │
│ Filter: [All] [Conflicts] [Warnings] [OK]       │
│                                                 │
│        [Cancel]   [Apply 239 of 247]            │
└─────────────────────────────────────────────────┘
```

#### Tab 4: History

```
Today
  ✓ Memes TikTok — Applied 239 files     [Rollback]
  ⊘ Cleanup duplicates — Dry-run         [Run again]

Yesterday
  ✓ Sort by person — Applied 1,204 files [Rollback]
  ↶ Migrate to external — Rolled back
```

### Quick actions desde el grid

Sin necesidad de crear una regla:

1. Seleccionar N archivos en el grid
2. Click derecho → "Organize..."
3. Modal rápido con destino + template
4. Mismo motor de preview/apply/rollback

### Indicadores visuales

- Archivos movidos por una regla muestran ícono pequeño en hover (📋 con badge)
- Click muestra "Moved by rule 'Memes TikTok' on March 14"

## Casos especiales y edge cases

### Usuario tocó el archivo entre plan y apply

- En cada operación, antes del `mv`, recomputar hash de source
- Si no coincide con el hash del plan, marcar como `skipped: source_modified`
- UI muestra warning, usuario puede regenerar el plan

### Disco externo desconectado durante un run

- Detectar pérdida de volumen vía `NSWorkspace.didUnmountNotification`
- Pausar run, no fallar
- Reintentar cuando se reconecte (o cancelar tras timeout)

### Path template inválido para algunos assets

Opciones por regla:
- **Strict**: marcar asset como `failed: missing_variable`
- **Fallback**: usar valor por defecto en template `{tag:tema | fallback("sin-tema")}`
- **Skip**: omitir asset, loggear

### Permisos macOS

- Cada library_root tiene security-scoped bookmark
- Si destino está fuera de library roots conocidos, pedir permiso explícito (NSOpenPanel) y guardar bookmark
- Sin permiso: regla `requires_permission`, no se ejecuta

### Espacio en disco

- Antes de cada run, calcular espacio necesario en destino
- Si no alcanza, abortar plan con error claro
- Para cross-volume, considerar espacio temporal del copy

### Cascada de eventos

Si una regla con `auto_run_on_new` está activa y taggeas 500 archivos a la vez:
- **Debounce**: agrupar eventos en ventanas de N segundos
- **Batch**: un único run con todos los archivos afectados

## Rollback en profundidad

El rollback es el escudo psicológico del usuario: saber que puede deshacer hace que use la feature con confianza.

### Estrategia

Por cada operación en orden inverso:

```
ROLLBACK MOVE:
  1. Verificar archivo aún está en destino con hash esperado
  2. mv destino → source original
  3. UPDATE assets SET file_path = source_path
  4. INSERT INTO asset_path_history (rollback)
  5. Si source_path tiene directorios vacíos creados por la regla, limpiarlos

ROLLBACK COPY:
  - Eliminar copia en destino (con confirmación si fue editada)

ROLLBACK RENAME:
  - Igual que move pero mismo directorio

ROLLBACK con replaced files:
  - Si la operación reemplazó un archivo, el original se mueve al trash interno
    ~/Library/Application Support/Atelier/organize-trash/run-{id}/
  - Rollback restaura desde ese trash
  - Trash se limpia después de N días configurables
```

### Retención

- Default: rollback disponible durante 30 días
- Configurable global y por regla
- "Forget run" libera espacio del journal y elimina trash asociado
- Runs muy antiguos quedan en history sin opción de rollback (auditoría)

### Limitaciones reconocidas

- Si el usuario edita un archivo movido después del move, el rollback ofrece elegir:
  - Revertir igual (pierde edición)
  - Skip
  - "Move edited file alongside" (deja la edición y restaura el original)
- Si elimina archivos por Finder después del move, rollback los marca `unrecoverable` y sigue con el resto

## Posicionamiento en el roadmap

Esta feature **NO va en el MVP**. Va en fases posteriores al v1.0 (ver `10-roadmap.md`).

Niveles incrementales:
- **v1.1 (Fase 6.5)**: Quick actions ad-hoc + rollback
- **v1.2 (Fase 7)**: Reglas guardadas, editor visual, history
- **v1.3 (Fase 8)**: Automatización (auto-run on-tag, scheduled)
