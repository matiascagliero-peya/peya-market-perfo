DECLARE query_name STRING DEFAULT '1. OPS Data - Base - OPS (Diario by WHS)';

-- ====================================================================================
-- ops_daily_data (PURE SELECT - JUNIO 2026 ONLY)
-- Compatible con Connected Sheets, Looker Studio, Power BI, y conectores SQL.
-- ====================================================================================

WITH darkstores AS (
  SELECT
    SAFE_CAST(REGEXP_EXTRACT(CAST(dp.warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    MAX(dp.warehouse_name) AS warehouse_name,
    MAX(dp.city.name) AS city_name,
    MAX(LOWER(dp.country.country_code)) AS country_code,
    IF(MAX(dc.country_name_en) = 'Dominican Republic', 'Republica Dominicana', MAX(dc.country_name_en)) AS Country_en
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON LOWER(dp.country.country_code) = LOWER(dc.country_code)
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND SAFE_CAST(REGEXP_EXTRACT(CAST(dp.warehouse_id AS STRING), r'\d+') AS INT64) IS NOT NULL
  GROUP BY 1
),

orders_data_daily AS (
  SELECT DISTINCT
    DATE(fo.registered_date) AS day_date,
    SAFE_CAST(REGEXP_EXTRACT(CAST(par.warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    CAST(fo.order_id AS STRING) AS order_id,
    fo.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON fo.restaurant.id = par.partner_id
  WHERE DATE(fo.registered_date) BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
    AND par.is_darkstore = TRUE
    AND par.warehouse_id IS NOT NULL
    AND SAFE_CAST(REGEXP_EXTRACT(CAST(par.warehouse_id AS STRING), r'\d+') AS INT64) IS NOT NULL
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
  WHERE created_date_local BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
),

seamless_data_daily AS (
  SELECT
    ods.day_date,
    ods.warehouse_id,
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
    ods.warehouse_id,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_data_daily ods
    ON ods.order_id = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) 
        BETWEEN DATETIME(DATE '2026-06-01') AND DATETIME(DATE_ADD(DATE '2026-06-30', INTERVAL 1 DAY))
    AND shift_start_date_utc BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
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
  WHERE DATE(lo.created_date) BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
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

timings_data AS (
  SELECT
    DATE(created_date) AS day_date,
    SAFE_CAST(REGEXP_EXTRACT(CAST(warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    COUNT(DISTINCT order_id) AS total_orders_timings,
    SUM(items) AS picked_items,
    SUM(picking_time_s) AS total_picking_time_s,
    SUM(CASE WHEN SAFE_CAST(is_order_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_order_late_10,
    COUNTIF(actual_dt_min > 35) AS is_dt_35min,
    SUM(CASE WHEN SAFE_CAST(is_vendor_late_10 AS INT64) = 1 THEN 1 ELSE 0 END) AS is_vendor_late,
    COUNTIF(is_vendor_late_10 IS NOT NULL) AS vendor_late_deno,
    COUNT(DISTINCT CASE WHEN (assignment_time_s / 60) > 7 THEN order_id END) AS saturation_orders_over_7min
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
  GROUP BY 1, 2
),

inaccuracy AS (
  SELECT
    i.order_date AS day_date,
    SAFE_CAST(REGEXP_EXTRACT(CAST(i.warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    SUM(i.total_orders)              AS total_orders_inaccuracy,
    SUM(i.total_complaint_orders)    AS inaccuracy_orders,
    SUM(i.food_issue_orders)         AS food_issue_orders,
    SUM(i.wrong_missing_item_orders) AS wrong_missing_item_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy` i
  WHERE i.order_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
  GROUP BY 1, 2
),

productividad_data AS (
  SELECT
    date AS day_date,
    SAFE_CAST(REGEXP_EXTRACT(CAST(warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    SUM(picking_units) AS picking_units,
    SUM(ajuste) AS ajuste_utr,
    SUM(receiving_units) AS receiving_units,
    SUM(picker_working_hours) AS picker_working_hours,
    SUM(manager_working_hours) AS manager_working_hours
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_productividad` proDa
  WHERE date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
  GROUP BY 1, 2
),

original_by_ops_diario AS (
  SELECT
    DATE(date) AS day_date,
    SAFE_CAST(REGEXP_EXTRACT(CAST(warehouse_id AS STRING), r'\d+') AS INT64) AS warehouse_id,
    SUM(orders)         AS Total_orders_ops,
    SUM(partial_orders) AS partial_orders,
    SUM(lost_sessions)  AS lost_sessions
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
  WHERE date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
  GROUP BY 1, 2
),

skeleton AS (
  SELECT day_date, warehouse_id FROM orders_data_agg
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM timings_data
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM inaccuracy
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM productividad_data
  UNION DISTINCT
  SELECT day_date, warehouse_id FROM original_by_ops_diario
)

SELECT
  sk.day_date                                             AS date,
  ds.Country_en                                           AS Country_en,
  ds.city_name                                            AS city_name,
  sk.warehouse_id                                         AS warehouse_id,
  ds.warehouse_name                                       AS warehouse_name,
  COALESCE(od.total_orders_fact_orders, 0)                AS total_orders_fact_orders,
  COALESCE(od.total_orders_all_status, 0)                 AS total_orders_fact_orders_all_status,
  COALESCE(sdd.seamless_delivery, 0)                      AS seamless_orders,
  COALESCE(sdd.rejected_orders, 0)                       AS Fail_Rate,
  COALESCE(sdd.forced_pre_orders, 0)                      AS forced_pre_orders,
  COALESCE(sdd.modified_orders, 0)                        AS modified_orders,
  COALESCE(sdd.session_orders, 0)                         AS session_orders,
  COALESCE(sdd.slow_orders, 0)                            AS slow_orders,
  COALESCE(sdd.order_late, 0)                             AS order_late_ops,
  COALESCE(picko.assignment_time, 0)                      AS assignment_time,
  COALESCE(picko.picking_time, 0)                         AS picking_time,
  COALESCE(dta.non_forced_completed_orders_logistics, 0)  AS non_forced_completed_orders_logistics,
  COALESCE(dta.sum_delivery_time_min, 0)                  AS sum_delivery_time_min,
  COALESCE(dta.logistics_stacked_0, 0)                    AS logistics_stacked_0,
  COALESCE(dta.logistics_stacked_1, 0)                    AS logistics_stacked_1,
  COALESCE(dta.logistics_stacked_2, 0)                    AS logistics_stacked_2,
  COALESCE(dta.logistics_stacked_3_mas, 0)                AS logistics_stacked_3_mas,
  COALESCE(td.total_orders_timings, 0)                    AS Total_orders_timings,
  COALESCE(td.picked_items, 0)                            AS Picked_items,
  COALESCE(td.total_picking_time_s, 0)                    AS total_picking_time_seconds,
  COALESCE(td.is_order_late_10, 0)                        AS order_late_10_count,
  COALESCE(td.is_dt_35min, 0)                             AS dt_35min_count,
  COALESCE(td.is_vendor_late, 0)                          AS vendor_late_count,
  COALESCE(td.vendor_late_deno, 0)                        AS vendor_late_deno,
  COALESCE(inaccuracy.total_orders_inaccuracy, 0)         AS total_orders_inaccuracy,
  COALESCE(inaccuracy.inaccuracy_orders, 0)               AS inaccuracy_orders,
  COALESCE(inaccuracy.food_issue_orders, 0)              AS food_issue_orders,
  COALESCE(inaccuracy.wrong_missing_item_orders, 0)       AS wrong_missing_item_orders,

  -- UTR / Productivity
  COALESCE(proDa.picking_units, 0)                        AS Helper_Total_Units,
  COALESCE(proDa.receiving_units, 0)                      AS receiving_units,
  COALESCE(proDa.ajuste_utr, 0)                             AS ajuste_utr,
  COALESCE(proDa.picker_working_hours, 0)                 AS picker_working_hours,
  COALESCE(proDa.manager_working_hours, 0)                AS manager_working_hours,

  COALESCE(opsd.Total_orders_ops, 0)                      AS Total_orders_ops,
  COALESCE(opsd.partial_orders, 0)                        AS partial_orders,
  COALESCE(opsd.lost_sessions, 0)                           AS lost_sessions,
  COALESCE(td.saturation_orders_over_7min, 0)             AS Saturation_orders_over_7min

FROM skeleton sk
LEFT JOIN darkstores ds               ON sk.warehouse_id = ds.warehouse_id
LEFT JOIN orders_data_agg od          ON sk.day_date = od.day_date          AND sk.warehouse_id = od.warehouse_id
LEFT JOIN seamless_data_daily sdd     ON sk.day_date = sdd.day_date         AND sk.warehouse_id = sdd.warehouse_id
LEFT JOIN pickers_orders picko        ON sk.day_date = picko.day_date       AND sk.warehouse_id = picko.warehouse_id
LEFT JOIN delivery_time_agg dta       ON sk.day_date = dta.day_date         AND sk.warehouse_id = dta.warehouse_id
LEFT JOIN timings_data td             ON sk.day_date = td.day_date          AND sk.warehouse_id = td.warehouse_id
LEFT JOIN inaccuracy                  ON sk.day_date = inaccuracy.day_date  AND sk.warehouse_id = inaccuracy.warehouse_id
LEFT JOIN productividad_data proDa    ON sk.day_date = proDa.day_date       AND sk.warehouse_id = proDa.warehouse_id
LEFT JOIN original_by_ops_diario opsd ON sk.day_date = opsd.day_date        AND sk.warehouse_id = opsd.warehouse_id;