-- ==============================================================================
-- QUERY MAESTRA DE ALMACENES: dim_warehouse_footprint_master
-- 
-- Objetivo: Generar la tabla dimensional maestra de almacenes (Darkstores / WHS)
--           con información física, ubicación espacial, polígonos de cobertura,
--           superficie en km² y centroides para los últimos 3 meses.
--
-- Tablas origen:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (datos físicos y coordenadas WHS)
--   2. `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` (polígonos históricos y geografía)
--   3. `peya-bi-tools-pro.il_core.fact_orders` (actividad / órdenes confirmadas de darkstores)
-- ==============================================================================

-- Rango dinámico para los últimos 3 meses cerrados (o podés definir fechas fijas)
DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Deduplicación de Partner principal por Almacén y Mes usando fact_orders
-- Un warehouse puede tener más de un partner_id histórico. Se toma el partner con más órdenes en el mes.
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

-- 2. Datos maestros del local físico desde dim_partner
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

-- 3. Polígonos reales de cobertura históricos por partner y mes
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
-- RESULTADO FINAL: DIMENSIÓN MAESTRA DE WHS
-- ==============================================================================
SELECT
  -- 1. Identificación del Almacén
  ps.month_date,
  dp.warehouse_id,
  COALESCE(dp.warehouse_name, ps.partner_name) AS warehouse_name,
  dp.partner_id,
  dp.partner_name,
  CASE WHEN COALESCE(wtp.total_monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_active,

  -- 2. Ubicación Física y Geografía
  ps.country_name                              AS country,
  ps.country_code,
  ps.country_id,
  ps.city_name_lz                              AS city,
  ps.city_id_lz                                AS city_id,
  ps.city_name_lz                              AS neighborhood,
  dp.store_lat,
  dp.store_lng,
  ST_GEOGPOINT(dp.store_lng, dp.store_lat)     AS store_geopoint,

  -- 3. Polígono de Cobertura y Métricas de Terreno
  ps.partner_shape,
  ST_ASGEOJSON(ps.partner_shape)               AS shape_geojson,
  ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2) AS coverage_area_km2,
  ROUND(ST_Y(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lat,
  ROUND(ST_X(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lng

FROM partner_shapes_history ps

-- Join con la información física de dim_partner
INNER JOIN dmart_partners_master dp
  ON ps.partner_id = dp.partner_id

-- Join con la deduplicación mensual de partner principal y actividad
LEFT JOIN warehouse_top_partner wtp
  ON  dp.warehouse_id = wtp.warehouse_id
  AND ps.month_date   = wtp.month_date
  AND dp.partner_id   = wtp.partner_id

ORDER BY
  ps.month_date DESC,
  country,
  city,
  warehouse_name;
