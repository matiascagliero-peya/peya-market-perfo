-- ==============================================================================
-- EJEMPLO PARA 1 SOLO ALMACÉN (WHS): dim_warehouse_all_partners_master
--
-- Objetivo: Ver la salida exacta fila por partner para un único almacén
--           (ideal para probar en BigQuery Console en menos de 1 segundo).
--
-- Grano: 1 fila por partner por mes para el WHS seleccionado.
-- ==============================================================================

WITH params AS (
  SELECT
    DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) AS start_month,
    DATE_TRUNC(CURRENT_DATE(), MONTH)                              AS end_month,
    '506'                                                          AS target_whs -- Cambiá '506' por el ID o nombre del local que quieras probar
),

-- 1. Rango mensual generado dinámicamente para los últimos 4 meses
months_range AS (
  SELECT month_date
  FROM params,
  UNNEST(GENERATE_DATE_ARRAY(params.start_month, params.end_month, INTERVAL 1 MONTH)) AS month_date
),

-- 2. Almacén físico y sus partners filtrados por el WHS elegido
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
    CAST(dp.address.longitude AS FLOAT64)  AS store_lng
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp, params
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
    AND dp.address.latitude IS NOT NULL
    AND dp.address.longitude IS NOT NULL
    AND (
      CAST(dp.warehouse_id AS STRING) = params.target_whs
      OR CAST(dp.warehouse_id AS STRING) LIKE CONCAT('%', params.target_whs, '%')
      OR LOWER(dp.warehouse_name) LIKE CONCAT('%', LOWER(params.target_whs), '%')
    )
),

-- 3. Órdenes del mes únicamente para los partners de este WHS
partner_monthly_orders AS (
  SELECT
    warehouse_id,
    CAST(vendor_id AS STRING)     AS partner_id,
    DATE_TRUNC(order_date, MONTH) AS month_date,
    COUNT(DISTINCT order_id)      AS monthly_orders
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`, params
  WHERE order_date >= params.start_month
    AND order_date < DATE_ADD(params.end_month, INTERVAL 1 MONTH)
    AND state = 'CONFIRMED'
    AND CAST(warehouse_id AS STRING) IN (SELECT warehouse_id FROM warehouse_partners_raw)
  GROUP BY 1, 2, 3
),

-- 4. Polígonos reales de Hurrier de los partners de este WHS (sin simplificar)
partner_shapes_hurrier AS (
  SELECT
    CAST(vda.vendor_code AS STRING)                         AS partner_id,
    ANY_VALUE(vda.vertical_type)                            AS hurrier_vertical_type,
    ST_UNION_AGG(s.shape)                                   AS partner_shape,
    ST_ASGEOJSON(ST_UNION_AGG(s.shape))                     AS shape_geojson,
    ROUND(ST_AREA(ST_UNION_AGG(s.shape)) / 1000000.0, 2)   AS coverage_area_km2,
    ROUND(ST_Y(ST_CENTROID(ST_UNION_AGG(s.shape))), 6)     AS centroid_lat,
    ROUND(ST_X(ST_CENTROID(ST_UNION_AGG(s.shape))), 6)     AS centroid_lng
  FROM `peya-data-origins-pro.cl_hurrier.vendors_delivery_areas` vda
  LEFT JOIN UNNEST(vda.delivery_areas) da
  LEFT JOIN UNNEST(da.history) h
  LEFT JOIN `peya-data-origins-pro.cl_hurrier.vendor_delivery_area_shapes` s
    ON da.id = s.id AND CAST(da.shape_hash AS STRING) = CAST(s.shape_hash AS STRING)
  WHERE da.is_deleted = FALSE
    AND h.active_to IS NULL
    AND COALESCE(h.is_active, TRUE) = TRUE
    AND s.shape IS NOT NULL
    AND CAST(vda.vendor_code AS STRING) IN (
      SELECT partner_id FROM warehouse_partners_raw
    )
  GROUP BY 1
),

-- 5. Ranking de partners y cálculo de órdenes del local
warehouse_partners_ranked AS (
  SELECT
    mr.month_date,
    wp.warehouse_id,
    wp.warehouse_name,
    wp.partner_id,
    wp.partner_name,
    wp.business_type,
    ps.hurrier_vertical_type,
    wp.country,
    wp.country_code,
    wp.country_id,
    wp.city,
    wp.city_id,
    wp.neighborhood,
    wp.store_lat,
    wp.store_lng,
    COALESCE(pmo.monthly_orders, 0) AS partner_monthly_orders,
    CASE WHEN COALESCE(pmo.monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_partner_active,
    ROW_NUMBER() OVER (
      PARTITION BY wp.warehouse_id, mr.month_date
      ORDER BY COALESCE(pmo.monthly_orders, 0) DESC, wp.partner_id ASC
    ) AS partner_rank,
    SUM(COALESCE(pmo.monthly_orders, 0)) OVER (
      PARTITION BY wp.warehouse_id, mr.month_date
    ) AS total_whs_monthly_orders,

    -- Shape individual del partner desde Hurrier
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
  LEFT JOIN partner_shapes_hurrier ps
    ON wp.partner_id = ps.partner_id
),

-- 6. Fechas operativas reales (apertura y última orden) del local
whs_fechas_operativas AS (
  SELECT
    CAST(par.warehouse_id AS STRING) AS warehouse_id,
    MIN(DATE(fo.registered_date))    AS fecha_apertura,
    MAX(DATE(fo.registered_date))    AS fecha_ultima_orden
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par 
    ON fo.restaurant.id = par.partner_id
  WHERE fo.order_status = 'CONFIRMED'
    AND fo.registered_date >= '2020-01-01'
    AND CAST(par.warehouse_id AS STRING) IN (SELECT warehouse_id FROM warehouse_partners_raw)
  GROUP BY 1
),

-- 7. Histórico de estado online de este almacén
partner_online_status AS (
  SELECT
    CAST(par.warehouse_id AS STRING) AS warehouse_id,
    ARRAY_AGG(hp.is_online ORDER BY SAFE_CAST(hp.yyyymmdd AS DATE) DESC LIMIT 1)[OFFSET(0)] AS is_online_actual,
    MAX(CASE WHEN hp.is_online IS TRUE THEN SAFE_CAST(hp.yyyymmdd AS DATE) END)             AS fecha_ultimo_dia_online
  FROM `peya-bi-tools-pro.il_core.dim_historical_partners` hp
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` par
    ON hp.restaurant_id = par.partner_id
  WHERE hp.yyyymmdd >= '2023-01-01'
    AND CAST(par.warehouse_id AS STRING) IN (SELECT warehouse_id FROM warehouse_partners_raw)
  GROUP BY 1
)

