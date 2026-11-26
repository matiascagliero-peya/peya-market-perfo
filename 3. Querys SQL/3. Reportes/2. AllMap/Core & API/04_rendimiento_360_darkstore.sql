-- ==============================================================================
-- PILAR 4: RENDIMIENTO INTEGRAL 360° POR TIENDA (WHS / MES)
-- Archivo: 04_rendimiento_360_darkstore.sql
--
-- FUNCIÓN ÚNICA:
--   Consolidar la visión holística mensual de cada Darkstore combinando:
--   1. Ventas y transacciones oficiales (fact_orders y SKU level).
--   2. Operaciones y logística: Seamless %, tiempos de entrega, atrasos y picking.
--   3. Ciclo de Vida del Usuario según taxonomía Frank (New, M1, Reorder, Reactivados).
--
-- TABLAS FUENTE OFICIALES:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (maestro de darkstores)
--   2. `peya-bi-tools-pro.il_core.fact_orders` (órdenes y facturación)
--   3. `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` (unidades y Ultra Fresh)
--   4. `peya-delivery-and-support.automated_tables_reports.dmarts_timings` (tiempos de entrega y picking)
--   5. `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` (calidad fulfillment)
--   6. `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` (motor de ciclo de vida Frank)
--
-- GRANO: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Maestros de Darkstores desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    dp.partner_id,
    dp.country.country_name       AS country,
    dp.city.name                  AS city
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Universo de Órdenes Confirmadas de fact_orders
orders_base AS (
  SELECT
    fo.order_id,
    CAST(fo.order_id AS STRING)                 AS order_id_str,
    CAST(fo.customer_id AS STRING)              AS customer_id,
    dp.warehouse_id,
    dp.warehouse_name,
    dp.country,
    dp.city,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    fo.registered_date,
    fo.total_amount                             AS gross_amount
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
),

