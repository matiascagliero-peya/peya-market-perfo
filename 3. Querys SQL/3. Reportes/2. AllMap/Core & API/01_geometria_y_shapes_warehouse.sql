-- ==============================================================================
-- PILAR 1: GEOMETRÍA Y SHAPES DE ALMACENES (Darkstores / WHS)
-- Archivo: 01_geometria_y_shapes_warehouse.sql
--
-- FUNCIÓN ÚNICA:
--   Determinar la ubicación física exacta de cada tienda, sus coordenadas,
--   su polígono oficial de reparto (Shape) mes a mes, su superficie en km²
--   y su centroide geográfico.
--
-- TABLAS FUENTE OFICIALES:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (datos físicos y coordenadas)
--   2. `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` (polígonos mensuales)
--   3. `peya-bi-tools-pro.il_core.fact_orders` (actividad / órdenes confirmadas)
--
-- GRANO: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Deduplicación del partner principal por warehouse según órdenes confirmadas
warehouse_partner_orders AS (
  SELECT
    dp.warehouse_id,
    CAST(fo.restaurant.id AS STRING)            AS partner_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    COUNT(DISTINCT fo.order_id)                 AS total_monthly_orders
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
    AND dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
  GROUP BY 1, 2, 3
),

warehouse_top_partner AS (
  SELECT
    warehouse_id,
    partner_id,
    month_date,
    total_monthly_orders
  FROM (
    SELECT
      warehouse_id,
      partner_id,
      month_date,
      total_monthly_orders,
      ROW_NUMBER() OVER (
        PARTITION BY warehouse_id, month_date
        ORDER BY total_monthly_orders DESC
      ) AS rnk
    FROM warehouse_partner_orders
  )
  WHERE rnk = 1
),

-- 2. Datos físicos del local desde dim_partner
dmart_partners_master AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING)          AS partner_id,
    dp.partner_name,
    CAST(dp.address.latitude AS FLOAT64)   AS store_lat,
    CAST(dp.address.longitude AS FLOAT64)  AS store_lng
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.address.latitude IS NOT NULL
    AND dp.address.longitude IS NOT NULL
),

-- 3. Polígonos de reparto históricos mensuales (Shapes)
partner_shapes_history AS (
  SELECT
    ps.month_date,
    CAST(ps.partner_id AS STRING) AS partner_id,
    ps.partner_name,
    ps.country_id,
    ps.country_name,
    ps.country_code,
    ps.city_id_lz,
    ps.city_name_lz,
    ps.partner_shape
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
  WHERE ps.month_date >= start_month
    AND ps.month_date <= end_month
    AND ps.partner_shape IS NOT NULL
)

-- ==============================================================================
-- RESULTADO FINAL: CATÁLOGO ESPACIAL MAESTRO DE DARKSTORES
-- ==============================================================================
SELECT
  -- Identificación
  ps.month_date,
  dp.warehouse_id,
  COALESCE(dp.warehouse_name, ps.partner_name) AS warehouse_name,
  dp.partner_id,
  dp.partner_name,
  CASE WHEN COALESCE(wtp.total_monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_active,

  -- Ubicación Geográfica
  ps.country_name                              AS country,
  ps.country_code,
  ps.country_id,
  ps.city_name_lz                              AS city,
  ps.city_id_lz                                AS city_id,
  ps.city_name_lz                              AS neighborhood,
  dp.store_lat,
  dp.store_lng,
  ST_GEOGPOINT(dp.store_lng, dp.store_lat)     AS store_geopoint,

  -- Geometría del Polígono (Shape)
  ps.partner_shape,
  ST_ASGEOJSON(ps.partner_shape)               AS shape_geojson,
  ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2) AS coverage_area_km2,
  ROUND(ST_Y(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lat,
  ROUND(ST_X(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lng

FROM partner_shapes_history ps

INNER JOIN dmart_partners_master dp
  ON ps.partner_id = dp.partner_id

LEFT JOIN warehouse_top_partner wtp
  ON  dp.warehouse_id = wtp.warehouse_id
  AND ps.month_date   = wtp.month_date
  AND dp.partner_id   = wtp.partner_id

ORDER BY
  ps.month_date DESC,
  country,
  city,
  warehouse_name;
