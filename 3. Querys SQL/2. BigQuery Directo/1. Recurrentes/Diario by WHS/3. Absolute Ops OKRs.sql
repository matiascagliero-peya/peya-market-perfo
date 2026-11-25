DECLARE query_name STRING DEFAULT '1. Absolute Operaciones OKRs.sql';

-- ====================================================================================
-- TABLA: absolute_okrs_operaciones (INCREMENTAL · 2025 BACKFILL & RECARGA DINÁMICA)
--   • Destino: `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
--   • Granularidad: (date, warehouse_id)
--   • No existe (o vacía) -> backfill completo desde 2025-01-01.
--   • Existe              -> actualiza únicamente el último mes (mínimo consumo de BigQuery ~7 GB).
-- ====================================================================================

DECLARE fecha_inicio  DATE;
DECLARE to_date       DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
DECLARE reload_from   DATE;
DECLARE table_exists  BOOL DEFAULT FALSE;

-- 1. ¿Existe la tabla en el dataset?
SET table_exists = (
  SELECT COUNT(1) > 0
  FROM `peya-food-and-groceries.automated_tables_reports`.INFORMATION_SCHEMA.TABLES
  WHERE table_name = 'absolute_okrs_operaciones'
);

IF table_exists THEN
  -- Si existe pero está vacía -> tratarla como no existente para hacer backfill completo
  IF (SELECT MAX(date) FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`) IS NULL THEN
    SET table_exists = FALSE;
  END IF;
END IF;

-- 2. Ventana de escaneo optimizada (MÍNIMO CONSUMO DE DATOS):
--   • Sin tabla previa -> carga desde 2025-01-01.
--   • Con tabla previa -> recarga incremental del último mes (~7.16 GB).
IF NOT table_exists THEN
  SET fecha_inicio = DATE '2025-01-01';
ELSE
  SET reload_from = DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH);
  SET fecha_inicio = reload_from;
END IF;

-- ====================================================================================
-- STAGING: cálculo acotado estrictamente a la ventana [fecha_inicio, to_date]
-- ====================================================================================
CREATE TEMP TABLE _staging AS
WITH

darkstores AS (
  SELECT
    LOWER(TRIM(CAST(dp.warehouse_id AS STRING))) AS warehouse_id,
    MAX(dp.warehouse_name)                       AS warehouse_name,
    MAX(dp.city.name)                            AS city_name,
    MAX(LOWER(dp.country.country_code))          AS country_code,
    IF(MAX(dc.country_name_en) = 'Dominican Republic', 'Republica Dominicana', MAX(dc.country_name_en)) AS Country_en
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON LOWER(dp.country.country_code) = LOWER(dc.country_code)
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
  GROUP BY 1
),

-- 1) Fact Orders
orders_data_daily AS (
  SELECT DISTINCT
    DATE(fo.registered_date)                     AS day_date,
    LOWER(TRIM(CAST(par.warehouse_id AS STRING))) AS warehouse_id,
    CAST(fo.order_id AS STRING)                  AS order_id,
    fo.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON fo.restaurant.id = par.partner_id
  WHERE DATE(fo.registered_date) >= fecha_inicio
    AND DATE(fo.registered_date) <= to_date
    AND par.is_darkstore = TRUE
    AND par.warehouse_id IS NOT NULL
),

orders_data_agg AS (
  SELECT
    day_date,
    warehouse_id,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders_fact_orders,
    COUNT(DISTINCT order_id) AS total_orders_all_status
  FROM orders_data_daily
  GROUP BY 1, 2
),

-- 2) Seamless Delivery
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
    AND created_date_local <= to_date
),

seamless_data_daily AS (
  SELECT
    ods.day_date,
    ods.warehouse_id,
    SUM(CASE WHEN so.non_seamless_order = TRUE THEN 0 ELSE 1 END) AS seamless_delivery,
    COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS rejected_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS order_late
  FROM orders_data_daily ods
  LEFT JOIN seamless_orders_new so ON ods.order_id = so.order_id
  GROUP BY 1, 2
),

