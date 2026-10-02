-- ==============================================================================
-- PARTE 3: DATOS OPERACIONALES (Seamless, Logística, Timings e Inaccuracy)
-- Nombre: warehouse_ops_performance
--
-- Objetivo: Medir exclusivamente la calidad de servicio, tiempos y fallas por WHS:
--   - Seamless Delivery Rate (% entregas sin fricción) y Fail Rate (Rechazados).
--   - Tiempos de Entrega reales y pedidos tardíos (>10 min y >35 min).
--   - Avoidable Wait Time (AWT) de repartidores esperando en el local.
--   - Grado de apilamiento logístico (Stacked deliveries: 0, 1, 2+).
--   - Tiempos de preparación / picking en tienda.
--   - Reclamos de clientes por calidad o faltantes (Inaccuracy).
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Darkstores desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING) AS partner_id
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Universo de Órdenes Confirmadas desde fact_orders
orders_base AS (
  SELECT
    fo.order_id,
    CAST(fo.order_id AS STRING)                 AS order_id_str,
    dp.warehouse_id,
    dp.warehouse_name,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
),

-- 3. Total de órdenes confirmadas por WHS/Mes para cálculo de ratios
orders_total_whs AS (
  SELECT
    month_date,
    warehouse_id,
    ANY_VALUE(warehouse_name) AS warehouse_name,
    COUNT(DISTINCT order_id)  AS total_confirmed_orders
  FROM orders_base
  GROUP BY 1, 2
),

-- 4. Métricas de Seamless Delivery (non_seamless_delivery_order_level)
seamless_data AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    COUNT(DISTINCT CASE WHEN s.non_seamless_order IS FALSE OR s.non_seamless_order IS NULL THEN ob.order_id_str END) AS seamless_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)   AS rejected_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)       AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_late_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)       AS late_orders_ops,
    COUNT(DISTINCT CASE WHEN CAST(s.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)   AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)  AS forced_pre_orders
  FROM orders_base ob
  LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` s
    ON ob.order_id_str = CAST(s.platform_order_code AS STRING)
  GROUP BY 1, 2
),

-- 5. Métricas de Logística, Tiempos y Apilamiento (fact_logistic_orders)
logistics_data AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    ROUND(AVG(l.timings.actual_delivery_time / 60), 1)      AS avg_delivery_time_min,
    SUM(l.timings.avoidable_wait_time / 60)                 AS total_awt_minutes,
    SUM(l.is_order_late_10)                                 AS order_late_10_count,
    COUNT(DISTINCT CASE WHEN COALESCE(del.stacked_deliveries, 0) = 0 THEN ob.order_id_str END) AS deliveries_stacked_0,
    COUNT(DISTINCT CASE WHEN del.stacked_deliveries = 1 THEN ob.order_id_str END)              AS deliveries_stacked_1,
    COUNT(DISTINCT CASE WHEN del.stacked_deliveries >= 2 THEN ob.order_id_str END)             AS deliveries_stacked_2_plus
  FROM orders_base ob
  INNER JOIN `peya-bi-tools-pro.il_logistics.fact_logistic_orders` l
    ON ob.order_id = l.peya_order_id
  CROSS JOIN UNNEST(l.deliveries) del
  WHERE l.order_cancelled != 1
    AND UPPER(del.delivery_status) = 'COMPLETED'
  GROUP BY 1, 2
),

-- 6. Tiempos de Picking y Demoras Críticas (dmarts_timings)
timings_data AS (
  SELECT
    DATE_TRUNC(DATE(created_date), MONTH) AS month_date,
    warehouse_id,
    ROUND(AVG(picking_time_s), 1)         AS avg_picking_time_s,
    COUNTIF(actual_dt_min > 35)           AS is_dt_35min_count,
    COUNTIF((assignment_time_s / 60) > 6) AS assignment_time_over_6min_count
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= start_month
    AND created_date <= end_month
    AND warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 7. Inexactitud y Quejas de Clientes (dmarts_inaccuracy)
inaccuracy_data AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month_date,
    warehouse_id,
    SUM(total_orders)              AS total_orders_inaccuracy,
    SUM(total_complaint_orders)    AS complaint_orders,
    SUM(food_issue_orders)         AS food_issue_orders,
    SUM(wrong_missing_item_orders) AS wrong_missing_item_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_inaccuracy`
  WHERE order_date >= start_month
    AND order_date <= end_month
  GROUP BY 1, 2
)

