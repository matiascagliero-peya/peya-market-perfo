-- ==============================================================================
-- PILAR 2: ANÁLISIS DE PENETRACIÓN POR ANILLOS CONCÉNTRICOS
-- Archivo: 02_analisis_anillos_concentricos.sql
--
-- FUNCIÓN ÚNICA:
--   Segmentar el territorio alrededor de cada tienda en anillos concéntricos
--   (< 1 KM, 1-2 KM, 2-3 KM, 3-4 KM, etc.) y calcular:
--   - Universo de usuarios de la app cubiertos (Covered MAUs).
--   - Clientes que compraron en la tienda (Dmart MAUs).
--   - Tasa de penetración por radio (% Dmart / Covered).
--   - Facturación neta, unidades vendidas y pedidos Ultra Fresh.
--   - Eficiencia logística: tiempos de entrega (DT) y atrasos (>10 min).
--
-- TABLAS FUENTE OFICIALES:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (coordenadas de la tienda)
--   2. `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` (polígono de cobertura)
--   3. `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` (domicilio del usuario)
--   4. `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` (ventas y artículos)
--   5. `peya-delivery-and-support.automated_tables_reports.dmarts_timings` (tiempos de entrega y picking)
--
-- GRANO: 1 fila por (month_date, warehouse_id, anillo_order)
-- ==============================================================================

DECLARE target_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);

WITH

