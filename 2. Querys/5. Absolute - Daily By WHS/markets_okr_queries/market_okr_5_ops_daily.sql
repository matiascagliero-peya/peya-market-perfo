DECLARE query_name STRING DEFAULT 'market_okr_5_ops_daily';

-- ============================================================
-- markets_ops_daily
-- Responsable: Logistics + Ops
-- Grain: fecha_completa + country_name + warehouse_id
-- Incluye: CPO, Seamless, Late/Slow orders, Delivery/Assignment time (sum+count para promediar en vista)
-- ============================================================

DECLARE table_exists BOOL;
SET table_exists = EXISTS (
  SELECT 1
  FROM `peya-food-and-groceries.automated_tables_reports.markets_ops_daily`
);

DECLARE from_date DATE;
DECLARE to_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
IF NOT table_exists THEN
  SET from_date = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 10 WEEK), WEEK(MONDAY));
ELSE
  SET from_date = DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
END IF;

-- CREACIÓN DE TABLA
IF NOT table_exists THEN
  CREATE TABLE `peya-food-and-groceries.automated_tables_reports.markets_ops_daily` (
    fecha_completa                  DATE,
    country_name                    STRING,
    warehouse_id                    STRING,
    warehouse_name                  STRING,
    -- CPO (dmarts es warehouse-level; platform/courier son country-level repetidos por warehouse)
    dmarts_cpo                      FLOAT64,
    dmart_orders_cpo                INT64,
    platform_cpo                    FLOAT64,
    courier_cpo                     FLOAT64,
    platform_orders_excl_dmarts     INT64,
    -- Seamless
    seamless_numerador              INT64,
    total_seamless_base_orders      INT64,
    -- Fulfillment
    late_orders                     INT64,
    slow_orders                     INT64,
    session_orders                  INT64,
    forced_preorders                INT64,
    modified_orders                 INT64,
    -- Delivery time (guardamos sum+count para calcular promedio en la vista)
    delivery_time_sum               FLOAT64,
    delivery_time_order_count       INT64,
    -- Assignment time
    assignment_time_sum             FLOAT64,
    assignment_time_order_count     INT64
  )
  PARTITION BY fecha_completa
  CLUSTER BY country_name, warehouse_id;
END IF;

-- LIMPIEZA INCREMENTAL
IF table_exists THEN
  DELETE FROM `peya-food-and-groceries.automated_tables_reports.markets_ops_daily`
  WHERE fecha_completa BETWEEN from_date AND to_date;
END IF;

-- INSERCIÓN
INSERT INTO `peya-food-and-groceries.automated_tables_reports.markets_ops_daily`

WITH

