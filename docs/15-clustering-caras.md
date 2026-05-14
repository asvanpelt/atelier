# Clustering de caras (parked)

> **Estado:** prototipo desactivado en UI. Schema y servicios quedan en el repo para retomarlo.
> **Razón del freeze:** `VNGenerateImageFeaturePrintRequest` no es face-specific y todas las caras quedaron a distancias muy parecidas (un solo cluster gigante con threshold laxo, miles de clusters de 1 con threshold estricto). Necesitamos un modelo de embeddings entrenado para identidad facial antes de que el clustering aporte valor.

## Lo que ya está construido (sigue en el repo)

| Pieza | Path |
|---|---|
| Migración `M005_FaceClustering` | `Atelier/Database/Migrations/M005_FaceClustering.swift` |
| Columnas `embedding BLOB`, `cluster_id INTEGER` en `face_observations` | aplicada en cualquier base ya migrada |
| `VisionService.runFaceEmbedding(url:bbox:)` + `decodeFeaturePrint` + `distance` | `Atelier/Services/VisionService.swift` |
| `FaceClusteringService` (greedy + auto-asignar) con thresholds + logging de distribución | `Atelier/Services/FaceClusteringService.swift` |
| Métodos repo `updateEmbedding`, `updateCluster`, `clusterSummary`, `facesInCluster`, `assignClusterToPerson`, `resetClusters`, `confirmedFacesWithEmbedding`, `facesNeedingEmbedding`, `facesWithEmbeddingUnassigned`, `nextClusterId` | `Atelier/Database/Repositories/VisionRepository.swift` |
| Sheet de detalle de cluster (asignar todo, sacar caras, asignar individual) | `Atelier/Views/Main/People/ClusterDetailSheet.swift` |

## Lo que se quitó de la UI

- Botón **"Reagrupar caras"** en la toolbar de `MainWindow`.
- Status indicator de progreso de clustering.
- Sección **"Clusters detectados"** + **"Sin agrupar"** en `PeopleManagerView` "Sin asignar".
- Llamada automática a `clusteringService.computeEmbedding` después de detectar caras en `IndexingService`.

`PeopleManagerView` "Sin asignar" volvió al grid plano de caras deduplicadas por `asset_id` (comportamiento anterior).

## Por qué no funcionó con `VNFeaturePrint`

`VNGenerateImageFeaturePrintRequest` produce un descriptor de propósito general. Para crops faciales de tamaños chicos (~150–300 px) los vectores quedan muy parecidos entre sí porque el modelo no fue entrenado para distinguir identidades — atiende a textura, color global, composición. Resultado observado:

- Threshold 22 → 1 cluster con cientos de caras (todo entra).
- Threshold 12 → mismo problema, todo cae bajo 12 de distancia.
- Threshold 2.5 → expectativa de splits razonables sin verificar (a confirmar con logs si se retoma).

## Plan para retomar — opciones ordenadas

### Opción A — Bundlear un modelo CoreML face embedding (recomendado)

Modelos candidatos (todos convertibles a `.mlmodel`):

| Modelo | Output | Tamaño | Notas |
|---|---|---|---|
| **MobileFaceNet** | 192-dim | ~5 MB | Excelente trade-off velocidad/calidad. Repo PyTorch + script `coremltools`. |
| **FaceNet (Inception ResNet v1)** | 128-dim | ~90 MB | Calidad alta, modelo grande. |
| **ArcFace (ResNet50)** | 512-dim | ~170 MB | State of the art. Demasiado para una app de escritorio liviana. |

