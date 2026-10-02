DECLARE query_name STRING DEFAULT '12. Mapster - Base - Performance (WHS data)';
-- ==============================================================================
-- QUERY MAESTRA DE ALMACENES: dim_warehouse_all_partners_master
--
-- Objetivo: Ver TODOS los partners habilitados dentro de cada Warehouse (WHS),
--           identificando cuál es el partner principal (mayor volumen de órdenes),
--           los partners secundarios, cuántos están activos en el mes, la lista
--           completa de IDs/Nombres y el ARRAY estructurado con su detalle.
--
-- Grano por defecto: 1 fila por (month_date, warehouse_id) con ARRAY de partners
-- (Al final se incluye la opción comentada para ver 1 fila por partner individual)
--
-- Tablas origen:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (datos físicos y lista de partners WHS)
--   2. `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` (polígonos históricos y geografía)
--   3. `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` (órdenes y actividad)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Meses a evaluar dentro del rango seleccionado
months_range AS (
  SELECT DISTINCT month_date
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes`
  WHERE month_date >= start_month
    AND month_date <= end_month
),

-- 2. Órdenes mensuales por Partner y Warehouse
partner_monthly_orders AS (
  SELECT
    warehouse_id,
    CAST(vendor_id AS STRING)     AS partner_id,
    DATE_TRUNC(order_date, MONTH) AS month_date,
    COUNT(DISTINCT order_id)      AS monthly_orders
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= start_month
    AND state = 'CONFIRMED'
    AND warehouse_id IS NOT NULL
  GROUP BY 1, 2, 3
),

-- 3. Todos los partners físicos asociados a cada Warehouse en dim_partner
warehouse_partners_raw AS (
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

-- 4. Cruce de partners por mes con sus órdenes y ranking dentro del WHS
warehouse_partners_ranked AS (
  SELECT
    mr.month_date,
    wp.warehouse_id,
    wp.warehouse_name,
    wp.partner_id,
    wp.partner_name,
    wp.store_lat,
    wp.store_lng,
    COALESCE(pmo.monthly_orders, 0) AS monthly_orders,
    CASE WHEN COALESCE(pmo.monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_partner_active,
    ROW_NUMBER() OVER (
      PARTITION BY wp.warehouse_id, mr.month_date
      ORDER BY COALESCE(pmo.monthly_orders, 0) DESC, wp.partner_id ASC
    ) AS partner_rank
  FROM warehouse_partners_raw wp
  CROSS JOIN months_range mr
  LEFT JOIN partner_monthly_orders pmo
    ON  wp.warehouse_id = pmo.warehouse_id
    AND wp.partner_id   = pmo.partner_id
    AND mr.month_date   = pmo.month_date
),

-- 5. Agrupación consolidada a nivel Warehouse con todos sus partners
warehouse_partners_aggregated AS (
  SELECT
    month_date,
    warehouse_id,
    ANY_VALUE(warehouse_name) AS warehouse_name,
    ANY_VALUE(store_lat)      AS store_lat,
    ANY_VALUE(store_lng)      AS store_lng,

    -- Partner Principal (Rank 1: con mayor actividad de órdenes en el mes)
    MAX(CASE WHEN partner_rank = 1 THEN partner_id END)   AS main_partner_id,
    MAX(CASE WHEN partner_rank = 1 THEN partner_name END) AS main_partner_name,

    -- Métricas de partners habilitados en el local
    COUNT(DISTINCT partner_id)                                      AS total_enabled_partners,
    COUNT(DISTINCT CASE WHEN is_partner_active THEN partner_id END) AS active_partners_in_month,
    SUM(monthly_orders)                                             AS total_whs_monthly_orders,

    -- Lista concatenada de todos los IDs habilitados
    STRING_AGG(DISTINCT partner_id, ', ') AS all_partner_ids,

    -- Lista descriptiva legible con nombres y estado
    STRING_AGG(
      DISTINCT CONCAT(partner_name, ' [ID: ', partner_id, CASE WHEN partner_rank = 1 THEN ' - Principal' ELSE '' END, ']'),
      ' | ' ORDER BY CONCAT(partner_name, ' [ID: ', partner_id, CASE WHEN partner_rank = 1 THEN ' - Principal' ELSE '' END, ']')
    ) AS all_partners_display,

    -- Array estructurado detallado de cada partner habilitado
    ARRAY_AGG(
      STRUCT(
        partner_id,
        partner_name,
        (partner_rank = 1) AS is_main,
        is_partner_active,
        monthly_orders
      )
      ORDER BY monthly_orders DESC, partner_id ASC
    ) AS partners_detail

  FROM warehouse_partners_ranked
  GROUP BY month_date, warehouse_id
),

-- 6. Polígonos reales de cobertura históricos por partner y mes
partner_shapes_history AS (
  SELECT
    ps.month_date,
    CAST(ps.partner_id AS STRING) AS partner_id,
    ps.country_name,
    ps.country_code,
    ps.country_id,
    ps.city_name_lz,
    ps.city_id_lz,
    ps.partner_shape
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
  WHERE ps.month_date >= start_month
    AND ps.month_date <= end_month
    AND ps.partner_shape IS NOT NULL
)

-- ==============================================================================
-- RESULTADO FINAL: 1 FILA POR WHS CON TODOS SUS PARTNERS HABILITADOS
-- ==============================================================================
SELECT
  -- 1. Identificación del Almacén y Red de Partners
  w.month_date,
  w.warehouse_id,
  w.warehouse_name,
  w.total_enabled_partners,
  w.active_partners_in_month,
  w.main_partner_id,
  w.main_partner_name,
  w.all_partner_ids,
  w.all_partners_display,
  w.partners_detail,
  CASE WHEN COALESCE(w.total_whs_monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_active,

  -- 2. Ubicación Física y Geografía (obtenidas desde qc_coverage_partner_shapes)
  COALESCE(ps.country_name, 'Desconocido') AS country,
  ps.country_code,
  ps.country_id,
  ps.city_name_lz                          AS city,
  ps.city_id_lz                            AS city_id,
  ps.city_name_lz                          AS neighborhood,
  w.store_lat,
  w.store_lng,
  ST_GEOGPOINT(w.store_lng, w.store_lat)   AS store_geopoint,

  -- 3. Polígono de Cobertura y Métricas de Terreno (del Partner Principal del WHS)
  ps.partner_shape,
  ST_ASGEOJSON(ps.partner_shape)             AS shape_geojson,
  ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2) AS coverage_area_km2,
  ROUND(ST_Y(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lat,
  ROUND(ST_X(ST_CENTROID(ps.partner_shape)), 6)   AS centroid_lng

FROM warehouse_partners_aggregated w

-- Se vincula el polígono de cobertura histórica del partner principal del WHS
LEFT JOIN partner_shapes_history ps
  ON  w.main_partner_id = ps.partner_id
  AND w.month_date      = ps.month_date

ORDER BY
  w.month_date DESC,
  country,
  city,
  warehouse_name;

-- ==============================================================================
-- VARIANTE DESGLOSADA (1 FILA POR CADA PARTNER HABILITADO):
-- Si en algún análisis necesitás ver cada partner habilitado en una fila individual,
-- ejecutá esta variante reemplazando el SELECT final por:
--
-- SELECT
--   w.month_date,
--   w.warehouse_id,
--   w.warehouse_name,
--   p.partner_id,
--   p.partner_name,
--   p.is_main AS is_main_partner,
--   p.is_partner_active,
--   p.monthly_orders,
--   ps.country_name AS country,
--   ps.city_name_lz AS city,
--   ps.city_name_lz AS neighborhood,
--   w.store_lat,
--   w.store_lng,
--   ps.partner_shape,
--   ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2) AS coverage_area_km2
-- FROM warehouse_partners_aggregated w,
-- UNNEST(w.partners_detail) p
-- LEFT JOIN partner_shapes_history ps
--   ON p.partner_id = ps.partner_id AND w.month_date = ps.month_date
-- ORDER BY w.month_date DESC, w.warehouse_id, p.is_main DESC;
-- ==============================================================================
