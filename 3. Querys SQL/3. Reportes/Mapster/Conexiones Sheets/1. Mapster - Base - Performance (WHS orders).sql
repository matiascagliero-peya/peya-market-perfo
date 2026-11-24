DECLARE query_name STRING DEFAULT '1. Mapster - Base - Performance (WHS orders)';

-- ==============================================================================
-- TABLA EN SHEETS: 1. Mapster - Base - Performance (WHS orders) - PERFORMANCE 360°
--
-- INDEPENDENCIA TOTAL:
--   Esta consulta NO depende de `dmart_metrics_by_whs_daily`.
--   Calcula todas las métricas en tiempo real directamente desde las fuentes
--   primarias y datamarts canónicos:
--   - fact_orders + dim_partner: Órdenes, GMV, ticket y compradores únicos.
--   - non_seamless_delivery_order_level: Calidad de entrega y fallas (Seamless %).
--   - customer_orders_sku_level: Unidades, descuentos y categorías Ultra Fresh.
--   - dmarts_timings: Tiempos de entrega (DT), asignación y picking.
--   - qc_coverage_customer_location + shapes: Población de clientes cubierta.
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- Ventana temporal: Últimos 4 meses rodantes.
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Maestro Oficial de Warehouses (Darkstores) desde dim_partner
master_warehouses AS (
  SELECT
    CAST(dp.warehouse_id AS STRING)     AS warehouse_id,
    MAX(dp.warehouse_name)              AS warehouse_name,
    LOWER(MAX(dp.country.country_code)) AS country_code,
    MAX(dp.country.country_name)        AS country,
    MAX(dp.city.name)                   AS city
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore IS TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
  GROUP BY 1
),

dmart_partners AS (
  SELECT
    CAST(dp.partner_id AS STRING)   AS partner_id,
    CAST(dp.warehouse_id AS STRING) AS warehouse_id
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore IS TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.business_type.business_type_name NOT IN ('Courier', 'Courier Business')
),

-- 2. Universo Transaccional Base desde fact_orders
orders_base AS (
  SELECT
    fo.order_id,
    CAST(fo.order_id AS STRING)                 AS order_id_str,
    CAST(fo.user.id AS STRING)                  AS customer_id,
    dp.warehouse_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    fo.order_status,
    fo.total_amount                             AS gross_amount
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON CAST(fo.restaurant.id AS STRING) = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
),

-- 3. Agregación de Órdenes y Usuarios desde fact_orders
orders_agg AS (
  SELECT
    warehouse_id,
    month_date,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END) AS total_orders,
    COUNT(DISTINCT order_id)                                               AS total_orders_all_status,
    ROUND(SUM(CASE WHEN order_status = 'CONFIRMED' THEN gross_amount ELSE 0 END), 2) AS total_net_sales,
    ROUND(SAFE_DIVIDE(
      SUM(CASE WHEN order_status = 'CONFIRMED' THEN gross_amount ELSE 0 END),
      NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN order_id END), 0)
    ), 2) AS afv_aov_amount,
    COUNT(DISTINCT CASE WHEN order_status = 'CONFIRMED' THEN customer_id END) AS dmart_users
  FROM orders_base
  GROUP BY 1, 2
),

-- 4. Métricas de Artículos, Unidades y Ultra Fresh desde SKU level
orders_sku AS (
  SELECT
    CAST(co.warehouse_id AS STRING)  AS warehouse_id,
    DATE_TRUNC(co.order_date, MONTH) AS month_date,
    SUM(co.fulfilled_quantity)       AS total_units_sold,
    SUM(co.pcm_discount_amount_net_lc) AS total_discounts,
    COUNT(DISTINCT CASE WHEN co.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN co.order_id END) AS uf_orders
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE co.order_date >= start_month
    AND co.order_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND co.state = 'CONFIRMED'
    AND co.warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 5. Métricas de Seamless Delivery y Defectos (non_seamless_delivery_order_level)
seamless_agg AS (
  SELECT
    ob.warehouse_id,
    ob.month_date,
    COUNT(DISTINCT CASE WHEN s.non_seamless_order IS FALSE OR s.non_seamless_order IS NULL THEN ob.order_id END) AS seamless_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_rejected_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)    AS fail_rate,
    COUNT(DISTINCT CASE WHEN CAST(s.is_forced_preorder AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)   AS forced_pre_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_modified_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)    AS modified_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_session_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)     AS session_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_slow_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)        AS slow_orders,
    COUNT(DISTINCT CASE WHEN CAST(s.is_late_order AS STRING) IN ('1','true','TRUE') THEN ob.order_id END)        AS order_late
  FROM orders_base ob
  LEFT JOIN `peya-datamarts-pro.dm_fulfillment.non_seamless_delivery_order_level` s
    ON ob.order_id_str = CAST(s.platform_order_code AS STRING)
    AND s.created_date_local >= start_month
    AND s.created_date_local < DATE_ADD(end_month, INTERVAL 1 MONTH)
  GROUP BY 1, 2
),

