# Detección de origen y cuenta

Atelier deduce automáticamente la **plataforma de origen** y, cuando es posible, la **cuenta** (`@username`) a partir del nombre de archivo. La detección corre al indexar y se puede reprocesar con un botón en la toolbar.

## Modelo de datos

Migración **M004_AssetSource** agrega dos columnas a `assets`:

| Columna | Tipo | Notas |
|---|---|---|
| `source` | TEXT (nullable) | Identificador interno (`instagram`, `twitter`, …). Se mapea a `AssetSource` en Swift. |
| `source_account` | TEXT (nullable) | Username sin `@`. Solo cuando el patrón lo expone. |

Índices: `idx_assets_source`, `idx_assets_source_account`.

## Cuándo se ejecuta

1. **Automático** — `IndexingService.indexFile(...)` llama a `SourceDetector.detect(filename:)` en cada upsert. Si el patrón hace match, escribe `source` / `source_account`. Si no, se preservan los valores existentes (no pisa con `nil`).
2. **Manual** — botón **"Detectar origen"** en la toolbar (`scope`) corre el detector sobre todos los assets con `source IS NULL`. Útil para procesar la biblioteca histórica una sola vez tras la migración.

## Patrones reconocidos

Los regex viven en `Atelier/Services/SourceDetector.swift`. El orden importa: el primer match gana.

| Origen | Patrón (regex Swift literal) | Ejemplo | Captura cuenta |
|---|---|---|---|
| `instagram` | `^_*(?<account>[A-Za-z0-9._]+?)_*__\d{4}-\d{2}-\d{2}T\d{6}\.\d{3}Z(_\d+)?(\(\d+\))?\.[A-Za-z0-9]+$` | `elixserr__2026-01-12T183727.000Z_3.jpg`, `_francis.co__2026-01-15T125626.000Z_8.jpg`, `brenda_nicole______2026-01-18T012339.000Z.jpg` | ✅ |
| `instagram_cdn` | `^\d{8,}_\d{8,}_\d{8,}_n\.(?i)(jpg\|jpeg\|png\|webp\|mp4)$` | `629371855_865240773228252_6612711687832509072_n.jpg` | ❌ |
| `twitter` | `^[A-Za-z0-9_-]{15}\.(?i)(jpg\|jpeg\|png\|webp)$` | `HCbL9JIb0AAVvN4.jpeg` | ❌ |
| `tiktok` | `^(?i)(tiktok_\|tt_)` | `tiktok_dance.mp4`, `tt_clip.mp4` | ❌ (todavía) |
| `whatsapp` | `^WhatsApp (Image\|Video\|Audio) ` | `WhatsApp Image 2026-02-02 at 11.39.33.jpeg` | ❌ |
| `screenshot_mac` | `^(Captura de pantalla\|Screenshot\|Screen Shot) ` | `Captura de pantalla 2026-04-17 a la(s) 11.50.18 a. m..png` | ❌ |
| `screenshot_android` | `^(IMG_\|VID_\|PXL_\|Screenshot_)?\d{8}[_-]\d{6}` | `20250608_121027.jpg`, `IMG_20250608_121027.jpg`, `PXL_20250101-153000.jpg` | ❌ |
| `gemini` | `^Gemini_Generated_` | `Gemini_Generated_Image_ka398zka398zka39.png` | ❌ |

### Notas sobre el patrón Instagram (downloader)

Producido por extensiones tipo "Instagram Downloader" de Firefox:

- `__` (doble underscore) separa username de timestamp ISO-8601 sin separadores (`YYYY-MM-DDTHHMMSS.000Z`).
- Acepta `_` iniciales y trailing en el username (`_francis.co__`, `brenda_nicole______`) gracias a `_*` en ambos extremos.
- El sufijo `_N` (carrusel) y `(N)` (duplicado) son opcionales.
- Username permite letras, dígitos, `.` y `_`.

### Cobertura conocida que NO matchea

- `unnamed.png`, `harrynoo.mp4` — sin pistas → quedan en `source = NULL`.
- Patrón Instagram CDN cuando viene sin el sufijo `_n` — clasificaría mal, por eso el regex exige `_n.ext`.

Para ampliar cobertura: agregar el regex en `SourceDetector`, agregar el case en `AssetSource` (con `label` y `symbol` SF Symbol), y opcionalmente correr el botón "Detectar origen" para reclasificar lo viejo.

## API

### `enum AssetSource: String, CaseIterable`

Casos: `.instagram`, `.instagramCdn`, `.tiktok`, `.twitter`, `.whatsapp`, `.screenshotMac`, `.screenshotAndroid`, `.gemini`, `.unknown`.

Propiedades:
- `label: String` — nombre legible (`"Instagram"`, `"Captura de pantalla (Mac)"`, …).
- `symbol: String` — SF Symbol asociado (`camera.fill`, `bird.fill`, …).

### `enum SourceDetector`

```swift
static func detect(filename: String) -> SourceDetectionResult
```

`SourceDetectionResult` es `(source: AssetSource, account: String?)`. Retorna `.unknown` si ningún patrón aplica.

### `AssetRepository`

| Método | Uso |
|---|---|
| `updateSource(id:source:account:)` | Persiste el resultado del detector. |
| `findBySource(_:account:)` | Filtra assets por origen (y opcional cuenta). |
| `sourceSummary()` | `[(source, count)]` ordenado descendente, para sidebar. |
| `accountsForSource(_:)` | `[(account, count)]` para expandir el disclosure. |
| `allWithoutSource()` | Assets con `source IS NULL` — input del botón "Detectar origen". |

## UI

- **Sidebar → "Orígenes"**: `DisclosureGroup` por plataforma con badge de cantidad. Click en el header filtra por origen; expandir lista cuentas, click en una filtra por origen + cuenta.
- **InspectorPanel → `sourceSection`**: chip arriba de "Tags" con ícono SF Symbol, label y `@account` si existe. Texto seleccionable.
- **Toolbar → "Detectar origen"**: corre `MainWindow.detectSources()` que itera `allWithoutSource()` y reporta progreso en la status bar.

## Cómo agregar un patrón nuevo

1. En `Atelier/Services/SourceDetector.swift`:
   - Agregar el case en `AssetSource` (rawValue, `label`, `symbol`).
   - Declarar el regex como `private nonisolated(unsafe) static let nuevoPatron = #/.../#`.
   - Sumar el branch en `detect(filename:)` respetando el orden (más específico primero).
2. Si requiere capturar cuenta: usar `(?<account>...)` y mapearlo en el branch.
3. Reiniciar la app y correr "Detectar origen" para reclasificar.
