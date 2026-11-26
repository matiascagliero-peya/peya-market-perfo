-- ==============================================================================
-- QUERY ANALÍTICA: datamart_warehouse_ops_and_users_performance
--
-- Objetivo: Generar el datamart mensual por Warehouse (WHS) enfocado en:
--   1. Segmentación profunda de usuarios (Core Users, High Income, Basket Size,
--      Frecuencia, AFV, Ultra Fresh y Antigüedad/Tenure).
--   2. Operaciones avanzadas (Seamless Delivery, Fail Rate, Delivery Times, AWT,
--      Stacked deliveries, Picking y Reclamos de Inaccuracy).
--
-- Fuentes y Referencias:
--   - `1. OPS Data - Base - OPS (Mensual).sql` (Seamless, logística, inaccuracy, timings)
--   - `6. Users details - Base - Performance.sql` (SKUs, Ultra Fresh, Growth Tracker, Basket)
--   - `peya-bi-tools-pro.il_core.fact_orders` (ventas y órdenes oficiales)
--   - `peya-bi-tools-pro.il_qcommerce.user_lifecycle` (Core y High Income)
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Maestros de Almacenes (Darkstores) desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING) AS partner_id,
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

-- 3. Métricas de Artículos, Unidades y Ultra Fresh desde SKU level
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

-- 4. Perfil y Segmentación del Usuario (Core & High Income)
user_profiles AS (
  SELECT
    CAST(du.customer_id AS STRING)                           AS customer_id,
    MAX(CASE WHEN UPPER(lc.subsegment) = 'CORE' THEN 1 ELSE 0 END) AS is_core_user,
    MAX(CASE WHEN UPPER(lc.user_income) = 'HIGH' THEN 1 ELSE 0 END) AS is_high_income_user
  FROM `peya-bi-tools-pro.il_qcommerce.user_lifecycle` lc
  INNER JOIN `peya-bi-tools-pro.il_core.dim_user` du
    ON lc.user_id = du.user_id AND lc.country_id = du.country_id
  GROUP BY 1
),

-- 5. Antigüedad y Growth Status desde latam_dmart_growth_tracker
user_growth_tracker AS (
  SELECT
    CAST(customer_id AS STRING)  AS customer_id,
    DATE_TRUNC(month, MONTH)     AS month_date,
    AVG(mes_en_curso)            AS user_tenure_months
  FROM `peya-food-and-groceries.automated_tables_reports.latam_dmart_growth_tracker`
  WHERE month >= start_month
    AND dmart_growth_status_fixed != 'Churned'
  GROUP BY 1, 2
),

-- 6. Consolidación de Usuarios a Nivel Warehouse / Mes
users_warehouse_agg AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    ANY_VALUE(ob.warehouse_name) AS warehouse_name,
    ANY_VALUE(ob.country)        AS country,
    ANY_VALUE(ob.city)           AS city,

    -- Totales Básicos
    COUNT(DISTINCT ob.customer_id) AS total_users,
    COUNT(DISTINCT ob.order_id)    AS total_orders,
    SUM(COALESCE(sku.units_sold, 0)) AS total_units_sold,
    SUM(COALESCE(sku.net_sales_eur, ob.gross_amount)) AS total_net_sales,

    -- Segmentos: Core y High Income
    COUNT(DISTINCT CASE WHEN up.is_core_user = 1 THEN ob.customer_id END) AS core_users,
    COUNT(DISTINCT CASE WHEN up.is_high_income_user = 1 THEN ob.customer_id END) AS high_income_users,

    -- Antigüedad promedio (Tenure)
    ROUND(AVG(gt.user_tenure_months), 1) AS avg_tenure_months,

    -- Penetración y Adopción de Ultra Fresh
    COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN ob.order_id END)    AS uf_orders,
    COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN ob.customer_id END) AS uf_users

  FROM orders_base ob
  LEFT JOIN orders_sku_enriched sku
    ON ob.order_id = sku.order_id
  LEFT JOIN user_profiles up
    ON ob.customer_id = up.customer_id
  LEFT JOIN user_growth_tracker gt
    ON  ob.customer_id = gt.customer_id
    AND ob.month_date   = gt.month_date
  GROUP BY 1, 2
),

-- 7. Operaciones: Seamless Delivery (Fulfillment)
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