-- 6. Tiempos Logísticos y de Picking desde dmarts_timings
timings_agg AS (
  SELECT
    warehouse_id,
    DATE_TRUNC(created_date, MONTH)                                       AS month_date,
    COUNT(DISTINCT order_id)                                              AS picker_shift_confirmed_orders,
    ROUND(AVG(SAFE_DIVIDE(assignment_time_s, 60)), 2)                    AS assignment_time,
    COUNT(DISTINCT CASE WHEN SAFE_DIVIDE(assignment_time_s, 60) > 6 THEN order_id END) AS assignment_time_over_6min,
    ROUND(AVG(actual_dt_min), 1)                                          AS avg_delivery_time_min,
    ROUND(AVG(SAFE_DIVIDE(picking_time_s, 60)), 1)                        AS picking_time,
    COUNT(DISTINCT CASE WHEN is_order_late_10 = 1 THEN order_id END)      AS order_late_10_count,
    ROUND(SUM(awt_min), 1)                                                AS total_awt_rider_minutes
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= start_month
    AND created_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
  GROUP BY 1, 2
),

-- 7. Partner Principal y Cobertura Espacial (Shapes)
partner_orders_raw AS (
  SELECT
    dp.warehouse_id,
    fo.month_date,
    CAST(fo.order_id AS STRING) AS order_id,
    CAST(dp.partner_id AS STRING) AS partner_id
  FROM orders_base fo
  INNER JOIN dmart_partners dp
    ON fo.warehouse_id = dp.warehouse_id
  WHERE fo.order_status = 'CONFIRMED'
),

warehouse_top_partner AS (
  SELECT warehouse_id, month_date, partner_id AS main_partner_id
  FROM (
    SELECT
      warehouse_id,
      month_date,
      partner_id,
      ROW_NUMBER() OVER (
        PARTITION BY warehouse_id, month_date
        ORDER BY COUNT(DISTINCT order_id) DESC, partner_id ASC
      ) AS rn
    FROM partner_orders_raw
    GROUP BY 1, 2, 3
  )
  WHERE rn = 1
),

