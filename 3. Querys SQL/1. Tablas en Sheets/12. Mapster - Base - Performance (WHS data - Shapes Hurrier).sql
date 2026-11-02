DECLARE query_name STRING DEFAULT '12. Mapster - Base - Performance (WHS data - Shapes Hurrier)';

-- ==============================================================================
-- TABLA EN SHEETS 1: 1. WHS data — CATÁLOGO DE LOCALES, PARTNERS Y SHAPES (OPTIMIZADA)
--
-- Objetivo:
--   Obtener el catálogo maestro de almacenes y partners con granularidad
--   a nivel de 1 FILA POR PARTNER de manera ultra liviana (~5 GB vs 350 GB originales).
--   Cada fila contiene los datos del almacén, el partner específico,
--   sus órdenes del mes, el polígono real oficial de ESE partner,
--   y el flag `same_shape_as_main` que detecta si comparte silueta con el principal.
--
-- Grano: 1 fila por (month_date, warehouse_id, partner_id).
-- Ventana temporal: Últimos 4 meses rodantes.
-- Optimización: Usa `qc_coverage_partner_shapes` y `dim_partner` acotado, evitando
-- scans masivos de 290 GB de tablas históricas no particionadas.
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Rango mensual generado dinámicamente para los últimos 4 meses
months_range AS (
  SELECT month_date
  FROM UNNEST(GENERATE_DATE_ARRAY(start_month, end_month, INTERVAL 1 MONTH)) AS month_date
),

-- 2. Almacenes físicos y todos sus partners asociados en dim_partner
warehouse_partners_raw AS (
  SELECT DISTINCT
    CAST(dp.warehouse_id AS STRING)        AS warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING)          AS partner_id,
    dp.partner_name,
    dp.business_type.business_type_name    AS business_type,
    dp.country.country_name                AS country,
    LOWER(dp.country.country_code)         AS country_code,
    dp.country.country_id                  AS country_id,
    dp.city.name                           AS city,
    dp.city.id                             AS city_id,
    dp.city.name                           AS neighborhood,
    CAST(dp.address.latitude AS FLOAT64)   AS store_lat,
    CAST(dp.address.longitude AS FLOAT64)  AS store_lng,
    dp.first_date_online                   AS fecha_apertura,
    dp.is_active                           AS is_store_active
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.address.latitude IS NOT NULL
    AND dp.address.longitude IS NOT NULL
),

-- 3. Órdenes mensuales por Partner y Warehouse (fact_orders acotado a 4 meses)
partner_monthly_orders AS (
  SELECT
    wp.warehouse_id,
    CAST(fo.restaurant.id AS STRING)            AS partner_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    COUNT(DISTINCT fo.order_id)                 AS monthly_orders
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN (SELECT DISTINCT partner_id, warehouse_id FROM warehouse_partners_raw) wp
    ON CAST(fo.restaurant.id AS STRING) = wp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date < DATE_ADD(end_month, INTERVAL 1 MONTH)
    AND fo.order_status = 'CONFIRMED'
  GROUP BY 1, 2, 3
),

-- 4. Polígonos oficiales por Partner y Mes (qc_coverage_partner_shapes)
partner_shapes AS (
  SELECT
    ps.month_date,
    CAST(ps.partner_id AS STRING)                       AS partner_id,
    ps.business_type_name                               AS hurrier_vertical_type,
    ps.partner_shape,
    ST_ASGEOJSON(ps.partner_shape)                      AS shape_geojson,
    ROUND(ST_AREA(ps.partner_shape) / 1000000.0, 2)     AS coverage_area_km2,
    ROUND(ST_Y(ST_CENTROID(ps.partner_shape)), 6)       AS centroid_lat,
    ROUND(ST_X(ST_CENTROID(ps.partner_shape)), 6)       AS centroid_lng
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
  WHERE ps.month_date >= start_month
    AND ps.month_date <= end_month
    AND ps.partner_shape IS NOT NULL
    AND ps.partner_id IN (SELECT DISTINCT CAST(partner_id AS INT64) FROM warehouse_partners_raw)
),