-- 1. Coordenadas y polígonos mensuales de cada tienda
store_shapes_historical AS (
  SELECT
    dl.warehouse_id,
    dl.warehouse_name, 
    dl.country_name AS country,
    dl.store_geopoint,
    ps.month_date,
    ps.partner_shape AS full_shape
  FROM (
    SELECT
      warehouse_id, warehouse_name, country_name, partner_id,
      ST_GEOGPOINT(longitud, latitud) AS store_geopoint
    FROM (
      SELECT DISTINCT
        dp.warehouse_id,
        dp.warehouse_name,
        dp.country.country_name AS country_name,
        CAST(dp.partner_id AS STRING) AS partner_id,
        CAST(dp.address.longitude AS FLOAT64) AS longitud,
        CAST(dp.address.latitude AS FLOAT64)  AS latitud
      FROM `peya-bi-tools-pro.il_core.dim_partner` dp
      WHERE dp.is_darkstore = TRUE
        AND dp.address.longitude IS NOT NULL
        AND dp.address.latitude IS NOT NULL
    )
  ) dl
  JOIN `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
    ON  dl.partner_id = CAST(ps.partner_id AS STRING)
    AND ps.month_date = target_month
),

-- 2. Ubicación de usuarios y asignación al almacén más cercano
users_locations_raw AS (
  SELECT
    CAST(cl.customer_id AS STRING)                         AS customer_id,
    cl.month_date,
    ss.warehouse_id,
    ss.warehouse_name,
    ss.country,
    ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) AS dist_mts,
    FALSE                                                  AS sin_cobertura
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  JOIN store_shapes_historical ss
    ON  ST_WITHIN(cl.customer_geogpoint, ss.full_shape)
    AND cl.month_date = ss.month_date
  WHERE cl.month_date = target_month
    AND cl.customer_geogpoint IS NOT NULL
),

users_locations AS (
  SELECT
    customer_id, month_date, warehouse_id, warehouse_name, country,
    CASE
      WHEN dist_mts <= 1000  THEN 1
      WHEN dist_mts <= 2000  THEN 2
      WHEN dist_mts <= 3000  THEN 3
      WHEN dist_mts <= 4000  THEN 4
      WHEN dist_mts <= 5000  THEN 5
      WHEN dist_mts <= 6000  THEN 6
      WHEN dist_mts <= 7000  THEN 7
      WHEN dist_mts <= 8000  THEN 8
      WHEN dist_mts <= 9000  THEN 9
      WHEN dist_mts <= 10000 THEN 10
      ELSE 11
    END AS anillo_order,
    CASE
      WHEN dist_mts <= 1000  THEN '< 1 KM'
      WHEN dist_mts <= 2000  THEN '1-2 KM'
      WHEN dist_mts <= 3000  THEN '2-3 KM'
      WHEN dist_mts <= 4000  THEN '3-4 KM'
      WHEN dist_mts <= 5000  THEN '4-5 KM'
      WHEN dist_mts <= 6000  THEN '5-6 KM'
      WHEN dist_mts <= 7000  THEN '6-7 KM'
      WHEN dist_mts <= 8000  THEN '7-8 KM'
      WHEN dist_mts <= 9000  THEN '8-9 KM'
      WHEN dist_mts <= 10000 THEN '9-10 KM'
      ELSE '> 10 KM'
    END AS anillo,
    sin_cobertura
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id, month_date
        ORDER BY dist_mts ASC
      ) AS store_rank
    FROM users_locations_raw
  )
  WHERE store_rank = 1

  UNION ALL

  -- Usuarios fuera de cualquier polígono oficial
  SELECT
    CAST(cl.customer_id AS STRING) AS customer_id,
    cl.month_date,
    CAST(NULL AS STRING)           AS warehouse_id,
    CAST(NULL AS STRING)           AS warehouse_name,
    cl.country_name                AS country,
    99                             AS anillo_order,
    'Sin Cobertura'                AS anillo,
    TRUE                           AS sin_cobertura
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  WHERE cl.month_date = target_month
    AND NOT EXISTS (
      SELECT 1
      FROM users_locations_raw ulr
      WHERE ulr.customer_id = CAST(cl.customer_id AS STRING)
        AND ulr.month_date  = cl.month_date
    )
),

-- 3. Transacciones y artículos a nivel SKU
orders_base AS (
  SELECT
    order_id,
    CAST(customer_id AS STRING)             AS customer_id,
    warehouse_id,
    DATE_TRUNC(order_date, MONTH)           AS month_date,
    MAX(CASE WHEN master_category_parent_english IN ('Produce','Meat / Seafood','Ready To Consume')
             THEN 1 ELSE 0 END)             AS has_ultra_fresh,
    SUM(fulfilled_quantity)                 AS units_sold_dmart,
    SUM(total_amount_net_with_discount_eur) AS net_sales_dmart,
    SUM(pcm_discount_amount_net_lc)         AS discounts_dmart
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE DATE_TRUNC(order_date, MONTH) = target_month
    AND state = 'CONFIRMED'
  GROUP BY 1, 2, 3, 4
),

-- 4. Tiempos operacionales y demoras
timings_filtered AS (
  SELECT
    order_id, picking_time_s, items, actual_dt_min,
    SAFE_CAST(is_order_late_10  AS INT64)          AS is_order_late_10,
    SAFE_CAST(is_vendor_late_10 AS INT64)          AS is_vendor_late_10,
    CASE WHEN actual_dt_min > 35 THEN 1 ELSE 0 END AS is_dt_35min
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE DATE_TRUNC(created_date, MONTH) = target_month
),

coverage_deduped AS (
  SELECT DISTINCT customer_id, warehouse_id, month_date, anillo_order, anillo
  FROM users_locations
  WHERE sin_cobertura = FALSE
),

orders_enriched AS (
  SELECT
    o.order_id, o.customer_id, o.warehouse_id, o.month_date,
    o.has_ultra_fresh, o.units_sold_dmart, o.net_sales_dmart, o.discounts_dmart,
    t.picking_time_s, t.items AS picked_items, t.actual_dt_min,
    t.is_order_late_10, t.is_vendor_late_10, t.is_dt_35min,
    CASE WHEN ul.customer_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_covered,
    ul.anillo_order AS anillo_order_domicilio,
    ul.anillo       AS anillo_domicilio
  FROM orders_base o
  LEFT JOIN timings_filtered t
    ON o.order_id = t.order_id
  LEFT JOIN coverage_deduped ul
    ON  o.customer_id  = ul.customer_id
    AND o.warehouse_id = ul.warehouse_id
    AND o.month_date   = ul.month_date
),

covered_by_ring AS (
  SELECT
    warehouse_id, warehouse_name, country, month_date, anillo_order, anillo,
    COUNT(DISTINCT customer_id) AS Covered_MAUs
  FROM users_locations
  WHERE sin_cobertura = FALSE
  GROUP BY 1, 2, 3, 4, 5, 6
),

dmart_covered_by_ring AS (
  SELECT
    warehouse_id, month_date,
    anillo_order_domicilio AS anillo_order,
    anillo_domicilio       AS anillo,
    COUNT(DISTINCT customer_id)                                           AS Dmart_MAUs_Covered,
    COUNT(DISTINCT order_id)                                              AS dmart_orders,
    SUM(has_ultra_fresh)                                                  AS ultra_fresh_orders_dmart,
    SUM(units_sold_dmart)                                                 AS units_sold_dmart,
    SUM(net_sales_dmart)                                                  AS net_sales_dmart,
    SUM(discounts_dmart)                                                  AS discounts_dmart,
    COUNT(DISTINCT CASE WHEN actual_dt_min IS NOT NULL THEN order_id END) AS total_orders_timings,
    SUM(picking_time_s)                                                   AS item_picking_time,
    SUM(picked_items)                                                     AS picked_items,
    SUM(actual_dt_min)                                                    AS sum_delivery_time_min,
    SUM(is_order_late_10)                                                 AS is_order_late_10,
    SUM(is_vendor_late_10)                                                AS is_vendor_late_10,
    SUM(is_dt_35min)                                                      AS is_dt_35min
  FROM orders_enriched
  WHERE is_covered = TRUE
  GROUP BY 1, 2, 3, 4
),

totals_per_warehouse AS (
  SELECT warehouse_id, month_date, SUM(Covered_MAUs) AS total_covered_maus_warehouse
  FROM covered_by_ring
  GROUP BY 1, 2
)

-- ==============================================================================
-- RESULTADO FINAL: MATRIZ DE ANILLOS CONCÉNTRICOS POR DARKSTORE
-- ==============================================================================
SELECT
  dcr.month_date,
  dcr.warehouse_id,
  cbr.warehouse_name,
  cbr.country,
  dcr.anillo_order,
  dcr.anillo,

  -- Universo de usuarios y adopción
  COALESCE(cbr.Covered_MAUs, 0)                                       AS Covered_MAUs,
  COALESCE(tpw.total_covered_maus_warehouse, 0)                       AS total_covered_maus_warehouse,
  dcr.Dmart_MAUs_Covered,
  ROUND(SAFE_DIVIDE(dcr.Dmart_MAUs_Covered, cbr.Covered_MAUs) * 100, 1) AS penetration_pct,

  -- Actividad Comercial
  dcr.dmart_orders,
  ROUND(SAFE_DIVIDE(dcr.dmart_orders, dcr.Dmart_MAUs_Covered), 2)     AS monthly_frequency,
  ROUND(dcr.net_sales_dmart, 2)                                       AS net_sales_dmart,
  ROUND(SAFE_DIVIDE(dcr.net_sales_dmart, dcr.dmart_orders), 2)        AS aov_amount,
  dcr.units_sold_dmart,
  dcr.ultra_fresh_orders_dmart,
  ROUND(SAFE_DIVIDE(dcr.ultra_fresh_orders_dmart, dcr.dmart_orders) * 100, 1) AS ultra_fresh_share_pct,

  -- Rendimiento Operacional
  dcr.total_orders_timings,
  ROUND(SAFE_DIVIDE(dcr.sum_delivery_time_min, dcr.total_orders_timings), 1) AS avg_delivery_time_min,
  ROUND(SAFE_DIVIDE(dcr.is_order_late_10, dcr.total_orders_timings) * 100, 1) AS pct_order_late_10,
  ROUND(SAFE_DIVIDE(dcr.item_picking_time, dcr.total_orders_timings), 1)     AS avg_picking_time_s

FROM dmart_covered_by_ring dcr
LEFT JOIN covered_by_ring cbr
  ON  dcr.warehouse_id = cbr.warehouse_id
  AND dcr.month_date   = cbr.month_date
  AND dcr.anillo_order = cbr.anillo_order
LEFT JOIN totals_per_warehouse tpw
  ON  dcr.warehouse_id = tpw.warehouse_id
  AND dcr.month_date   = tpw.month_date
ORDER BY
  dcr.month_date DESC,
  dcr.warehouse_id,
  dcr.anillo_order ASC;
