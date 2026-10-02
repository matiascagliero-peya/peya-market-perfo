DECLARE target_month DATE DEFAULT DATE '2026-05-01';

-- CREATE TABLE IF NOT EXISTS `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_ops_seamless`
-- PARTITION BY month_date
-- CLUSTER BY warehouse_id AS (

-- DELETE FROM `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_ops_seamless` WHERE month_date = target_month;
-- INSERT INTO `peya-food-and-groceries.user_eugenio_irigoin.datamart_market_ops_seamless`

WITH 
orders_data_daily AS (
  SELECT DISTINCT
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    par.warehouse_id,
    MAX(par.warehouse_name) OVER (PARTITION BY par.warehouse_id) AS warehouse_name,
    LOWER(fo.country.country_code) AS country_code,
    CAST(fo.order_id AS STRING) AS order_id,
    fo.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON fo.restaurant.id = par.partner_id
  WHERE DATE(fo.registered_date) BETWEEN target_month AND LAST_DAY(target_month)
    AND par.is_darkstore = TRUE
),

orders_data_agg AS (
  SELECT
    month_date,
    warehouse_id,
    MAX(warehouse_name) AS warehouse_name,
    country_code,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders_fact_orders,
    COUNT(DISTINCT order_id) AS total_orders_all_status
  FROM orders_data_daily
  GROUP BY 1, 2, 4
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
  WHERE created_date_local BETWEEN target_month AND LAST_DAY(target_month)
),

seamless_data_agg AS (
  SELECT
    ods.month_date,
    ods.warehouse_id,
    ods.country_code,
    SUM(CASE WHEN so.non_seamless_order = TRUE THEN 0 ELSE 1 END) AS seamless_delivery,
    COUNT(DISTINCT CASE WHEN CAST(so.is_forced_preorder AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_modified_order AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_session_order AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_slow_order AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(so.is_late_order AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS order_late,
    COUNT(DISTINCT CASE WHEN CAST(so.is_rejected_order AS STRING) IN ('1', 'true', 'TRUE') THEN ods.order_id END) AS rejected_orders
  FROM orders_data_daily ods
  LEFT JOIN seamless_orders_new so 
    ON ods.order_id = so.order_id
  GROUP BY 1, 2, 3
),

pickers_orders AS (
  SELECT
    ods.month_date,
    ods.warehouse_id,
    ods.country_code,
    count(distinct order_events.order_id) as orders_assigment_time,
    SUM(order_events.order_available_to_start_duration_sec / 60) AS assignment_time,
    SUM(order_events.order_picking_duration_sec / 60) AS picking_time
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` picko,
    UNNEST(picko.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  INNER JOIN orders_data_daily ods
    ON ods.order_id = CAST(order_events.order_id AS STRING)
  WHERE DATETIME(shifts.shift_start_at_utc, shifts.timezone) BETWEEN target_month AND LAST_DAY(target_month)
    AND shift_start_date_utc BETWEEN target_month AND LAST_DAY(target_month)
    AND ods.order_status = 'CONFIRMED'
  GROUP BY 1, 2, 3
)

SELECT
  od.month_date,
  od.warehouse_id,
  od.warehouse_name,
  dc.country_name_en AS Country_en,
  od.total_orders_fact_orders AS total_orders_fact_orders,
  od.total_orders_all_status AS total_orders_fact_orders_all_status,
  sdd.seamless_delivery AS seamless_orders,
  sdd.rejected_orders,
  sdd.forced_pre_orders,
  sdd.modified_orders,
  sdd.session_orders,
  sdd.slow_orders,
  sdd.order_late AS order_late_ops,
  picko.orders_assigment_time,
  picko.assignment_time,
  picko.picking_time,

  -- Calculated Columns
  SAFE_DIVIDE(sdd.seamless_delivery, od.total_orders_all_status) * 100 AS seamless_rate_pct,
  SAFE_DIVIDE(sdd.rejected_orders, od.total_orders_all_status) * 100 AS fail_rate_pct,
  SAFE_DIVIDE(sdd.forced_pre_orders, od.total_orders_all_status) * 100 AS forced_preorder_pct,
  SAFE_DIVIDE(sdd.modified_orders, od.total_orders_all_status) * 100 AS modified_order_pct,
  SAFE_DIVIDE(sdd.session_orders, od.total_orders_all_status) * 100 AS session_order_pct,
  SAFE_DIVIDE(sdd.slow_orders, od.total_orders_all_status) * 100 AS slow_order_pct,
  SAFE_DIVIDE(sdd.order_late, od.total_orders_all_status) * 100 AS late_order_seamless_pct,
  SAFE_DIVIDE(picko.assignment_time, picko.orders_assigment_time) AS avg_assignment_time_min,
  SAFE_DIVIDE(picko.picking_time, picko.orders_assigment_time) AS avg_picking_time_min

FROM orders_data_agg od
LEFT JOIN seamless_data_agg sdd 
  ON od.month_date = sdd.month_date 
  AND od.warehouse_id = sdd.warehouse_id
  AND od.country_code = sdd.country_code
LEFT JOIN pickers_orders picko 
  ON od.month_date = picko.month_date
  AND od.warehouse_id = picko.warehouse_id
  AND od.country_code = picko.country_code
LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc 
  ON od.country_code = LOWER(dc.country_code)

-- )
