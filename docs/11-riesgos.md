# 11 · Riesgos y mitigaciones

| # | Riesgo | Impacto | Probabilidad | Mitigación |
|---|---|---|---|---|
| 1 | sqlite-vec no compila o tiene bugs en macOS | Alto | Baja | Plan B: faiss vía bridging C++, o LanceDB nativo Swift, o vectores en BLOB con búsqueda lineal hasta 50k |
| 2 | MLX Swift inmaduro para CLIP | Medio | Baja-Media | Plan B: CoreML conversion de CLIP (existen scripts oficiales de Apple), o llama.cpp con bindings Swift |
| 3 | FSEvents pierde eventos en bibliotecas grandes | Medio | Media | Scan periódico de respaldo cada 6 horas como safety net |
| 4 | Grid se traba con bibliotecas >100k | Alto | Media | Profiling temprano con Instruments, fallback a paginación, virtualización con NSCollectionView |
| 5 | Permisos macOS bloquean acceso a discos externos | Alto | Media | Onboarding claro, bookmarks bien manejados, diagnóstico in-app, regeneración de bookmarks |
| 6 | CLIP no entiende bien queries en español | Medio | Media | Multi-lingual CLIP variant disponible (xlm-roberta-clip), evaluable al testear |
| 7 | Caras de famosas mal matcheadas | Bajo-Medio | Alta | UI de confirmación obligatoria, threshold ajustable, opción "no es esta persona", fusión/división de personas |
| 8 | Descripciones VLM (Fase 9) consumen mucho disco/RAM | Medio | Media | Opt-in, cola de baja prioridad, batch nocturno, modelo configurable |
| 9 | Operación de Organize Engine rompe archivos | Crítico | Baja | Preview obligatorio, snapshot de hashes, atomicidad por archivo, rollback robusto, trash interno |
| 10 | Disco se llena durante indexación (caché thumbs) | Medio | Media | Límite de caché configurable, LRU cleanup, alerta al usuario antes de fallar |
| 11 | Reindexado masivo bloquea uso de la app | Medio | Media | Indexación en background con prioridad baja, UI muestra progreso pero no bloquea |
| 12 | Migraciones de DB rompen instalaciones existentes | Alto | Baja | Migraciones versionadas idempotentes, backup automático antes de migrar, rollback si falla |
| 13 | App crashea durante una operación de Organize | Alto | Baja | Journal en DB antes de ejecutar cada paso, recovery al abrir la app detecta runs interrumpidos |
| 14 | Modelo CLIP cambia entre versiones de app | Medio | Baja | Versionado de embeddings (`model_version`), reindex selectivo, sin pérdida de búsquedas viejas |
| 15 | Usuario borra archivo desde Finder durante búsqueda | Bajo | Alta | Detección de archivos faltantes en próximo scan, soft delete, no romper queries en vivo |
| 16 | Library root en disco externo desaparece (disco roto) | Medio | Baja | Marcar como `unavailable` indefinidamente, no borrar metadata, esperar reconexión |
| 17 | Sandbox de macOS rechaza acceso fuera de bookmarks | Alto | Media | NSOpenPanel para cada directorio destino de Organize, bookmark almacenado por root |
| 18 | DB corrupta por crash de sistema | Alto | Muy baja | WAL mode + backups periódicos en `~/Library/Application Support/Atelier/backups/` |
| 19 | Carga del modelo CLIP en cada indexación es lenta | Medio | Alta sin mitigación | Modelo cargado una vez, mantenido en memoria del actor de CLIPService, descargado por inactividad opcional |
| 20 | Notarización fallida al distribuir | Bajo | Baja | Configurar entitlements y hardened runtime desde Fase 0, testear notarización temprano |
| 21 | El usuario no entiende el sistema de tags | Medio | Media | Onboarding con ejemplos, tags sugeridos automáticos, namespaces pre-cargados con ejemplos |
| 22 | Privacy / surveillance percibida por scan de archivos | Bajo | Baja | Mensaje claro al onboarding: "Todo es local, nada sale del Mac". Open source o transparencia en docs |
| 23 | Reglas de Organize que se autodestruyen (loop) | Medio | Baja | Detección de loops: si un asset fue movido por una regla en últimos N minutos, no re-ejecutar esa regla sobre él |
| 24 | Conflicto entre múltiples reglas auto-run | Medio | Media | Priorización explícita, log de "shadowed by rule X", UI muestra reglas que pueden chocar |
| 25 | Performance de KNN sobre 100k+ embeddings | Medio | Media | sqlite-vec usa ANN, profiling al llegar a esa escala, posible upgrade a faiss IVF si hace falta |
| 26 | Pérdida de bookmarks tras update de macOS | Bajo | Baja | Detección al boot, prompt para re-autorizar carpeta, log de eventos |

## Plan de contingencia general

Para los riesgos críticos (1, 9, 12, 13, 18):

1. **Backup automático** de DB cada N días en `~/Library/Application Support/Atelier/backups/`, rotación de 7
2. **Export manual** de DB desde Preferences → Advanced
3. **Recovery mode**: si la DB no abre, app arranca en modo seguro y ofrece restaurar desde backup
4. **Diagnóstico in-app** con info de salud del sistema: tamaño DB, integridad, último backup, espacio disponible

## Lo que conscientemente NO mitigamos

- **Sincronización multi-máquina**: no es feature de v1, no nos preocupamos por conflictos de DB
- **Performance bajo 8GB RAM en Intel Mac**: target es Apple Silicon, Intel funciona con features degradadas
- **Archivos accedidos por otras apps simultáneamente**: confiamos en macOS para serializar acceso
- **Bibliotecas de 1M+ assets**: target inicial es 10k-200k, casos extremos se evalúan después
