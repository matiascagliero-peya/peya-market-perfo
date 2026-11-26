-- ==============================================================================
-- PILAR 3: CENSO GEOESPACIAL POR CUADRANTES / RECUADROS URBANOS
-- Archivo: 03_censo_cuadrantes_manzanas.sql
--
-- FUNCIÓN ÚNICA:
--   Dividir el área urbana en una cuadrícula de celdas geográficas (ej: 8x8 = 64 celdas)
--   y censar mediante funciones espaciales (ST_CONTAINS) exactamente cuántos usuarios
--   de la app residen dentro de cada celda y cuántos compran en darkstores.
--
-- TABLAS FUENTE OFICIALES:
--   1. `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` (geopuntos de usuarios)
--   2. `peya-bi-tools-pro.il_core.fact_orders` (órdenes y clientes darkstores)
--   3. `peya-bi-tools-pro.il_core.dim_partner` (identificación de darkstores)
--
-- GRANO: 1 fila por (month_date, cell_id)
-- ==============================================================================

DECLARE target_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);

WITH

-- 1. Definición de celdas/recuadros (parámetros de ejemplo para microcentro)
grid_cells AS (
  SELECT 0 AS cell_id, -34.6150 AS min_lat, -34.6050 AS max_lat, -58.3900 AS min_lng, -58.3750 AS max_lng UNION ALL
  SELECT 1 AS cell_id, -34.6050 AS min_lat, -34.5950 AS max_lat, -58.3900 AS min_lng, -58.3750 AS max_lng UNION ALL
  SELECT 2 AS cell_id, -34.5950 AS min_lat, -34.5850 AS max_lat, -58.3900 AS min_lng, -58.3750 AS max_lng UNION ALL
  SELECT 3 AS cell_id, -34.5850 AS min_lat, -34.5750 AS max_lat, -58.3900 AS min_lng, -58.3750 AS max_lng
),

grid_geometries AS (
  SELECT
    cell_id,
    min_lat,
    max_lat,
    min_lng,
    max_lng,
    ROUND((min_lat + max_lat) / 2.0, 6) AS centroid_lat,
    ROUND((min_lng + max_lng) / 2.0, 6) AS centroid_lng,
    ST_GEOGFROMTEXT(
      CONCAT('POLYGON((',
        min_lng, ' ', min_lat, ', ',
        max_lng, ' ', min_lat, ', ',
        max_lng, ' ', max_lat, ', ',
        min_lng, ' ', max_lat, ', ',
        min_lng, ' ', min_lat, '))')
    ) AS cell_geom
  FROM grid_cells
),

-- 2. Universo total de usuarios de la app en la ciudad en el mes objetivo
users_in_month AS (
  SELECT
    CAST(customer_id AS STRING) AS customer_id,
    customer_geogpoint
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location`
  WHERE month_date = target_month
    AND customer_geogpoint IS NOT NULL
),

-- 3. Clientes que compraron en darkstores en el mes objetivo
dmart_buyers AS (
  SELECT DISTINCT
    CAST(fo.customer_id AS STRING) AS customer_id,
    COUNT(DISTINCT fo.order_id)    AS dmart_orders
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN `peya-bi-tools-pro.il_core.dim_partner` dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= target_month
    AND fo.registered_date < DATE_ADD(target_month, INTERVAL 1 MONTH)
    AND fo.order_status = 'CONFIRMED'
    AND dp.is_darkstore = TRUE
  GROUP BY 1
),

-- 4. Cruce espacial: Asignar cada usuario a su cuadrante correspondiente
users_with_cell AS (
  SELECT
    g.cell_id,
    u.customer_id,
    CASE WHEN b.customer_id IS NOT NULL THEN 1 ELSE 0 END AS is_dmart_buyer,
    COALESCE(b.dmart_orders, 0)                            AS dmart_orders
  FROM grid_geometries g
  INNER JOIN users_in_month u
    ON ST_CONTAINS(g.cell_geom, u.customer_geogpoint)
  LEFT JOIN dmart_buyers b
    ON u.customer_id = b.customer_id
)

-- ==============================================================================
-- RESULTADO FINAL: DENSIDAD Y PENETRACIÓN POR CUADRANTE
-- ==============================================================================
SELECT
  target_month                                                              AS month_date,
  g.cell_id,
  g.min_lat,
  g.max_lat,
  g.min_lng,
  g.max_lng,
  g.centroid_lat,
  g.centroid_lng,

  -- Volumen de usuarios en el cuadrante
  COUNT(DISTINCT c.customer_id)                                             AS platform_users,
  COUNT(DISTINCT CASE WHEN c.is_dmart_buyer = 1 THEN c.customer_id END)     AS dmart_users,
  SUM(c.dmart_orders)                                                       AS dmart_orders,

  -- Penetración % en la celda
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN c.is_dmart_buyer = 1 THEN c.customer_id END),
    COUNT(DISTINCT c.customer_id)
  ) * 100, 1)                                                               AS penetration_pct

FROM grid_geometries g
LEFT JOIN users_with_cell c
  ON g.cell_id = c.cell_id
GROUP BY
  1, 2, 3, 4, 5, 6, 7, 8
ORDER BY
  g.cell_id ASC;