Pasos:
1. Bajar pesos pre-entrenados (ej. [insightface](https://github.com/deepinsight/insightface) o repos de MobileFaceNet en PyTorch).
2. Convertir con `coremltools` a `.mlmodel`, luego compilar a `.mlmodelc` para incluir en bundle.
3. Agregar `.mlmodelc` como recurso en `Package.swift` (`resources: [.process("Resources/...")]`).
4. Reemplazar `VisionService.runFaceEmbedding` por una versión que:
   - Cargue el modelo una vez (`MLModel(contentsOf:)`).
   - Crop facial → resize a input size del modelo (típicamente 112×112 o 160×160).
   - Normalice según la convención del modelo (FaceNet usa `(pixel - 127.5) / 128`).
   - Devuelva el output vector como `Data` (ej. `[Float] → Data`).
5. Reemplazar `VisionService.distance` por **cosine similarity** (`1 - dot(a, b) / (|a| * |b|)`) — los embeddings face-specific se comparan así, no con `VNFeaturePrintObservation.computeDistance`.
6. Re-tunear thresholds con dataset propio: típico `cosine < 0.4` = misma persona, `0.4–0.6` = ambiguo, `> 0.6` = distinto.

### Opción B — Usar `VNFaceLandmarks2DRequest` + features manuales

Calcular ratios entre puntos (distancia ojos/nariz/boca, ángulos) y formar un vector geométrico. Barato pero muy débil ante poses, oclusiones y variaciones de cámara. **Solo como fallback rápido si no se quiere bundlear modelo.**

### Opción C — Esperar API nativa de Apple

Apple no ha publicado un face embedding API a 2026-05. Si lo hace en una futura WWDC, sería el camino más limpio.

## Algoritmo de clustering

El greedy actual (un solo pass por todas las caras + comparar contra centroides existentes) escala mal: O(N × K) donde K es el número de personas/clusters. Para >10k caras conviene:

1. **HNSW / Annoy** para vecino más cercano aproximado.
2. **DBSCAN** para descubrir clusters densos sin necesidad de K predefinido — funciona bien con face embeddings normalizados y eps ≈ 0.4 (cosine).
3. **Re-clustering incremental**: en lugar de reset completo, al agregar una cara nueva solo comparar contra centroides existentes y sus k vecinos.

Para empezar, dejar el greedy actual con un buen modelo es suficiente. Refactorizar cuando duela.

## UX a recuperar cuando se retome

Lo que ya estaba diseñado y se puede reactivar tal cual:

- Botón **"Reagrupar caras"** en toolbar con status bar.
- En "Sin asignar":
  - Sección **"Clusters detectados"** — un tile por cluster, badge `person.3.fill` con N caras.
  - Sección **"Sin agrupar"** — caras que no entraron en ningún cluster.
  - Single-click en un cluster → `ClusterDetailView` con grilla completa, "Asignar todo a…" y "Sacar del cluster" por cara.
  - Doble-click → abrir foto en Finder.
- Auto-asignar a personas existentes con threshold conservador, dejar el resto para revisión humana.
- Exponer `autoAssignThreshold` y `clusterThreshold` en Preferences (slider con preview en tiempo real).

## Cómo desactivar/reactivar el código actual

**Para reactivar el botón de toolbar y la UI de clusters cuando bundleemos el modelo CoreML:**

1. En `Atelier/Views/Main/MainWindow.swift`:
   - Restaurar el `Button("Reagrupar caras", systemImage: "person.3.sequence.fill") ...` en el `ToolbarItemGroup(.primaryAction)` (entre "Detectar origen" e "Inspector").
   - Restaurar el branch `} else if isClustering { ... }` en el `ToolbarItem(.status)`.
   - Restaurar `private func reclusterFaces() async { ... }` (ya existe en git history del commit que agregó clustering).
2. En `Atelier/Views/Main/People/PeopleManagerView.swift`:
   - Restaurar el branch `unassignedContent` en `faceGallery`.
   - Restaurar la carga dual de `clusters` + `soloUnassigned` en `loadFacesForSelection`.
   - Restaurar el `.sheet(item: $clusterDetailItem) { ... }` y el `.onTapGesture` que abre `ClusterDetailView`.
3. En `Atelier/Services/IndexingService.swift`:
   - Reagregar `let savedFaces = try await visionRepo.facesFor(assetId: id); for face in savedFaces where face.embedding == nil { await clusteringService.computeEmbedding(for: face) }` después de `saveFaceObservations`.
4. Reemplazar internamente `VisionService.runFaceEmbedding` por la versión basada en CoreML (ver Opción A).

El schema, los servicios y la sheet de cluster ya están listos — el costo real de retomar es **solo** el modelo CoreML y volver a poner los hooks de UI.

## Métricas que vale la pena instrumentar antes de claim "anda bien"

- Distribución de distancias entre pares de caras de la misma persona (debería ser bimodal: pico bajo = misma persona, pico alto = distinta).
- Precisión / recall sobre un set manual de 50–100 caras etiquetadas.
- Tiempo de embedding por cara (target: < 100 ms).
- Tiempo total de "Reagrupar caras" sobre la biblioteca completa.

El logging de `min/p25/p50/p75/max/mean` que dejé en `FaceClusteringService.reclusterAll` ya cubre el primer punto — solo hay que mirar Console.app filtrando por subsystem `indexing`.
