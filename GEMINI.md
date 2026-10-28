# Directivas de Proyecto — PeYa Market

Este proyecto concentra los datamarts de BigQuery, automatizaciones de Google Apps Script y dashboards operativos de PedidosYa Market.

## 1. Métricas Operativas y Reglas de Alertas
* **Evaluación en Puntos Porcentuales (`pp`):** Todas las métricas de porcentaje operacional evalúan variaciones y desvíos estrictamente en puntos porcentuales para evitar distorsiones con denominadores bajos.
* **Baselines (L3W):** Las alertas de volumen y tiempos comparan contra el promedio del mismo día de la semana de las últimas 3 semanas (L3W).

## 2. Desarrollo en Google Apps Script
* **Límites de Ejecución:** Respetar el límite de 6 minutos por ejecución de Apps Script. Para tareas masivas o de sincronización, particionar las ejecuciones o procesar por lotes.
* **Modularidad:** Separar lógica de servidor (`Code.gs`, `EmailSender.gs`, `RankingUso.gs`) de las vistas (`Index.html`, partials `_nav.html`, etc.) usando `HtmlService`.
* **Seguridad de Datos:** No hardcodear credenciales ni tokens sensibles en el código fuente.

## 3. Consultas SQL y Datamarts (BigQuery)
* **Identificador Obligatorio `query_name`:** Toda consulta SQL DEBE comenzar obligatoriamente con la declaración `DECLARE query_name STRING DEFAULT '<nombre_o_identificador_de_la_query>';` en su primera línea.
* **Protocolo de Costos en BigQuery (Antes y Después de Cada Ejecución):**
  - **Antes de Ejecutar (Dry-Run / Estimación):** Es MANDATORIO realizar una estimación previa (`--dry_run=true` o cálculo de bytes escaneados) e informar al usuario el volumen de datos estimado a procesar (MB, GB o TB).
  - **Después de Ejecutar (Estadísticas Reales):** Es MANDATORIO reportar inmediatamente las métricas reales de ejecución del job:
    1. **Datos procesados / facturados:** Bytes exactos en GB o TB (`totalBytesBilled` / `totalBytesProcessed`).
    2. **Consumo de cómputo en slots:** Tiempo acumulado en slots (`totalSlotMs` / slot-segundos / slot-horas).
    3. **Duración de ejecución:** Tiempo total transcurrido en segundos (`finalExecutionDurationMs`).
    4. **Reserva aplicada:** Identificador de la reserva de slots corporativa (`reservation_id`, ej. `peya-internal-process`).
* **Verificación de Datos Obligatoria:** Cada consulta creada o editada en el Glosario de Métricas DEBE ser probada y verificada contra BigQuery mediante la CLI (con el usuario corporativo autenticado). La tabla con el resultado real verificado por país debe incluirse como bloque comentado al pie del archivo `.sql` y replicarse a Google Drive.
* **Particionado y Costos:** Siempre filtrar por fecha o partición correspondiente para evitar escaneos completos de tablas.
* **Consistencia de Nomenclatura:** Mantener uniformidad en los identificadores de almacén (`whs_id`, `warehouse_name`) y campos estándar entre datamarts.

## 4. Control de Versiones y Sincronización (Git)
* **Sincronización Previa Obligatoria:** Antes de realizar cualquier modificación, creación o edición de archivos en este proyecto, es MANDATORIO descargar y sincronizar la última versión del repositorio remoto (`git pull origin main` o verificar el estado frente al remoto) para garantizar que todo cambio se construya sobre la versión más reciente del código.

## 5. Glosario de Métricas y Sincronización Mandatoria con Google Drive
* **Protocolo de Modificación de Métricas:** Cada vez que se cree, actualice o modifique una métrica del glosario:
  1. **Edición Quirúrgica de Queries:** Actualizar el archivo `.sql` correspondiente en su subcarpeta de capítulo dentro de `PeYa Market/3. Querys SQL/3. Glosario/` (o en `7. Métricas Pendientes/`), manteniendo el encabezado estándar con `DECLARE query_name`, `Métrica Nº`, `Nombre`, `Chapter`, `Query bajada en`, `Sheets Name`, `Sheets Link`, `Owner`, `Slack Link`, `Tablas de origen`, `Tipo`, `Fórmula` y `Definición`.
  2. **Subida Automática a Google Drive:** Es MANDATORIO replicar y subir inmediatamente cualquier archivo `.sql`, `.csv` o `.md` modificado o nuevo a la unidad compartida de Google Drive:
     `G:\Unidades compartidas\Performance Regional - dMarts\3. Conexiones Bases de datos\Glosario\`
  3. **Consistencia en Catálogos:** Actualizar concurrentemente `GLOSARIO_METRICAS_OKRS.md` y `Glosario general de métricas - Performance.csv` tanto en local como en Google Drive.
  4. **Protección de Celdas en CSV:** Prohibido iniciar celdas con el signo `=` (evita errores `#ERROR!` o `#NAME?` al importar en Google Sheets). Los hipervínculos deben registrarse como URLs directas en HTTPS.
  5. **Asignación de Owners y Slack:** Respetar los referentes técnicos asignados (ej. todas las métricas de la familia UTR asignadas a `Juan Pablo Pinori Diaz` con enlace a su chat de Slack `https://deliveryhero.enterprise.slack.com/archives/D093J9QN9CK`).


