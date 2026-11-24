-- ==============================================================================
-- QUERY ANALÍTICA INTEGRAL DE SHAPES POR WHS: datamart_warehouse_shape_analytics
--
-- Objetivo: Cruzar cada polígono de cobertura de Warehouse (Shape) con:
--   1. Morfología y métricas de terreno (área km², perímetro, radio máximo, compacidad).
--   2. Demografía y Universo PeYa en el Shape (usuarios cubiertos, densidad por km²).
--   3. Penetración y Adopción Darkstores (DMart MAUs cubiertos, penetración %, gap).
--   4. Ciclo de Vida del Usuario (New Users, M1 Return, Reorder, Recurring, Re-activation).
--   5. Volumen Comercial y Ventas fact_orders (Órdenes, Net Sales, AOV, frecuencia).
--   6. Eficiencia Operacional (Delivery Time promedio, % Late >10m, % Late >35m, Picking).
--
-- Partición: month_date | Cluster: country, warehouse_id
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Deduplicación de Partner principal por Warehouse en fact_orders
warehouse_top_partner AS (
  SELECT
    warehouse_id,
    partner_id,
    month_date,
    total_monthly_orders
  FROM (
    SELECT
      dp.warehouse_id,
      CAST(fo.restaurant.id AS STRING)            AS partner_id,
      DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
      COUNT(DISTINCT fo.order_id)                 AS total_monthly_orders,
      ROW_NUMBER() OVER (
        PARTITION BY dp.warehouse_id, DATE_TRUNC(DATE(fo.registered_date), MONTH)
        ORDER BY COUNT(DISTINCT fo.order_id) DESC
      ) AS rnk
    FROM `peya-bi-tools-pro.il_core.fact_orders` fo
    INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
      ON fo.restaurant.id = dp.partner_id
    WHERE fo.registered_date >= start_month
      AND fo.order_status = 'CONFIRMED'
      AND dp.is_darkstore = TRUE
      AND dp.warehouse_id IS NOT NULL
    GROUP BY 1, 2, 3
  )
  WHERE rnk = 1
),

-- 2. Datos maestros del local físico y coordenadas desde dim_partner
dmart_partners_master AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING)         AS partner_id,
    dp.partner_name,
    CAST(dp.address.latitude AS FLOAT64)  AS store_lat,
    CAST(dp.address.longitude AS FLOAT64) AS store_lng,
    ST_GEOGPOINT(CAST(dp.address.longitude AS FLOAT64), CAST(dp.address.latitude AS FLOAT64)) AS store_geopoint
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.address.latitude IS NOT NULL
    AND dp.address.longitude IS NOT NULL
),

-- 3. Polígonos reales de cobertura históricos (Shapes) y métricas espaciales
shapes_base AS (
  SELECT
    ps.month_date,
    CAST(ps.partner_id AS STRING) AS partner_id,
    ps.country_name,
    ps.country_code,
    ps.country_id,
    ps.city_name_lz               AS city,
    ps.city_id_lz                 AS city_id,
    ps.partner_shape,
    ST_ASGEOJSON(ps.partner_shape) AS shape_geojson,
    
    -- Morfología del terreno
    ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2)       AS coverage_area_km2,
    ROUND(ST_PERIMETER(ps.partner_shape) / 1000.0, 2)     AS perimeter_km,
    ROUND(ST_Y(ST_CENTROID(ps.partner_shape)), 6)         AS centroid_lat,
    ROUND(ST_X(ST_CENTROID(ps.partner_shape)), 6)         AS centroid_lng
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
  WHERE ps.month_date >= start_month
    AND ps.month_date <= end_month
    AND ps.partner_shape IS NOT NULL
),