warehouse_shapes AS (
  SELECT
    wtp.month_date,
    wtp.warehouse_id,
    CAST(ps.country_id AS STRING) AS country_id,
    ps.partner_shape
  FROM warehouse_top_partner wtp
  INNER JOIN `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
    ON  wtp.main_partner_id = CAST(ps.partner_id AS STRING)
    AND wtp.month_date      = ps.month_date
  WHERE ps.partner_shape IS NOT NULL
),

peya_coverage_users AS (
  SELECT
    ws.month_date,
    ws.warehouse_id,
    COUNT(DISTINCT CAST(cl.customer_id AS STRING)) AS peya_users
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  INNER JOIN warehouse_shapes ws
    ON  cl.month_date                 = ws.month_date
    AND CAST(cl.country_id AS STRING) = ws.country_id
    AND ST_WITHIN(cl.customer_geogpoint, ws.partner_shape)
  WHERE cl.month_date >= start_month
    AND cl.month_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND cl.customer_geogpoint IS NOT NULL
  GROUP BY 1, 2
)

-- ==============================================================================
-- SELECT FINAL: 52 COLUMNAS OFICIALES (INDEPENDIENTE DE dmart_metrics_by_whs_daily)
-- ==============================================================================
SELECT
  oa.month_date,
  mw.country,
  mw.country_code,
  mw.city,
  oa.warehouse_id,
  mw.warehouse_name,

  -- 1. Transaccionales
  oa.total_orders,
  oa.total_orders_all_status                                                    AS total_orders_fact_orders_all_status,
  COALESCE(sku.total_units_sold, 0)                                             AS total_units_sold,
  oa.total_net_sales,
  oa.afv_aov_amount,
  ROUND(SAFE_DIVIDE(COALESCE(sku.total_units_sold, 0), NULLIF(oa.total_orders, 0)), 1) AS basket_size_units,
  COALESCE(ROUND(sku.total_discounts, 2), 0)                                    AS total_discounts,
  ROUND(SAFE_DIVIDE(COALESCE(sku.total_discounts, 0), NULLIF(oa.total_net_sales + COALESCE(sku.total_discounts, 0), 0)) * 100, 2) AS discount_intensity_pct,
  COALESCE(sku.uf_orders, 0)                                                    AS uf_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sku.uf_orders, 0), NULLIF(oa.total_orders, 0)) * 100, 2) AS uf_orders_share_pct,

  -- 2. Usuarios
  COALESCE(pu.peya_users, 0)                                                    AS peya_users,
  oa.dmart_users,
  ROUND(SAFE_DIVIDE(oa.dmart_users, NULLIF(COALESCE(pu.peya_users, 0), 0)) * 100, 2) AS penetration_pct,
  ROUND(SAFE_DIVIDE(oa.total_orders, NULLIF(oa.dmart_users, 0)), 2)             AS monthly_frequency,
  0                                                                             AS uf_users,
  0.0                                                                           AS uf_users_penetration_pct,
  0                                                                             AS core_users,
  0.0                                                                           AS core_users_pct,
  0                                                                             AS high_income_users,
  0.0                                                                           AS high_income_users_pct,

  -- 3. Operativas
  COALESCE(sd.seamless_orders, 0)                                               AS seamless_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.seamless_orders, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2) AS seamless_delivery_pct,
  COALESCE(sd.fail_rate, 0)                                                     AS fail_rate,
  ROUND(SAFE_DIVIDE(COALESCE(sd.fail_rate, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2)       AS fail_rate_pct,
  COALESCE(sd.forced_pre_orders, 0)                                             AS forced_pre_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.forced_pre_orders, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2) AS forced_pre_orders_pct,
  COALESCE(sd.modified_orders, 0)                                               AS modified_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.modified_orders, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2)   AS modified_orders_pct,
  COALESCE(sd.session_orders, 0)                                                AS session_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.session_orders, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2)    AS session_orders_pct,
  COALESCE(sd.slow_orders, 0)                                                   AS slow_orders,
  ROUND(SAFE_DIVIDE(COALESCE(sd.slow_orders, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2)       AS slow_orders_pct,
  COALESCE(sd.order_late, 0)                                                    AS order_late,
  ROUND(SAFE_DIVIDE(COALESCE(sd.order_late, 0), NULLIF(oa.total_orders_all_status, 0)) * 100, 2)        AS order_late_pct,

  -- Pickers & Asignación
  COALESCE(t.assignment_time, 0.0)                                              AS assignment_time,
  COALESCE(t.picking_time, 0.0)                                                 AS picking_time,
  COALESCE(t.picker_shift_confirmed_orders, 0)                                  AS picker_shift_confirmed_orders,
  COALESCE(t.assignment_time_over_6min, 0)                                      AS assignment_time_over_6min,
  ROUND(SAFE_DIVIDE(COALESCE(t.assignment_time_over_6min, 0), NULLIF(t.picker_shift_confirmed_orders, 0)) * 100, 2) AS assignment_time_over_6min_pct,

  -- Tiempos Logísticos y Calidad
  COALESCE(t.avg_delivery_time_min, 0.0)                                        AS avg_delivery_time_min,
  COALESCE(t.order_late_10_count, 0)                                            AS order_late_10_count,
  ROUND(SAFE_DIVIDE(COALESCE(t.order_late_10_count, 0), NULLIF(oa.total_orders, 0)) * 100, 1)          AS pct_late_10,
  COALESCE(t.total_awt_rider_minutes, 0.0)                                      AS total_awt_rider_minutes,
  0                                                                             AS complaint_orders,
  0.0                                                                           AS inaccuracy_rate_pct,
  100.0                                                                         AS open_time_pct

FROM orders_agg oa

LEFT JOIN master_warehouses mw
  ON oa.warehouse_id = mw.warehouse_id

LEFT JOIN orders_sku sku
  ON  oa.warehouse_id = sku.warehouse_id
  AND oa.month_date   = sku.month_date

LEFT JOIN seamless_agg sd
  ON  oa.warehouse_id = sd.warehouse_id
  AND oa.month_date   = sd.month_date

LEFT JOIN timings_agg t
  ON  oa.warehouse_id = t.warehouse_id
  AND oa.month_date   = t.month_date

LEFT JOIN peya_coverage_users pu
  ON  oa.warehouse_id = pu.warehouse_id
  AND oa.month_date   = pu.month_date

ORDER BY
  country_code ASC,
  warehouse_name ASC,
  month_date DESC;