-- 5. Ranking de partners y consolidación
warehouse_partners_ranked AS (
  SELECT
    mr.month_date,
    wp.warehouse_id,
    wp.warehouse_name,
    wp.partner_id,
    wp.partner_name,
    wp.business_type,
    COALESCE(ps.hurrier_vertical_type, wp.business_type) AS hurrier_vertical_type,
    wp.country,
    wp.country_code,
    wp.country_id,
    wp.city,
    wp.city_id,
    wp.neighborhood,
    wp.store_lat,
    wp.store_lng,
    wp.fecha_apertura,
    COALESCE(pmo.monthly_orders, 0) AS partner_monthly_orders,
    CASE WHEN COALESCE(pmo.monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_partner_active,
    ROW_NUMBER() OVER (
      PARTITION BY wp.warehouse_id, mr.month_date
      ORDER BY COALESCE(pmo.monthly_orders, 0) DESC, wp.partner_id ASC
    ) AS partner_rank,
    SUM(COALESCE(pmo.monthly_orders, 0)) OVER (
      PARTITION BY wp.warehouse_id, mr.month_date
    ) AS total_whs_monthly_orders,
    wp.is_store_active,

    -- Shape individual
    ps.shape_geojson,
    ps.coverage_area_km2,
    ps.centroid_lat,
    ps.centroid_lng
  FROM warehouse_partners_raw wp
  CROSS JOIN months_range mr
  LEFT JOIN partner_monthly_orders pmo
    ON  wp.warehouse_id = pmo.warehouse_id
    AND wp.partner_id   = pmo.partner_id
    AND mr.month_date   = pmo.month_date
  LEFT JOIN partner_shapes ps
    ON  wp.partner_id = ps.partner_id
    AND mr.month_date = ps.month_date
)

-- ==============================================================================
-- RESULTADO FINAL: TABLA 1 (WHS DATA) — 1 FILA POR PARTNER (ULTRA LIVIANA)
-- ==============================================================================
SELECT
  -- 1. Dimensión Temporal y Geográfica
  r.month_date,
  COALESCE(r.country, 'Desconocido')       AS country,
  r.country_code,
  r.country_id,
  r.city,
  r.city_id,
  r.neighborhood,

  -- 2. Almacén Físico (Warehouse / Darkstore)
  r.warehouse_id,
  r.warehouse_name,
  r.store_lat,
  r.store_lng,

  -- 3. Ciclo de Vida del Almacén
  r.fecha_apertura,
  CAST(NULL AS DATE)                       AS fecha_cierre,

  -- 4. Partner Específico y su Rol en el Local
  r.partner_id,
  r.partner_name,
  r.business_type,
  r.hurrier_vertical_type,
  (r.partner_rank = 1)                     AS is_main_partner,
  r.partner_rank,
  r.is_partner_active,

  -- 5. Métricas de Órdenes
  r.partner_monthly_orders,
  r.total_whs_monthly_orders,
  r.is_store_active,

  -- 6. Polígono de Cobertura de ESTE Partner (GeoJSON, Área y Centroide)
  r.shape_geojson,
  r.coverage_area_km2,
  r.centroid_lat,
  r.centroid_lng,

  -- 7. Flag: Detección si este partner tiene el mismo shape que el partner principal
  CASE 
    WHEN r.partner_rank = 1 THEN FALSE
    WHEN r.shape_geojson IS NOT NULL 
     AND r.shape_geojson = FIRST_VALUE(r.shape_geojson) OVER (
       PARTITION BY r.warehouse_id, r.month_date 
       ORDER BY r.partner_rank ASC
     ) THEN TRUE
    ELSE FALSE
  END AS same_shape_as_main

FROM warehouse_partners_ranked r
ORDER BY
  r.month_date DESC,
  country,
  city,
  warehouse_name,
  r.partner_rank ASC;
