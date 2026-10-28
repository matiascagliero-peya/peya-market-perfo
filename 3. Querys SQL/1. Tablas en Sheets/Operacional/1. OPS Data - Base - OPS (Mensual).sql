DECLARE query_name STRING DEFAULT '1. OPS Data - Base - OPS (Mensual)';

-- Sheets Name: 1. ET - OPS Data - Mensual (1 - OPS Data)
-- Sheets Link: https://docs.google.com/spreadsheets/d/1fM2MeakbnkvynjM6JRX0twsjw2FNt3_RxoNh9GAdQJo


DECLARE fecha_inicio DATE DEFAULT '2025-01-01';
DECLARE to_date      DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH

-- 1) Total orders de fact_orders (nivel orden, base para joins)
orders_data_monthly AS (
  SELECT DISTINCT
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    LOWER(fo.country.country_code) AS country_code,
    CAST(fo.order_id AS STRING) AS order_id,
    fo.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON fo.restaurant.id = par.partner_id
  WHERE DATE(fo.registered_date) >= fecha_inicio
    AND DATE(fo.registered_date) <= to_date
    AND par.is_darkstore = TRUE
),

orders_data_agg AS (
  SELECT
    month_date,
    country_code,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders_fact_orders,
    COUNT(DISTINCT order_id) AS total_orders_all_status
  FROM orders_data_monthly
  GROUP BY 1, 2
),

-- 2) Integración de Seamless
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
  AND created_date_local <= DATE_ADD(to_date, INTERVAL 1 DAY)),

seamless_data_monthly AS (
  SELECT
    ods.month_date,
    ods.country_code,
    COUNT(DISTINCT CASE WHEN so.non_seamless_order IS FALSE OR so.non_seamless_order IS NULL THEN ods.order_id END) AS seamless_delivery,
    COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS order_late,
    COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ods.order_id END) AS rejected_orders
  FROM orders_data_monthly ods
  LEFT JOIN seamless_orders_new so ON ods.order_id = so.order_id
  GROUP BY 1, 2
),

-- 3) Assignment_time / picking_time de qc_picker_shift_orders
pickers_orders AS (
  SELECT
    ods.month_date,
    ods.country_code,
    COUNT(DISTINCT ods.order_id) AS picker_shift_confirmed_orders,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time,
    COUNT(DISTINCT CASE WHEN (order_events.order_available_to_start_duration_sec / 60) > 6 THEN ods.order_id END) AS assignment_time_over_6min
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_data_monthly ods
    ON ods.order_id = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) >= CAST(fecha_inicio AS DATETIME)
    AND shift_start_date_utc >= fecha_inicio
    AND ods.order_status = 'CONFIRMED'
  GROUP BY 1, 2
),

-- 4) Delivery Time y Stacked de fact_logistic_orders (nivel orden)
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

-- Puente: agrega la logística (delivery time / stacked) a nivel mes/país
delivery_time_agg AS (
  SELECT
    ods.month_date,
    ods.country_code,
    COUNT(DISTINCT dt.order_id) AS non_forced_completed_orders_logistics,
    SUM(dt.sum_delivery_time_min) AS sum_delivery_time_min,
    SUM(dt.logistics_stacked_0) AS logistics_stacked_0,
    SUM(dt.logistics_stacked_1) AS logistics_stacked_1,
    SUM(dt.logistics_stacked_2) AS logistics_stacked_2,
    SUM(dt.logistics_stacked_3_mas) AS logistics_stacked_3_mas
  FROM orders_data_monthly ods
  INNER JOIN delivery_time_data dt
    ON ods.order_id = dt.order_id
  GROUP BY 1, 2
),

-- 5) Timings (dmarts_timings)
timings_data AS (
  SELECT
    DATE_TRUNC(DATE(created_date), MONTH) AS month_date,
    LOWER(country_code) AS country_code,
    COUNT(DISTINCT order_id) AS total_orders_timings,
    SUM(items) AS picked_items,
    SUM(picking_time_s) AS total_picking_time_s,
    COUNTIF(actual_dt_min > 35) AS is_dt_35min

  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= fecha_inicio
    AND created_date <= to_date
  GROUP BY 1, 2
),

-- 6) Logística nivel MES directo desde fact_logistic_orders  [NUEVA]
--    (AWT + late flags; sin UNNEST porque son campos order-level)
logistics_orders_monthly AS (
  SELECT
    DATE_TRUNC(DATE(l.created_date_local), MONTH) AS month_date,
    LOWER(l.country_code)                   AS country_code,
    COUNT(DISTINCT l.peya_order_id)         AS total_orders_logistics,
    SUM(l.timings.avoidable_wait_time)      AS awt_total,
    SUM(l.is_order_late_10)                 AS order_late_10_count,
    SUM(l.is_vendor_late_10)                AS vendor_late_10_count,
    COUNT(DISTINCT CASE 
        WHEN (l.estimated_prep_time / 60 - l.timings.assumed_actual_preparation_time / 60) > 5 
        THEN l.peya_order_id 
        ELSE NULL 
    END) AS ept_apt_over_5_min_orders
  FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders` AS l
  WHERE l.created_date_local >= fecha_inicio
    AND l.created_date_local <= to_date
    AND l.order_cancelled != 1
    AND l.vendor.vertical_type = 'darkstores'
  GROUP BY 1, 2
),

-- 7) Inaccuracy
inaccuracy AS (
  SELECT
    DATE_TRUNC(i.order_date, MONTH) AS month_date,
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
    AND i.order_date <= to_date
  GROUP BY 1, 2
),

-- 8) Productividad
productividad_data AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS month_date,
    LOWER(country_name) AS country_code,

    SUM(picking_units) AS picking_units,
    SUM(receiving_units) AS receiving_units,
    SUM(received_bags) AS received_bags,

    SUM(ajuste) AS ajuste_UTR,

    SUM(picker_working_hours) AS picker_working_hours,
    SUM(manager_working_hours) AS manager_working_hours

  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad`
  WHERE date >= fecha_inicio
    AND date <= to_date
  GROUP BY 1, 2
),