-- ==============================================================================
-- SELECT FINAL: PARTE 3 - OPERACIONES
-- ==============================================================================
SELECT
  -- Claves
  tot.month_date,
  tot.warehouse_id,
  tot.warehouse_name,

  -- Seamless & Fulfillment
  COALESCE(sd.seamless_orders, 0)                                   AS seamless_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.seamless_orders, 0), tot.total_confirmed_orders) * 100, 1) AS seamless_pct,
  COALESCE(sd.rejected_orders, 0)                                   AS rejected_orders_fail_rate,
  COALESCE(sd.slow_orders, 0)                                       AS slow_orders,
  COALESCE(sd.late_orders_ops, 0)                                   AS late_orders_ops,
  COALESCE(sd.modified_orders, 0)                                   AS modified_orders,
  COALESCE(sd.forced_pre_orders, 0)                                 AS forced_pre_orders,

  -- Tiempos de Entrega & Demoras
  COALESCE(ld.avg_delivery_time_min, 0)                             AS avg_delivery_time_min,
  COALESCE(ld.order_late_10_count, 0)                               AS order_late_10_count,
  ROUND(SAFE_DIVIDE(COALESCE(ld.order_late_10_count, 0), tot.total_confirmed_orders) * 100, 1) AS pct_late_10,
  COALESCE(td.is_dt_35min_count, 0)                                 AS order_late_35_count,
  ROUND(SAFE_DIVIDE(COALESCE(td.is_dt_35min_count, 0), tot.total_confirmed_orders) * 100, 1) AS pct_late_35,

  -- Logística de Riders & Apilamiento
  ROUND(COALESCE(ld.total_awt_minutes, 0), 1)                       AS total_awt_rider_minutes,
  COALESCE(ld.deliveries_stacked_0, 0)                              AS deliveries_stacked_0,
  COALESCE(ld.deliveries_stacked_1, 0)                              AS deliveries_stacked_1,
  COALESCE(ld.deliveries_stacked_2_plus, 0)                         AS deliveries_stacked_2_plus,
  ROUND(SAFE_DIVIDE(COALESCE(ld.deliveries_stacked_1, 0) + COALESCE(ld.deliveries_stacked_2_plus, 0), tot.total_confirmed_orders) * 100, 1) AS stacked_delivery_ratio_pct,

  -- Preparación en Tienda (Picking)
  COALESCE(td.avg_picking_time_s, 0)                                AS avg_picking_time_s,
  COALESCE(td.assignment_time_over_6min_count, 0)                    AS assignment_time_over_6min_count,

  -- Calidad de Servicio & Reclamos
  COALESCE(id.complaint_orders, 0)                                  AS complaint_orders,
  COALESCE(id.food_issue_orders, 0)                                 AS food_issue_orders,
  COALESCE(id.wrong_missing_item_orders, 0)                         AS wrong_missing_item_orders,
  ROUND(SAFE_DIVIDE(COALESCE(id.complaint_orders, 0), NULLIF(COALESCE(id.total_orders_inaccuracy, tot.total_confirmed_orders), 0)) * 100, 2) AS inaccuracy_rate_pct

FROM orders_total_whs tot

LEFT JOIN seamless_data sd
  ON  tot.warehouse_id = sd.warehouse_id
  AND tot.month_date   = sd.month_date

LEFT JOIN logistics_data ld
  ON  tot.warehouse_id = ld.warehouse_id
  AND tot.month_date   = ld.month_date

LEFT JOIN timings_data td
  ON  tot.warehouse_id = td.warehouse_id
  AND tot.month_date   = td.month_date

LEFT JOIN inaccuracy_data id
  ON  tot.warehouse_id = id.warehouse_id
  AND tot.month_date   = id.month_date

ORDER BY
  tot.month_date DESC,
  seamless_pct ASC;
