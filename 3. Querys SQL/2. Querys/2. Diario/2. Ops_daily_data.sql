DECLARE query_name STRING DEFAULT '2. Ops_daily_data';

-- ====================================================================================
-- ops_daily_data  (INCREMENTAL · 2025 BACKFILL & LAST MONTH UPDATE)
--   • No existe (o vacía) -> backfill: desde el año 2025 (2025-01-01).
--   • Existe              -> actualiza únicamente el último mes.
-- ====================================================================================

-- Variable inútil para identificar la query
DECLARE `2. Ops_daily_data` STRING DEFAULT NULL;

DECLARE fecha_inicio  DATE;
DECLARE to_date       DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
DECLARE reload_from   DATE;
DECLARE table_exists  BOOL DEFAULT FALSE;

-- ¿Existe la tabla?
SET table_exists = (
  SELECT COUNT(1) > 0
  FROM `peya-food-and-groceries.automated_tables_reports`.INFORMATION_SCHEMA.TABLES
  WHERE table_name = 'ops_daily_data'
);

IF table_exists THEN
  -- Si existe pero está vacía -> tratarla como si no existiera para hacer backfill completo
  IF (SELECT MAX(date) FROM `peya-food-and-groceries.automated_tables_reports.ops_daily_data`) IS NULL THEN
    SET table_exists = FALSE;
  END IF;
END IF;

-- Configuración de fechas:
--   • Si NO existe (o está vacía) -> cargamos el histórico completo desde 2025.
--   • Si SÍ existe -> actualizamos solo el último mes (reload_from = 1 mes atrás, fecha_inicio = reload_from para optimizar staging).
IF NOT table_exists THEN
  SET fecha_inicio = DATE '2025-01-01';
ELSE
  SET reload_from = DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH);
  SET fecha_inicio = reload_from;
END IF;

-- ====================================================================================
-- STAGING: se calcula una sola vez (CY 10 semanas)
-- ====================================================================================
CREATE TEMP TABLE _staging AS
WITH

orders_data_daily AS (
  SELECT DISTINCT
    DATE(fo.registered_date) AS day_date,
    LOWER(fo.country.country_code) AS country_code,
    CAST(fo.order_id AS STRING) AS order_id,
    fo.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON fo.restaurant.id = par.partner_id
  WHERE DATE(fo.registered_date) >= fecha_inicio
    AND par.is_darkstore = TRUE
),

orders_data_agg AS (
  SELECT
    day_date,
    country_code,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders_fact_orders,
    COUNT(DISTINCT order_id) AS total_orders_all_status
  FROM orders_data_daily
  GROUP BY 1, 2
),

seamless_orders_new AS (
  SELECT
    CAST(platform_order_code AS STRING) AS order_id,
    non_seamless_order,
    is_slow_order,
    is_modified_order,
    is_rejected_order,
    is_session_order,
    is_forced_preorder,
    is_late_order
  FROM `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
  WHERE created_date_local >= fecha_inicio
),

seamless_data_daily AS (
  SELECT
    ods.day_date,
    ods.country_code,
    SUM(CASE WHEN so.non_seamless_order = TRUE THEN 0 ELSE 1 END) AS seamless_delivery,
    COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS order_late,
    COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS rejected_orders
  FROM orders_data_daily ods
  LEFT JOIN seamless_orders_new so ON ods.order_id = so.order_id
  GROUP BY 1, 2
),

pickers_orders AS (
  SELECT
    ods.day_date,
    ods.country_code,
    COUNT(DISTINCT ods.order_id) AS picker_shift_confirmed_orders,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time,
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN ods.order_id END) AS saturation_orders_over_6min
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_data_daily ods
    ON ods.order_id = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= fecha_inicio
    AND shift_start_date_utc >= fecha_inicio
    AND ods.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

delivery_time_data AS (
  SELECT
    CAST(lo.peya_order_id AS STRING) AS order_id,
    COALESCE(MAX(lo.timings.actual_delivery_time), 0) / 60 AS sum_delivery_time_min,
    COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' THEN del.delivery_id END) AS deliveries_completed,
    COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND COALESCE(del.stacked_deliveries, 0) = 0 THEN del.delivery_id END) AS logistics_stacked_0,
    COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries = 1 THEN del.delivery_id END) AS logistics_stacked_1,
    COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries = 2 THEN del.delivery_id END) AS logistics_stacked_2,
    COUNT(DISTINCT CASE WHEN UPPER(del.delivery_status) = 'COMPLETED' AND del.stacked_deliveries >= 3 THEN del.delivery_id END) AS logistics_stacked_3_mas
  FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` AS lo
  CROSS JOIN UNNEST(lo.deliveries) del
  WHERE DATE(lo.created_date) >= fecha_inicio
    AND DATE(lo.created_date) <= to_date
    AND UPPER(lo.order_status) = 'COMPLETED'
    AND lo.is_preorder = FALSE
    AND lo.is_preorder is not null
  GROUP BY 1
),