-- 4. Unión de Shapes con el Warehouse y cálculo del radio máximo
warehouse_shapes AS (
  SELECT
    s.*,
    dp.warehouse_id,
    COALESCE(dp.warehouse_name, s.partner_id) AS warehouse_name,
    dp.store_lat,
    dp.store_lng,
    dp.store_geopoint,
    -- Distancia máxima en línea recta desde la tienda hasta el vértice más lejano del polígono
    ROUND(ST_MAXDISTANCE(dp.store_geopoint, s.partner_shape) / 1000.0, 2) AS max_delivery_radius_km
  FROM shapes_base s
  INNER JOIN dmart_partners_master dp
    ON s.partner_id = dp.partner_id
  INNER JOIN warehouse_top_partner wtp
    ON  dp.warehouse_id = wtp.warehouse_id
    AND s.month_date    = wtp.month_date
    AND dp.partner_id   = wtp.partner_id
),

-- 5. Demografía de Usuarios PeYa dentro de cada Shape
users_inside_shape AS (
  SELECT
    ws.month_date,
    ws.warehouse_id,
    COUNT(DISTINCT CAST(cl.customer_id AS STRING)) AS peya_users_covered
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  INNER JOIN warehouse_shapes ws
    ON  cl.month_date = ws.month_date
    AND ST_WITHIN(cl.customer_geogpoint, ws.partner_shape)
  WHERE cl.month_date >= start_month
    AND cl.customer_geogpoint IS NOT NULL
  GROUP BY 1, 2
),

-- 6. Métricas Comerciales y Transaccionales desde fact_orders
orders_per_warehouse AS (
  SELECT
    dp.warehouse_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    COUNT(DISTINCT fo.order_id)                 AS dmart_orders,
    COUNT(DISTINCT fo.customer_id)              AS dmart_maus_total,
    -- Ventas Netas estimadas en EUR y Moneda Local
    ROUND(SUM(COALESCE(fo.total_amount, 0)), 2) AS gross_sales,
    ROUND(AVG(COALESCE(fo.total_amount, 0)), 2) AS aov_amount
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.order_status = 'CONFIRMED'
    AND dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 7. Eficiencia Operativa y Demoras desde dmarts_timings
timings_per_warehouse AS (
  SELECT
    warehouse_id,
    DATE_TRUNC(created_date, MONTH) AS month_date,
    ROUND(AVG(actual_dt_min), 1)    AS avg_delivery_time_min,
    ROUND(SAFE_DIVIDE(SUM(SAFE_CAST(is_order_late_10 AS INT64)), COUNT(DISTINCT order_id)) * 100, 1) AS pct_order_late_10,
    ROUND(SAFE_DIVIDE(SUM(CASE WHEN actual_dt_min > 35 THEN 1 ELSE 0 END), COUNT(DISTINCT order_id)) * 100, 1) AS pct_order_late_35,
    ROUND(AVG(picking_time_s), 1)   AS avg_picking_time_s,
    ROUND(AVG(items), 1)            AS avg_items_per_order
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= start_month
    AND warehouse_id IS NOT NULL
  GROUP BY 1, 2
),

-- 8. Ciclo de Vida del Usuario (frank_user_type) dentro del Warehouse
lifecycle_per_warehouse AS (
  SELECT
    dp.warehouse_id,
    f.month AS month_date,
    COUNT(DISTINCT CASE WHEN f.Type_Dmart = 'New User'         THEN f.customer_id END) AS new_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Type_Dmart = 'M1 Return'        THEN f.customer_id END) AS m1_return_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Type_Dmart = 'Reorder'          THEN f.customer_id END) AS reorder_users_dmart,
    COUNT(DISTINCT CASE WHEN f.Type_Dmart = 'Recurring Return' THEN f.customer_id END) AS recurring_return_dmart,
    COUNT(DISTINCT CASE WHEN f.Type_Dmart = 'Re-Activation'    THEN f.customer_id END) AS reactivation_users_dmart
  FROM `peya-food-and-groceries.automated_tables_reports.frank_user_type` f
  INNER JOIN `peya-bi-tools-pro.il_core.fact_orders` o
    ON  f.customer_id = o.customer_id
    AND DATE_TRUNC(DATE(o.registered_date), MONTH) = f.month
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON o.restaurant.id = dp.partner_id
  WHERE f.month >= start_month
    AND dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
  GROUP BY 1, 2
)