-- 9) OPS daily (dmarts_ops_daily_new)
original_by_ops_diario AS (
  SELECT
    DATE_TRUNC(DATE(date), MONTH) AS month_date,
    LOWER(country_name) AS country_code,
    SUM(orders)         AS Total_orders_ops,
    SUM(partial_orders) AS partial_orders,
    SUM(lost_sessions)  AS lost_sessions
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
  WHERE date >= fecha_inicio
    AND date <= to_date
  GROUP BY 1, 2
)

-- SELECT FINAL (ordenado según aparición de cada CTE)
SELECT
  -- ===== 0) Claves =====
  od.month_date                               AS date,
  IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS Country_en,

  -- ===== 1) orders_data_agg (od) =====
  od.total_orders_fact_orders                 AS total_orders_fact_orders,
  od.total_orders_all_status                  AS total_orders_fact_orders_all_status,

  -- ===== 2) seamless_data_monthly (sdm) =====
  sdm.seamless_delivery                       AS seamless_orders,
  sdm.rejected_orders                         AS Fail_Rate,
  sdm.forced_pre_orders                       AS forced_pre_orders,
  sdm.modified_orders                         AS modified_orders,
  sdm.session_orders                          AS session_orders,
  sdm.slow_orders                             AS slow_orders,
  sdm.order_late                              AS order_late_ops,

  -- ===== 3) pickers_orders (picko) =====
  picko.picker_shift_confirmed_orders         AS picker_shift_confirmed_orders,
  picko.assignment_time                       AS assignment_time,
  picko.assignment_time_over_6min             AS assignment_time_over_6min,
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
  td.is_dt_35min                              AS dt_35min_count,

  -- ===== 6) logistics_orders_monthly (lom)  [NUEVA] =====
  lom.total_orders_logistics                  AS total_orders_logistics,
  lom.order_late_10_count                     AS order_late_10_count,
  lom.vendor_late_10_count                    AS vendor_late_10_count,
  lom.awt_total                               AS awt_total,
  lom.ept_apt_over_5_min_orders               AS ept_apt_over_5_min_orders,

  -- ===== 7) inaccuracy =====
  inaccuracy.total_orders_inaccuracy          AS total_orders_inaccuracy,
  inaccuracy.inaccuracy_orders                AS inaccuracy_orders,
  inaccuracy.food_issue_orders                AS food_issue_orders,
  inaccuracy.wrong_missing_item_orders        AS wrong_missing_item_orders,

  -- ===== 8) productividad_data (proDa) =====
  proDa.picking_units                         AS Helper_Total_Units,
  proDa.receiving_units                       AS receiving_units,
  proDa.ajuste_UTR                            AS ajuste_UTR,
  proDa.picker_working_hours                  AS picker_working_hours,
  proDa.manager_working_hours                 AS manager_working_hours,
  proDa.received_bags                         AS received_bags,

  -- ===== 9) original_by_ops_diario (opsd) =====
  opsd.Total_orders_ops                       AS Total_orders_ops,
  opsd.partial_orders                         AS partial_orders,
  opsd.lost_sessions                          AS lost_sessions

FROM orders_data_agg od
LEFT JOIN seamless_data_monthly sdm      ON od.month_date = sdm.month_date        AND od.country_code = sdm.country_code
LEFT JOIN pickers_orders picko           ON od.month_date = picko.month_date      AND od.country_code = picko.country_code
LEFT JOIN delivery_time_agg dta          ON od.month_date = dta.month_date        AND od.country_code = dta.country_code
LEFT JOIN timings_data td                ON od.month_date = td.month_date         AND od.country_code = td.country_code
LEFT JOIN logistics_orders_monthly lom   ON od.month_date = lom.month_date        AND od.country_code = lom.country_code
LEFT JOIN inaccuracy                     ON od.month_date = inaccuracy.month_date AND od.country_code = inaccuracy.country_code
LEFT JOIN productividad_data proDa       ON od.month_date = proDa.month_date      AND od.country_code = proDa.country_code
LEFT JOIN original_by_ops_diario opsd    ON od.month_date = opsd.month_date       AND od.country_code = opsd.country_code
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc ON od.country_code = LOWER(dc.country_code)
ORDER BY date DESC, Country_en ASC;