-- 8. Operaciones: Logística y Entregas Apiladas (fact_logistic_orders)
logistics_data AS (
  SELECT
    ob.month_date,
    ob.warehouse_id,
    ROUND(AVG(l.timings.actual_delivery_time / 60), 1)      AS avg_delivery_time_min,
    SUM(l.timings.avoidable_wait_time / 60)                 AS total_awt_minutes,
    SUM(l.is_order_late_10)                                 AS order_late_10_count,
    SUM(l.is_vendor_late_10)                                AS vendor_late_10_count,
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

-- 9. Operaciones: Tiempos de Picking y Saturación (dmarts_timings)
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

-- 10. Operaciones: Inexactitud y Reclamos de Calidad (dmarts_inaccuracy)
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
-- RESULTADO FINAL CONSOLIDADO (WHS / MES)
-- ==============================================================================
SELECT
  -- ===== 1. Identificación =====
  u.month_date,
  u.warehouse_id,
  u.warehouse_name,
  u.country,
  u.city,

  -- ===== 2. Segmentación Profunda de Usuarios =====
  u.total_users,
  u.core_users,
  ROUND(SAFE_DIVIDE(u.core_users, u.total_users) * 100, 1)          AS core_users_pct,
  u.high_income_users,
  ROUND(SAFE_DIVIDE(u.high_income_users, u.total_users) * 100, 1)   AS high_income_users_pct,
  u.avg_tenure_months,

  -- ===== 3. Datos de Consumo de los Usuarios =====
  u.total_orders,
  ROUND(SAFE_DIVIDE(u.total_orders, u.total_users), 2)              AS monthly_frequency,
  ROUND(SAFE_DIVIDE(u.total_units_sold, u.total_orders), 1)         AS basket_size_units,
  ROUND(SAFE_DIVIDE(u.total_net_sales, u.total_orders), 2)          AS afv_aov_amount,
  ROUND(u.total_net_sales, 2)                                       AS total_net_sales,
  u.uf_users,
  ROUND(SAFE_DIVIDE(u.uf_users, u.total_users) * 100, 1)            AS uf_users_penetration_pct,
  u.uf_orders,
  ROUND(SAFE_DIVIDE(u.uf_orders, u.total_orders) * 100, 1)          AS uf_orders_share_pct,

  -- ===== 4. Operaciones: Seamless & Calidad de Fulfillment =====
  COALESCE(sd.seamless_orders, 0)                                   AS seamless_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.seamless_orders, 0), u.total_orders) * 100, 1) AS seamless_pct,
  COALESCE(sd.rejected_orders, 0)                                   AS rejected_orders_fail_rate,
  COALESCE(sd.slow_orders, 0)                                       AS slow_orders,
  COALESCE(sd.late_orders_ops, 0)                                   AS late_orders_ops,
  COALESCE(sd.modified_orders, 0)                                   AS modified_orders,

  -- ===== 5. Operaciones: Logística, Tiempos de Entrega & Stacked =====
  COALESCE(ld.avg_delivery_time_min, 0)                             AS avg_delivery_time_min,
  COALESCE(ld.order_late_10_count, 0)                               AS order_late_10_count,
  ROUND(SAFE_DIVIDE(COALESCE(ld.order_late_10_count, 0), u.total_orders) * 100, 1) AS pct_late_10,
  COALESCE(td.is_dt_35min_count, 0)                                 AS order_late_35_count,
  ROUND(SAFE_DIVIDE(COALESCE(td.is_dt_35min_count, 0), u.total_orders) * 100, 1) AS pct_late_35,
  ROUND(COALESCE(ld.total_awt_minutes, 0), 1)                       AS total_awt_rider_minutes,
  COALESCE(ld.deliveries_stacked_0, 0)                              AS deliveries_stacked_0,
  COALESCE(ld.deliveries_stacked_1, 0)                              AS deliveries_stacked_1,
  COALESCE(ld.deliveries_stacked_2_plus, 0)                         AS deliveries_stacked_2_plus,
  ROUND(SAFE_DIVIDE(COALESCE(ld.deliveries_stacked_1, 0) + COALESCE(ld.deliveries_stacked_2_plus, 0), u.total_orders) * 100, 1) AS stacked_delivery_ratio_pct,

  -- ===== 6. Operaciones: Picking y Despacho en Tienda =====
  COALESCE(td.avg_picking_time_s, 0)                                AS avg_picking_time_s,
  COALESCE(td.assignment_time_over_6min_count, 0)                    AS assignment_time_over_6min_count,

  -- ===== 7. Operaciones: Reclamos e Inaccuracy =====
  COALESCE(id.complaint_orders, 0)                                  AS complaint_orders,
  COALESCE(id.food_issue_orders, 0)                                 AS food_issue_orders,
  COALESCE(id.wrong_missing_item_orders, 0)                         AS wrong_missing_item_orders,
  ROUND(SAFE_DIVIDE(COALESCE(id.complaint_orders, 0), NULLIF(COALESCE(id.total_orders_inaccuracy, u.total_orders), 0)) * 100, 2) AS inaccuracy_rate_pct

FROM users_warehouse_agg u

LEFT JOIN seamless_data sd
  ON  u.warehouse_id = sd.warehouse_id
  AND u.month_date   = sd.month_date

LEFT JOIN logistics_data ld
  ON  u.warehouse_id = ld.warehouse_id
  AND u.month_date   = ld.month_date

LEFT JOIN timings_data td
  ON  u.warehouse_id = td.warehouse_id
  AND u.month_date   = td.month_date

LEFT JOIN inaccuracy_data id
  ON  u.warehouse_id = id.warehouse_id
  AND u.month_date   = id.month_date

ORDER BY
  u.month_date DESC,
  u.country,
  u.city,
  u.total_orders DESC;
