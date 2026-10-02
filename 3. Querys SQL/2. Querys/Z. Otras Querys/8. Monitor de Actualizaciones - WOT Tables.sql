DECLARE query_name STRING DEFAULT '8. Monitor de Actualizaciones - WOT Tables.sql';

-- ====================================================================================
-- PROPÓSITO: Monitorear la última fecha/hora de actualización, frescura y tamaño
--            de todas las tablas que componen el cálculo de 'wot_hour_by_whs'.
--
-- COSTO DE ESCANEO: 0 BYTES (Consulta vistas de metadatos __TABLES__ de BigQuery).
-- ====================================================================================

WITH metadata_tablas AS (
  -- 1. Tablas de dm_dmarts (peya-datamarts-pro)
  SELECT
    'peya-datamarts-pro' AS proyecto,
    'dm_dmarts'          AS dataset,
    table_id             AS tabla,
    TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion_utc,
    row_count,
    ROUND(size_bytes / POW(1024, 3), 2)  AS tamano_gb
  FROM `peya-datamarts-pro.dm_dmarts.__TABLES__`
  WHERE table_id IN ('customer_orders_sku_level', 'dim_partner_darkstore')

  UNION ALL

  -- 2. Tablas de sesiones Perseus (peya-bi-tools-pro)
  SELECT
    'peya-bi-tools-pro'  AS proyecto,
    'il_sessions'        AS dataset,
    table_id             AS tabla,
    TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion_utc,
    row_count,
    ROUND(size_bytes / POW(1024, 3), 2)  AS tamano_gb
  FROM `peya-bi-tools-pro.il_sessions.__TABLES__`
  WHERE table_id IN ('fact_perseus_sessions', 'perseus_fact_sessions_funnel_by_verticals')

  UNION ALL

  -- 3. Double Ya (peya-bi-tools-pro)
  SELECT
    'peya-bi-tools-pro'  AS proyecto,
    'il_qcommerce'       AS dataset,
    table_id             AS tabla,
    TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion_utc,
    row_count,
    ROUND(size_bytes / POW(1024, 3), 2)  AS tamano_gb
  FROM `peya-bi-tools-pro.il_qcommerce.__TABLES__`
  WHERE table_id IN ('fact_sessions_double_ya')

  UNION ALL

  -- 4. Tablas core de partner y órdenes (peya-bi-tools-pro)
  SELECT
    'peya-bi-tools-pro'  AS proyecto,
    'il_core'            AS dataset,
    table_id             AS tabla,
    TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion_utc,
    row_count,
    ROUND(size_bytes / POW(1024, 3), 2)  AS tamano_gb
  FROM `peya-bi-tools-pro.il_core.__TABLES__`
  WHERE table_id IN ('agg_fact_partner_times', 'fact_orders', 'dim_partner', 'dim_historical_partners')

  UNION ALL

  -- 5. Tablas destino del modelo WOT (peya-food-and-groceries)
  SELECT
    'peya-food-and-groceries' AS proyecto,
    'automated_tables_reports' AS dataset,
    table_id                  AS tabla,
    TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion_utc,
    row_count,
    ROUND(size_bytes / POW(1024, 3), 2)  AS tamano_gb
  FROM `peya-food-and-groceries.automated_tables_reports.__TABLES__`
  WHERE table_id IN ('wot_hour_by_whs', 'wot_weekly_by_country')
)

SELECT
  CONCAT(proyecto, '.', dataset, '.', tabla) AS tabla_completa,

  -- Rol dentro del modelo de cálculo
  CASE tabla
    WHEN 'agg_fact_partner_times'                  THEN 'Horarios programados y minutos cerrados por partner'
    WHEN 'fact_perseus_sessions'                   THEN 'Sesiones Perseus para ponderación de tráfico horario'
    WHEN 'perseus_fact_sessions_funnel_by_verticals' THEN 'Funnel vertical para filtrar sesiones de Market'
    WHEN 'fact_sessions_double_ya'                 THEN 'Filtro para excluir sesiones Double Ya'
    WHEN 'customer_orders_sku_level'               THEN 'Identificación de Partner Principal (Top Vendor) por WHS'
    WHEN 'fact_orders'                             THEN 'Fechas operativas reales (apertura / última orden)'
    WHEN 'dim_historical_partners'                 THEN 'Snapshot histórico de estado Online y último día activo'
    WHEN 'dim_partner'                             THEN 'Dimensión partner (nombre, país, ciudad, warehouse_id)'
    WHEN 'dim_partner_darkstore'                   THEN 'Filtro de confirmación de darkstores'
    WHEN 'wot_hour_by_whs'                         THEN '[DESTINO] Tabla intermedia horaria por WHS'
    WHEN 'wot_weekly_by_country'                   THEN '[DESTINO] Tabla consolidada semanal País y LATAM'
    ELSE 'Fuente auxiliar'
  END AS rol_en_modelo,

  -- Fecha y hora local (GMT-3)
  DATETIME(ultima_modificacion_utc, "America/Argentina/Buenos_Aires") AS ultima_actualizacion_local,

  -- Tiempo transcurrido desde la última escritura
  CONCAT(
    CAST(DIV(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), ultima_modificacion_utc, MINUTE), 60) AS STRING), 'h ',
    CAST(MOD(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), ultima_modificacion_utc, MINUTE), 60) AS STRING), 'm'
  ) AS hace_cuanto,

  -- Frecuencia típica de ingesta
  CASE tabla
    WHEN 'fact_perseus_sessions'                   THEN 'Cada 1 a 3 horas (Micro-batch)'
    WHEN 'perseus_fact_sessions_funnel_by_verticals' THEN 'Cada 1 a 3 horas'
    WHEN 'fact_sessions_double_ya'                 THEN 'Diaria (madrugada)'
    WHEN 'agg_fact_partner_times'                  THEN 'Diaria (madrugada ~05:00-08:00 UTC)'
    WHEN 'customer_orders_sku_level'               THEN 'Diaria (madrugada)'
    WHEN 'fact_orders'                             THEN 'Streaming / Intradiario (~15-30 min)'
    WHEN 'dim_historical_partners'                 THEN 'Diaria (snapshot nocturno)'
    WHEN 'dim_partner'                             THEN 'Diaria / Frecuente'
    WHEN 'dim_partner_darkstore'                   THEN 'Diaria'
    ELSE 'Automatizada'
  END AS frecuencia_habitual,

  row_count AS cantidad_filas,
  tamano_gb AS tamano_gb

FROM metadata_tablas
ORDER BY ultima_modificacion_utc DESC;