-- 3) Pickers Orders (Asignación y Picking)
pickers_orders AS (
  SELECT
    ods.day_date,
    ods.warehouse_id,
    COUNT(DISTINCT ods.order_id) AS picker_shift_confirmed_orders,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time,
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN ods.order_id END) AS saturation_orders_over_6min,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_data_daily ods
    ON ods.order_id = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= DATETIME(fecha_inicio)
    AND DATETIME(shifts.shift_start_at_utc, shifts.timezone) <= DATETIME(DATE_ADD(to_date, INTERVAL 1 DAY))
    AND shift_start_date_utc >= fecha_inicio
    AND shift_start_date_utc <= to_date
    AND ods.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 4) Delivery Time & Stacked Deliveries
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
    AND lo.is_preorder IS NOT NULL
  GROUP BY 1
),

delivery_time_agg AS (
  SELECT
    ods.day_date,
    ods.warehouse_id,
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

-- 5) Timings Data (Item picking y DT > 35)
timings_data AS (
  SELECT
    DATE(created_date)                           AS day_date,
    LOWER(TRIM(CAST(warehouse_id AS STRING)))    AS warehouse_id,
    COUNT(DISTINCT order_id)                     AS total_orders_timings,
    SUM(items)                                   AS picked_items,
    SUM(picking_time_s)                          AS total_picking_time_s,
    COUNTIF(actual_dt_min > 35)                  AS is_dt_35min
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= fecha_inicio
    AND created_date <= to_date
  GROUP BY 1, 2
),

-- 6) Logística nivel WHS directo desde fact_logistic_orders (AWT, EPT-APT, Late 10)
logistics_orders AS (
  SELECT
    DATE(l.created_date_local)                   AS day_date,
    LOWER(TRIM(CAST(dp.warehouse_id AS STRING))) AS warehouse_id,
    COUNT(DISTINCT l.peya_order_id)              AS total_orders_logistics,
    SUM(l.timings.avoidable_wait_time)           AS awt_total,
    SUM(l.is_order_late_10)                      AS order_late_10_count,
    SUM(l.is_vendor_late_10)                     AS vendor_late_10_count,
    COUNT(DISTINCT CASE 
        WHEN (l.estimated_prep_time / 60 - l.timings.assumed_actual_preparation_time / 60) > 5 
        THEN l.peya_order_id 
        ELSE NULL 
    END) AS ept_apt_over_5_min_orders
  FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` AS l
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON CAST(l.vendor.vendor_code AS STRING) = CAST(dp.partner_id AS STRING)
   AND dp.is_darkstore = TRUE
  WHERE l.created_date_local >= fecha_inicio
    AND l.created_date_local <= to_date
    AND l.order_cancelled != 1
    AND l.vendor.vertical_type = 'darkstores'
    AND dp.warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 7) Inaccuracy (Reclamos de calidad y producto)
inaccuracy AS (
  SELECT
    i.order_date                                 AS day_date,
    LOWER(TRIM(CAST(i.warehouse_id AS STRING)))  AS warehouse_id,
    SUM(i.total_orders)                          AS total_orders_inaccuracy,
    SUM(i.total_complaint_orders)                AS inaccuracy_orders,
    SUM(i.food_issue_orders)                     AS food_issue_orders,
    SUM(i.wrong_missing_item_orders)             AS wrong_missing_item_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy` i
  WHERE i.order_date >= fecha_inicio
    AND i.order_date <= to_date
  GROUP BY 1, 2
),