-- ==============================================================================
-- RESULTADO FINAL: 1 FILA POR PARTNER PARA ESTE ALMACÉN
-- ==============================================================================
SELECT
  -- 1. Dimensión Temporal y Geográfica
  r.month_date,
  COALESCE(r.country, 'Desconocido')       AS country,
  r.country_code,
  r.city,
  r.neighborhood,

  -- 2. Almacén Físico
  r.warehouse_id,
  r.warehouse_name,
  r.store_lat,
  r.store_lng,

  -- 3. Ciclo de Vida
  fo.fecha_apertura,
  CASE 
    WHEN fo.fecha_ultima_orden >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) THEN NULL
    ELSE LEAST(
      fo.fecha_ultima_orden,
      COALESCE(pos.fecha_ultimo_dia_online, fo.fecha_ultima_orden)
    )
  END AS fecha_cierre,

  -- 4. Partner Específico
  r.partner_id,
  r.partner_name,
  r.business_type,
  r.hurrier_vertical_type,
  (r.partner_rank = 1)                     AS is_main_partner,
  r.partner_rank,
  r.is_partner_active,

  -- 5. Órdenes
  r.partner_monthly_orders,
  r.total_whs_monthly_orders,
  CASE WHEN COALESCE(r.total_whs_monthly_orders, 0) > 0 THEN TRUE ELSE FALSE END AS is_store_active,

  -- 6. Polígono de Cobertura de este Partner
  r.shape_geojson,
  r.coverage_area_km2,
  r.centroid_lat,
  r.centroid_lng

FROM warehouse_partners_ranked r
LEFT JOIN whs_fechas_operativas fo
  ON r.warehouse_id = fo.warehouse_id
LEFT JOIN partner_online_status pos
  ON r.warehouse_id = pos.warehouse_id

ORDER BY
  r.month_date DESC,
  r.partner_rank ASC;