-- ==============================================================================
-- RESULTADO FINAL CONSOLIDADO DEL SHAPE ANALYTICS
-- ==============================================================================
SELECT
  -- A. Identificación y Dimensiones
  ws.month_date,
  ws.warehouse_id,
  ws.warehouse_name,
  ws.partner_id,
  ws.country_name                               AS country,
  ws.country_code,
  ws.country_id,
  ws.city,
  ws.city_id,

  -- B. Geometría y Terreno del Polígono
  ws.coverage_area_km2,
  ws.perimeter_km,
  ws.max_delivery_radius_km,
  ws.store_lat,
  ws.store_lng,
  ws.centroid_lat,
  ws.centroid_lng,
  ws.store_geopoint,
  ws.partner_shape,
  ws.shape_geojson,

  -- C. Demografía y Universo PeYa en el Área
  COALESCE(u.peya_users_covered, 0)             AS peya_users_covered,
  ROUND(SAFE_DIVIDE(COALESCE(u.peya_users_covered, 0), NULLIF(ws.coverage_area_km2, 0)), 1) AS user_density_per_km2,

  -- D. Penetración y Adopción DMart
  COALESCE(ord.dmart_maus_total, 0)             AS dmart_maus,
  ROUND(SAFE_DIVIDE(COALESCE(ord.dmart_maus_total, 0), NULLIF(u.peya_users_covered, 0)) * 100, 1) AS penetration_pct,
  GREATEST(0, COALESCE(u.peya_users_covered, 0) - COALESCE(ord.dmart_maus_total, 0)) AS unpenetrated_opportunity_users,

  -- E. Métricas Comerciales y Transaccionales (fact_orders)
  COALESCE(ord.dmart_orders, 0)                 AS dmart_orders,
  ROUND(SAFE_DIVIDE(COALESCE(ord.dmart_orders, 0), NULLIF(ord.dmart_maus_total, 0)), 2) AS monthly_frequency,
  COALESCE(ord.gross_sales, 0)                  AS gross_sales,
  COALESCE(ord.aov_amount, 0)                   AS aov_amount,

  -- F. Ciclo de Vida de Clientes (CRM)
  COALESCE(lc.new_users_dmart, 0)               AS new_users_dmart,
  COALESCE(lc.m1_return_users_dmart, 0)         AS m1_return_users_dmart,
  COALESCE(lc.reorder_users_dmart, 0)           AS reorder_users_dmart,
  COALESCE(lc.recurring_return_dmart, 0)        AS recurring_return_dmart,
  COALESCE(lc.reactivation_users_dmart, 0)      AS reactivation_users_dmart,

  -- G. Eficiencia y Calidad Operacional (dmarts_timings)
  t.avg_delivery_time_min,
  t.pct_order_late_10,
  t.pct_order_late_35,
  t.avg_picking_time_s,
  t.avg_items_per_order

FROM warehouse_shapes ws

-- Universo de usuarios en el shape
LEFT JOIN users_inside_shape u
  ON  ws.warehouse_id = u.warehouse_id
  AND ws.month_date   = u.month_date

-- Ventas y órdenes de fact_orders
LEFT JOIN orders_per_warehouse ord
  ON  ws.warehouse_id = ord.warehouse_id
  AND ws.month_date   = ord.month_date

-- Tiempos operacionales y demoras
LEFT JOIN timings_per_warehouse t
  ON  ws.warehouse_id = t.warehouse_id
  AND ws.month_date   = t.month_date

-- Desglose de ciclo de vida
LEFT JOIN lifecycle_per_warehouse lc
  ON  ws.warehouse_id = lc.warehouse_id
  AND ws.month_date   = lc.month_date

ORDER BY
  ws.month_date DESC,
  country,
  city,
  warehouse_name;