delivery_time_agg AS (
  SELECT
    ods.day_date,
    ods.country_code,
    COUNT(DISTINCT dt.order_id) AS non_forced_completed_orders_logistics,
    SUM(dt.sum_delivery_time_min) AS sum_delivery_time_min,
    SUM(dt.logistics_stacked_0) AS logistics_stacked_0,
    SUM(dt.logistics_stacked_1) AS logistics_stacked_1,
    SUM(dt.logistics_stacked_2) AS logistics_stacked_2,
    SUM(dt.logistics_stacked_3_mas) AS logistics_stacked_3_mas
  FROM orders_data_daily ods
  INNER JOIN delivery_time_data dt
    ON ods.order_id = dt.order_id
  GROUP BY 1, 2
),

timings_data AS (
  SELECT
    DATE(created_date) AS day_date,
    LOWER(country_code) AS country_code,
    COUNT(DISTINCT order_id) AS total_orders_timings,
    SUM(items) AS picked_items,
    SUM(picking_time_s) AS total_picking_time_s,
    SUM(CASE WHEN SAFE_CAST(is_order_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_order_late_10,
    COUNTIF(actual_dt_min > 35) AS is_dt_35min,
    SUM(CASE WHEN SAFE_CAST(is_vendor_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_vendor_late,
    COUNTIF(is_vendor_late_10 IS NOT NULL) AS vendor_late_deno
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= fecha_inicio
  GROUP BY 1, 2
),

inaccuracy AS (
  SELECT
    i.order_date         AS day_date,
    LOWER(dc.country_code) AS country_code,
    SUM(i.total_orders)              AS total_orders_inaccuracy,
    SUM(i.total_complaint_orders)    AS inaccuracy_orders,
    SUM(i.food_issue_orders)         AS food_issue_orders,
    SUM(i.wrong_missing_item_orders) AS wrong_missing_item_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy` i
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON CASE i.country
         WHEN 'Perú'                 THEN 'Peru'
         WHEN 'Panamá'               THEN 'Panama'
         WHEN 'República Dominicana' THEN 'Dominican Republic'
         ELSE i.country
       END = dc.country_name_en
  WHERE i.order_date >= fecha_inicio
  GROUP BY 1, 2
),

productividad_data AS (
  SELECT
    date AS fecha,
    LOWER(country_name) AS country_code,

    SUM(picking_units) AS picking_units,
    SUM(receiving_units) AS receiving_units,
    SUM(received_bags) AS received_bags,
    
    SUM(ajuste) AS ajuste_utr,

    SUM(picker_working_hours) AS picker_working_hours,
    SUM(manager_working_hours) AS manager_working_hours
    
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad` proDa
  WHERE date >= fecha_inicio  
  GROUP BY 1, 2
),

original_by_ops_diario AS (
  SELECT
    DATE(date)          AS day_date,
    LOWER(country_name) AS country_code,
    SUM(orders)         AS Total_orders_ops,
    SUM(partial_orders) AS partial_orders,
    SUM(lost_sessions)  AS lost_sessions
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
  WHERE date >= fecha_inicio
  GROUP BY 1, 2
)

SELECT
  -- ===== 0) Claves =====
  od.day_date                                 AS date,
  IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS Country_en,

  -- ===== 1) orders_data_agg (od) =====
  od.total_orders_fact_orders                 AS total_orders_fact_orders,
  od.total_orders_all_status                  AS total_orders_fact_orders_all_status,

  -- ===== 2) seamless_data_daily (sdd) =====
  sdd.seamless_delivery                       AS seamless_orders,
  sdd.rejected_orders                         AS Fail_Rate,
  sdd.forced_pre_orders                       AS forced_pre_orders,
  sdd.modified_orders                         AS modified_orders,
  sdd.session_orders                          AS session_orders,
  sdd.slow_orders                             AS slow_orders,
  sdd.order_late                              AS order_late_ops,

  -- ===== 3) pickers_orders (picko) =====
  picko.picker_shift_confirmed_orders         AS picker_shift_confirmed_orders,
  picko.assignment_time                       AS assignment_time,
  picko.saturation_orders_over_6min           AS Saturation_orders_over_6min,
  picko.picking_time                          AS picking_time,

  -- ===== 4) delivery_time_agg (dta) =====
  COALESCE(dta.non_forced_completed_orders_logistics, 0) AS non_forced_completed_orders_logistics,
  dta.sum_delivery_time_min                   AS sum_delivery_time_min,
  dta.logistics_stacked_0                     AS logistics_stacked_0,
  dta.logistics_stacked_1                     AS logistics_stacked_1,
  dta.logistics_stacked_2                     AS logistics_stacked_2,
  dta.logistics_stacked_3_mas                 AS logistics_stacked_3_mas,

  -- ===== 5) timings_data (td) =====
  td.total_orders_timings                     AS Total_orders_timings,
  td.picked_items                             AS Picked_items,
  td.total_picking_time_s                     AS total_picking_time_seconds,
  td.is_order_late_10                         AS order_late_10_count,
  td.is_dt_35min                              AS dt_35min_count,
  td.is_vendor_late                           AS vendor_late_count,
  td.vendor_late_deno                         AS vendor_late_deno,

  -- ===== 7) inaccuracy =====
  inaccuracy.total_orders_inaccuracy          AS total_orders_inaccuracy,
  inaccuracy.inaccuracy_orders                AS inaccuracy_orders,
  inaccuracy.food_issue_orders                AS food_issue_orders,
  inaccuracy.wrong_missing_item_orders        AS wrong_missing_item_orders,

  -- ===== 8) productividad_data (proDa) =====
  proDa.picking_units                         AS Helper_Total_Units,
  proDa.receiving_units                       AS receiving_units,
  proDa.ajuste_utr                            AS ajuste_utr,
  proDa.picker_working_hours                  AS picker_working_hours,
  proDa.manager_working_hours                 AS manager_working_hours,
  proDa.received_bags                         AS received_bags,

  -- ===== 9) original_by_ops_diario (opsd) =====
  opsd.Total_orders_ops                       AS Total_orders_ops,
  opsd.partial_orders                         AS partial_orders,
  opsd.lost_sessions                          AS lost_sessions

