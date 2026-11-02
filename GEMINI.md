# Instrucciones — PeYa Market

## Git
- Ejecutar `git pull origin main` y verificar sincronización con el remoto antes de crear o modificar cualquier archivo.

## BigQuery & SQL
- Iniciar toda consulta con `DECLARE query_name STRING DEFAULT '<nombre_o_identificador_de_la_query>';` en la primera línea.
- Realizar dry-run (`--dry_run=true`) antes de ejecutar e informar los bytes estimados a procesar.
- Reportar tras cada ejecución:
  - Bytes procesados y facturados (`totalBytesBilled` / `totalBytesProcessed`).
  - Cómputo consumido en slots (`totalSlotMs` / slot-segundos / slot-horas).
  - Duración total en segundos (`finalExecutionDurationMs`).
  - Reserva aplicada (`reservation_id`, ej. `peya-internal-process`).
- Probar consultas contra BigQuery vía CLI, adjuntar tabla de resultados comentada al final del `.sql` y replicar a Google Drive.
- Filtrar siempre por fecha o partición para evitar escaneos completos.
- Usar identificadores estándar (`whs_id`, `warehouse_name`).

## Glosario de Métricas y Google Drive
- Al crear o modificar métricas:
  1. Actualizar el archivo `.sql` en `PeYa Market/3. Querys SQL/3. Glosario/` (o `7. Métricas Pendientes/`) con su encabezado estándar (`DECLARE query_name`, `Métrica Nº`, `Nombre`, `Chapter`, `Query bajada en`, `Sheets Name`, `Sheets Link`, `Owner`, `Slack Link`, `Tablas de origen`, `Tipo`, `Fórmula`, `Definición`).
  2. Replicar archivos `.sql`, `.csv` o `.md` modificados a `G:\Unidades compartidas\Performance Regional - dMarts\3. Conexiones Bases de datos\Glosario\`.
  3. Actualizar en paralelo `GLOSARIO_METRICAS_OKRS.md` y `Glosario general de métricas - Performance.csv` (local y Drive).
  4. En archivos CSV: no iniciar celdas con `=` (usar URLs directas en HTTPS para hipervínculos).
  5. Mantener owners y enlaces de Slack correspondientes (ej. métricas UTR a `Juan Pablo Pinori Diaz`).

## Métricas y Reglas de Alertas
- Evaluar variaciones y desvíos operacionales estrictamente en puntos porcentuales (`pp`).
- Comparar volumen y tiempos contra el baseline L3W (promedio del mismo día de las últimas 3 semanas).

## Google Apps Script
- Respetar el límite de 6 minutos de ejecución (procesar por lotes o particionar ejecuciones masivas).
- Separar lógica backend (`.gs`) de vistas (`.html`) usando `HtmlService`.
- No incluir tokens ni credenciales en el código fuente.