-- 8) Productividad y UTR
productividad_data AS (
  SELECT
    date                                         AS day_date,
    LOWER(TRIM(CAST(warehouse_id AS STRING)))    AS warehouse_id,
    SUM(picking_units)                           AS picking_units,
    SUM(receiving_units)                         AS receiving_units,
    SUM(ajuste)                                  AS ajuste_utr,
    SUM(picker_working_hours)                    AS picker_working_hours,
    SUM(received_bags)                           AS received_bags
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad` proDa
  WHERE date >= fecha_inicio
    AND date <= to_date
  GROUP BY 1, 2
),

-- 9) Ops Diario (Parciales y Lost Sessions)
original_by_ops_diario AS (
  SELECT
    DATE(date)                                   AS day_date,
    LOWER(TRIM(CAST(warehouse_id AS STRING)))    AS warehouse_id,
    SUM(orders)                                  AS Total_orders_ops,
    SUM(partial_orders)                          AS partial_orders,
    SUM(lost_sessions)                           AS lost_sessions
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
  WHERE date >= fecha_inicio
    AND date <= to_date
  GROUP BY 1, 2
),

-- Esqueleto dimensional
skeleton AS (
  SELECT day_date, warehouse_id FROM orders_data_agg WHERE warehouse_id IS NOT NULL
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM timings_data WHERE warehouse_id IS NOT NULL
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM inaccuracy WHERE warehouse_id IS NOT NULL
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM productividad_data WHERE warehouse_id IS NOT NULL
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM original_by_ops_diario WHERE warehouse_id IS NOT NULL
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM logistics_orders WHERE warehouse_id IS NOT NULL
)

SELECT
  -- ===== 0) Claves de dimensión =====
  sk.day_date                                             AS date,
  ds.Country_en                                           AS Country_en,
  ds.city_name                                            AS city_name,
  sk.warehouse_id                                         AS warehouse_id,
  ds.warehouse_name                                       AS warehouse_name,

  -- ===== 1) orders_data_agg (od) =====
  COALESCE(od.total_orders_fact_orders, 0)                AS total_orders_fact_orders,
  COALESCE(od.total_orders_all_status, 0)                 AS total_orders_fact_orders_all_status,

  -- ===== 2) seamless_data_daily (sdd) =====
  COALESCE(sdd.seamless_delivery, 0)                      AS seamless_orders,
  COALESCE(sdd.rejected_orders, 0)                        AS Fail_Rate,
  COALESCE(sdd.forced_pre_orders, 0)                      AS forced_pre_orders,
  COALESCE(sdd.modified_orders, 0)                        AS modified_orders,
  COALESCE(sdd.session_orders, 0)                         AS session_orders,
  COALESCE(sdd.slow_orders, 0)                            AS slow_orders,
  COALESCE(sdd.order_late, 0)                             AS order_late_ops,

  -- ===== 3) pickers_orders (picko) =====
  COALESCE(picko.picker_shift_confirmed_orders, 0)        AS picker_shift_confirmed_orders,
  COALESCE(picko.assignment_time, 0)                      AS assignment_time,
  COALESCE(picko.saturation_orders_over_6min, 0)          AS Saturation_orders_over_6min,
  COALESCE(picko.picking_time, 0)                         AS picking_time,

  -- ===== 4) delivery_time_agg (dta) =====
  COALESCE(dta.non_forced_completed_orders_logistics, 0)  AS non_forced_completed_orders_logistics,
  COALESCE(dta.sum_delivery_time_min, 0)                  AS sum_delivery_time_min,
  COALESCE(dta.logistics_stacked_0, 0)                    AS logistics_stacked_0,
  COALESCE(dta.logistics_stacked_1, 0)                    AS logistics_stacked_1,
  COALESCE(dta.logistics_stacked_2, 0)                    AS logistics_stacked_2,
  COALESCE(dta.logistics_stacked_3_mas, 0)                AS logistics_stacked_3_mas,

  -- ===== 5) timings_data (td) =====
  COALESCE(td.total_orders_timings, 0)                    AS Total_orders_timings,
  COALESCE(td.picked_items, 0)                            AS Picked_items,
  COALESCE(td.total_picking_time_s, 0)                    AS total_picking_time_seconds,
  COALESCE(td.is_dt_35min, 0)                             AS dt_35min_count,

  -- ===== 6) logistics_orders (lom) =====
  COALESCE(lom.total_orders_logistics, 0)                 AS total_orders_logistics,
  COALESCE(lom.order_late_10_count, 0)                    AS order_late_10_count,
  COALESCE(lom.vendor_late_10_count, 0)                   AS vendor_late_10_count,
  COALESCE(lom.awt_total, 0)                              AS awt_total,
  COALESCE(lom.ept_apt_over_5_min_orders, 0)              AS ept_apt_over_5_min_orders,

  -- ===== 7) inaccuracy =====
  COALESCE(inaccuracy.total_orders_inaccuracy, 0)         AS total_orders_inaccuracy,
  COALESCE(inaccuracy.inaccuracy_orders, 0)               AS inaccuracy_orders,
  COALESCE(inaccuracy.food_issue_orders, 0)               AS food_issue_orders,
  COALESCE(inaccuracy.wrong_missing_item_orders, 0)       AS wrong_missing_item_orders,

  -- ===== 8) productividad_data (proDa) =====
  COALESCE(proDa.picking_units, 0)                        AS Helper_Total_Units,
  COALESCE(proDa.receiving_units, 0)                      AS receiving_units,
  COALESCE(proDa.ajuste_utr, 0)                           AS ajuste_utr,
  COALESCE(proDa.picker_working_hours, 0)                 AS picker_working_hours,
  CAST(NULL AS FLOAT64)                                   AS manager_working_hours,
  COALESCE(proDa.received_bags, 0)                        AS received_bags,

  -- ===== 9) original_by_ops_diario (opsd) =====
  COALESCE(opsd.Total_orders_ops, 0)                      AS Total_orders_ops,
  COALESCE(opsd.partial_orders, 0)                        AS partial_orders,
  COALESCE(opsd.lost_sessions, 0)                         AS lost_sessions

FROM skeleton sk
LEFT JOIN darkstores ds               ON sk.warehouse_id = ds.warehouse_id
LEFT JOIN orders_data_agg od          ON sk.day_date = od.day_date          AND sk.warehouse_id = od.warehouse_id
LEFT JOIN seamless_data_daily sdd     ON sk.day_date = sdd.day_date         AND sk.warehouse_id = sdd.warehouse_id
LEFT JOIN pickers_orders picko        ON sk.day_date = picko.day_date       AND sk.warehouse_id = picko.warehouse_id
LEFT JOIN delivery_time_agg dta       ON sk.day_date = dta.day_date         AND sk.warehouse_id = dta.warehouse_id
LEFT JOIN timings_data td             ON sk.day_date = td.day_date          AND sk.warehouse_id = td.warehouse_id
LEFT JOIN logistics_orders lom        ON sk.day_date = lom.day_date         AND sk.warehouse_id = lom.warehouse_id
LEFT JOIN inaccuracy                  ON sk.day_date = inaccuracy.day_date  AND sk.warehouse_id = inaccuracy.warehouse_id
LEFT JOIN productividad_data proDa    ON sk.day_date = proDa.day_date       AND sk.warehouse_id = proDa.warehouse_id
LEFT JOIN original_by_ops_diario opsd ON sk.day_date = opsd.day_date        AND sk.warehouse_id = opsd.warehouse_id
WHERE ds.warehouse_name IS NOT NULL;

-- ====================================================================================
-- CARGA / INSERCIÓN (IDÉNTICO A ABSOLUTE SUPPLY Y OPS DAILY DATA)
-- ====================================================================================
IF NOT table_exists THEN
  -- Creación inicial con partición y cluster: backfill completo desde 2025
  CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
  PARTITION BY date
  CLUSTER BY Country_en, warehouse_id AS
  SELECT * FROM _staging
  WHERE date BETWEEN fecha_inicio AND to_date;

ELSE
  -- Carga incremental: borra y reinserta únicamente el último mes
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones`
  WHERE date >= reload_from;

  INSERT INTO `peya-food-and-groceries.automated_tables_reports.absolute_okrs_operaciones` (
    date,
    Country_en,
    city_name,
    warehouse_id,
    warehouse_name,
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
    dt_35min_count,
    total_orders_logistics,
    order_late_10_count,
    vendor_late_10_count,
    awt_total,
    ept_apt_over_5_min_orders,
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
    city_name,
    warehouse_id,
    warehouse_name,
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
    dt_35min_count,
    total_orders_logistics,
    order_late_10_count,
    vendor_late_10_count,
    awt_total,
    ept_apt_over_5_min_orders,
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