FROM orders_data_agg od
LEFT JOIN seamless_data_daily sdd     ON od.day_date = sdd.day_date        AND od.country_code = sdd.country_code
LEFT JOIN pickers_orders picko        ON od.day_date = picko.day_date      AND od.country_code = picko.country_code
LEFT JOIN delivery_time_agg dta       ON od.day_date = dta.day_date        AND od.country_code = dta.country_code
LEFT JOIN timings_data td             ON od.day_date = td.day_date         AND od.country_code = td.country_code
LEFT JOIN inaccuracy                  ON od.day_date = inaccuracy.day_date AND od.country_code = inaccuracy.country_code
LEFT JOIN productividad_data proDa    ON od.day_date = proDa.fecha         AND od.country_code = proDa.country_code
LEFT JOIN original_by_ops_diario opsd ON od.day_date = opsd.day_date       AND od.country_code = opsd.country_code
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON od.country_code = LOWER(dc.country_code);

-- ====================================================================================
-- CARGA
-- ====================================================================================
IF NOT table_exists THEN
  -- Tabla nueva (o vacía): backfill completo desde 2025
  CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.ops_daily_data`
  PARTITION BY date
  CLUSTER BY Country_en AS
  SELECT * FROM _staging
  WHERE date BETWEEN fecha_inicio AND to_date;

ELSE
  -- Incremental: borra el último mes y reinserta
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.ops_daily_data`
  WHERE date >= reload_from;

  INSERT INTO `peya-food-and-groceries.automated_tables_reports.ops_daily_data` (
    date,
    Country_en,
    total_orders_fact_orders,
    total_orders_fact_orders_all_status,
    seamless_orders,
    Fail_Rate,
    forced_pre_orders,
    modified_orders,
    session_orders,
    slow_orders,
    order_late_ops,
    picker_shift_confirmed_orders,
    assignment_time,
    Saturation_orders_over_6min,
    picking_time,
    non_forced_completed_orders_logistics,
    sum_delivery_time_min,
    logistics_stacked_0,
    logistics_stacked_1,
    logistics_stacked_2,
    logistics_stacked_3_mas,
    Total_orders_timings,
    Picked_items,
    total_picking_time_seconds,
    order_late_10_count,
    dt_35min_count,
    vendor_late_count,
    vendor_late_deno,
    total_orders_inaccuracy,
    inaccuracy_orders,
    food_issue_orders,
    wrong_missing_item_orders,
    Helper_Total_Units,
    receiving_units,
    ajuste_utr,
    picker_working_hours,
    manager_working_hours,
    received_bags,
    Total_orders_ops,
    partial_orders,
    lost_sessions
  )
  SELECT
    date,
    Country_en,
    total_orders_fact_orders,
    total_orders_fact_orders_all_status,
    seamless_orders,
    Fail_Rate,
    forced_pre_orders,
    modified_orders,
    session_orders,
    slow_orders,
    order_late_ops,
    picker_shift_confirmed_orders,
    assignment_time,
    Saturation_orders_over_6min,
    picking_time,
    non_forced_completed_orders_logistics,
    sum_delivery_time_min,
    logistics_stacked_0,
    logistics_stacked_1,
    logistics_stacked_2,
    logistics_stacked_3_mas,
    Total_orders_timings,
    Picked_items,
    total_picking_time_seconds,
    order_late_10_count,
    dt_35min_count,
    vendor_late_count,
    vendor_late_deno,
    total_orders_inaccuracy,
    inaccuracy_orders,
    food_issue_orders,
    wrong_missing_item_orders,
    Helper_Total_Units,
    receiving_units,
    ajuste_utr,
    picker_working_hours,
    manager_working_hours,
    received_bags,
    Total_orders_ops,
    partial_orders,
    lost_sessions
  FROM _staging
  WHERE date BETWEEN reload_from AND to_date;

END IF;