partners AS (
  SELECT p.country_id, p.partner_id, pd.warehouse_id, pd.warehouse_name, TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` pd ON p.partner_id = pd.partner_id
),

cost_per_order_raw AS (
  SELECT
    DATE(registered_date) AS day,
    country_id,
    partner.partner_id,
    CASE
      WHEN partner.vertical_group = 'D-Mart'                           THEN 'D-Mart'
      WHEN partner.vertical_group IN ('Courier Business', 'Courier')   THEN 'Courier'
      ELSE 'Platform'
    END AS vertical,
    delivery.delivery_type,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS confirmed_orders,
    SUM(rider_cost.rider_cost / monthly_rate_eu)                            AS rider_cost_eur
  FROM `peya-datamarts-pro.dm_order_profitability.fact_order_profitability`
  WHERE registered_date BETWEEN from_date AND to_date
  GROUP BY 1, 2, 3, 4, 5
),

cost_per_order_country AS (
  SELECT day, country_id,
    SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS platform_cpo,
    SUM(CASE WHEN vertical = 'Courier'  AND delivery_type = 'OD' THEN SAFE_DIVIDE(rider_cost_eur, confirmed_orders) END) AS courier_cpo,
    SUM(CASE WHEN vertical = 'Platform' AND delivery_type = 'OD' THEN confirmed_orders END)                               AS platform_orders_excl_dmarts
  FROM cost_per_order_raw
  GROUP BY 1, 2
),

cost_per_order_warehouse AS (
  SELECT r.day, r.country_id, p.warehouse_id,
    SUM(CASE WHEN r.vertical = 'D-Mart' AND r.delivery_type = 'OD' THEN SAFE_DIVIDE(r.rider_cost_eur, r.confirmed_orders) END) AS dmarts_cpo,
    SUM(CASE WHEN r.vertical = 'D-Mart' AND r.delivery_type = 'OD' THEN r.confirmed_orders END)                                 AS dmart_orders_cpo
  FROM cost_per_order_raw r
  INNER JOIN partners p ON CAST(r.partner_id AS STRING) = CAST(p.partner_id AS STRING)
  GROUP BY 1, 2, 3
),

seamless_metrics AS (
  SELECT platform_order_code AS order_id,
    MAX(CASE WHEN non_seamless_order = TRUE THEN 0 ELSE 1 END)                                                AS is_seamless,
    MAX(CASE WHEN CAST(is_late_order      AS STRING) IN ('1','true','TRUE') THEN 1 ELSE 0 END)                AS is_late_order,
    MAX(CASE WHEN CAST(is_slow_order      AS STRING) IN ('1','true','TRUE') THEN 1 ELSE 0 END)                AS is_slow_order,
    MAX(CASE WHEN CAST(is_session_order   AS STRING) IN ('1','true','TRUE') THEN 1 ELSE 0 END)                AS is_session_order,
    MAX(CASE WHEN CAST(is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN 1 ELSE 0 END)                AS is_forced_preorder,
    MAX(CASE WHEN CAST(is_modified_order  AS STRING) IN ('1','true','TRUE') THEN 1 ELSE 0 END)                AS is_modified_order,
    MAX(actual_delivery_time)                                                                                  AS actual_delivery_time
  FROM `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level`
  WHERE created_date_local BETWEEN from_date AND to_date
  GROUP BY 1
),

pickers_metrics AS (
  SELECT CAST(order_events.order_id AS STRING) AS order_id,
    SUM(SAFE_DIVIDE(order_events.order_available_to_start_duration_sec, 60)) AS assignment_time_min
  FROM `peya-data-origins-pro.cl_dmarts.qc_picker_shift_orders` p,
    UNNEST(p.shifts) AS shifts,
    UNNEST(shifts.order_events) AS order_events
  WHERE shift_start_date_utc BETWEEN from_date AND to_date
  GROUP BY 1
),

orders AS (
  SELECT
    o.order_id,
    o.registered_date   AS order_placed_local,
    o.country.country_name,
    o.country_id,
    o.restaurant.id     AS restaurant_id,
    o.order_status
  FROM `peya-bi-tools-pro.il_core.fact_orders` o
  WHERE o.registered_date BETWEEN from_date AND to_date
)

SELECT
  DATE(o.order_placed_local)                    AS fecha_completa,
  o.country_name,
  hp.warehouse_id,
  hp.warehouse_name,

  -- CPO
  MAX(cpow.dmarts_cpo)                          AS dmarts_cpo,
  MAX(cpow.dmart_orders_cpo)                    AS dmart_orders_cpo,
  MAX(cpoc.platform_cpo)                        AS platform_cpo,
  MAX(cpoc.courier_cpo)                         AS courier_cpo,
  MAX(cpoc.platform_orders_excl_dmarts)         AS platform_orders_excl_dmarts,

  -- Seamless
  SUM(seam.is_seamless)                         AS seamless_numerador,
  COUNT(DISTINCT CASE WHEN seam.order_id IS NOT NULL THEN o.order_id END) AS total_seamless_base_orders,

  -- Fulfillment
  SUM(seam.is_late_order)                       AS late_orders,
  SUM(seam.is_slow_order)                       AS slow_orders,
  SUM(seam.is_session_order)                    AS session_orders,
  SUM(seam.is_forced_preorder)                  AS forced_preorders,
  SUM(seam.is_modified_order)                   AS modified_orders,

  -- Delivery time (sum+count para promedio en vista)
  SUM(CASE WHEN o.order_status = 'CONFIRMED' THEN seam.actual_delivery_time END)                                           AS delivery_time_sum,
  COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND seam.actual_delivery_time IS NOT NULL THEN o.order_id END)     AS delivery_time_order_count,

  -- Assignment time
  SUM(pm.assignment_time_min)                                                                                                AS assignment_time_sum,
  COUNT(DISTINCT CASE WHEN pm.assignment_time_min IS NOT NULL THEN o.order_id END)                                          AS assignment_time_order_count

FROM orders o
INNER JOIN `peya-bi-tools-pro.il_core.dim_country` c  ON c.country_id = o.country_id AND c.active = TRUE
INNER JOIN partners hp                                  ON CAST(hp.partner_id AS STRING) = CAST(o.restaurant_id AS STRING)
LEFT JOIN cost_per_order_country cpoc                   ON cpoc.country_id = o.country_id AND cpoc.day = DATE(o.order_placed_local)
LEFT JOIN cost_per_order_warehouse cpow                 ON cpow.warehouse_id = hp.warehouse_id AND cpow.day = DATE(o.order_placed_local) AND cpow.country_id = o.country_id
LEFT JOIN seamless_metrics seam                         ON CAST(seam.order_id AS STRING) = CAST(o.order_id AS STRING)
LEFT JOIN pickers_metrics pm                            ON CAST(pm.order_id AS STRING)   = CAST(o.order_id AS STRING)
WHERE DATE(o.order_placed_local) BETWEEN from_date AND to_date
GROUP BY 1, 2, 3, 4;