-- 3. Detalle de Artículos y Ultra Fresh (customer_orders_sku_level)
orders_sku_enriched AS (
  SELECT
    co.order_id,
    SUM(co.fulfilled_quantity)                  AS units_sold,
    SUM(co.total_amount_net_with_discount_eur)  AS net_sales_eur,
    MAX(CASE WHEN co.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS has_ultra_fresh
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE co.order_date >= start_month
    AND co.order_date <= end_month
    AND co.state = 'CONFIRMED'
  GROUP BY co.order_id
),

-- 4. Métricas de Fulfillment y Seamless Delivery
seamless_data AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    COUNT(DISTINCT CASE WHEN s.non_seamless_order IS FALSE OR s.non_seamless_order IS NULL THEN ob.order_id_str END) AS seamless_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)   AS rejected_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)       AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_late_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id_str END)       AS late_orders
  FROM orders_base ob
  LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` s
    ON ob.order_id_str = CAST(s.platform_order_code AS STRING)
  GROUP BY 1, 2
),

-- 5. Tiempos Logísticos y Picking (dmarts_timings)
timings_data AS (
  SELECT
    DATE_TRUNC(DATE(created_date), MONTH) AS month_date,
    warehouse_id,
    ROUND(AVG(actual_dt_min), 1)          AS avg_delivery_time_min,
    ROUND(AVG(picking_time_s), 1)         AS avg_picking_time_s,
    COUNTIF(actual_dt_min > 35)           AS is_dt_35min_count,
    COUNTIF(SAFE_CAST(is_order_late_10 AS INT64) = 1) AS is_order_late_10_count
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= start_month
    AND created_date <= end_month
    AND warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 6. Ciclo de Vida del Usuario según Taxonomía Frank (CRM)
lifecycle_frank AS (
  SELECT
    ob.warehouse_id,
    ob.month_date,
    COUNT(DISTINCT CASE WHEN f.Market_Actual_Type = 'New User'         THEN ob.customer_id END) AS new_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Market_Actual_Type = 'M1 Return'        THEN ob.customer_id END) AS m1_return_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Market_Actual_Type = 'Reorder'          THEN ob.customer_id END) AS reorder_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Market_Actual_Type = 'Recurring Return' THEN ob.customer_id END) AS recurring_return_dmart,
    COUNT(DISTINCT CASE WHEN f.Market_Actual_Type = 'Re-Activation'    THEN ob.customer_id END) AS reactivation_users_dmart
  FROM orders_base ob
  LEFT JOIN `peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly` f
    ON  ob.customer_id = CAST(f.customer_id AS STRING)
    AND ob.month_date   = f.Fecha
  GROUP BY 1, 2
)

-- ==============================================================================
-- RESULTADO FINAL CONSOLIDADO (WHS / MES)
-- ==============================================================================
SELECT
  -- Identificación
  ob.month_date,
  ob.warehouse_id,
  ANY_VALUE(ob.warehouse_name)                                      AS warehouse_name,
  ANY_VALUE(ob.country)                                             AS country,
  ANY_VALUE(ob.city)                                                AS city,

  -- Transaccional y Consumo
  COUNT(DISTINCT ob.customer_id)                                    AS total_buyers,
  COUNT(DISTINCT ob.order_id)                                       AS total_orders,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT ob.order_id), COUNT(DISTINCT ob.customer_id)), 2) AS monthly_frequency,
  ROUND(SUM(COALESCE(sku.net_sales_eur, ob.gross_amount)), 2)       AS total_net_sales,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(sku.net_sales_eur, ob.gross_amount)), COUNT(DISTINCT ob.order_id)), 2) AS afv_aov_amount,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(sku.units_sold, 0)), COUNT(DISTINCT ob.order_id)), 1) AS basket_size_units,

  -- Categorías Frescas: Ultra Fresh
  COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN ob.order_id END) AS uf_orders,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN ob.order_id END), COUNT(DISTINCT ob.order_id)) * 100, 1) AS uf_share_pct,

  -- Calidad Operativa: Seamless Delivery
  COALESCE(sd.seamless_orders, 0)                                   AS seamless_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.seamless_orders, 0), COUNT(DISTINCT ob.order_id)) * 100, 1) AS seamless_pct,
  COALESCE(sd.rejected_orders, 0)                                   AS rejected_orders,

  -- Eficiencia Logística y Picking
  COALESCE(t.avg_delivery_time_min, 0)                              AS avg_delivery_time_min,
  COALESCE(t.avg_picking_time_s, 0)                                 AS avg_picking_time_s,
  ROUND(SAFE_DIVIDE(COALESCE(t.is_order_late_10_count, 0), COUNT(DISTINCT ob.order_id)) * 100, 1) AS pct_late_10,

  -- Ciclo de Vida del Cliente (Taxonomía Frank)
  COALESCE(lf.new_users_dmart, 0)                                   AS new_users_dmart,
  COALESCE(lf.m1_return_users_dmart, 0)                             AS m1_return_users_dmart,
  COALESCE(lf.reorder_users_dmart, 0)                               AS reorder_users_dmart,
  COALESCE(lf.recurring_return_dmart, 0)                            AS recurring_return_dmart,
  COALESCE(lf.reactivation_users_dmart, 0)                          AS reactivation_users_dmart

FROM orders_base ob

LEFT JOIN orders_sku_enriched sku
  ON ob.order_id_str = sku.order_id

LEFT JOIN seamless_data sd
  ON  ob.warehouse_id = sd.warehouse_id
  AND ob.month_date   = sd.month_date

LEFT JOIN timings_data t
  ON  ob.warehouse_id = t.warehouse_id
  AND ob.month_date   = t.month_date

LEFT JOIN lifecycle_frank lf
  ON  ob.warehouse_id = lf.warehouse_id
  AND ob.month_date   = lf.month_date

GROUP BY
  ob.month_date,
  ob.warehouse_id,
  sd.seamless_orders,
  sd.rejected_orders,
  t.avg_delivery_time_min,
  t.avg_picking_time_s,
  t.is_order_late_10_count,
  lf.new_users_dmart,
  lf.m1_return_users_dmart,
  lf.reorder_users_dmart,
  lf.recurring_return_dmart,
  lf.reactivation_users_dmart

ORDER BY
  ob.month_date DESC,
  total_orders DESC;
