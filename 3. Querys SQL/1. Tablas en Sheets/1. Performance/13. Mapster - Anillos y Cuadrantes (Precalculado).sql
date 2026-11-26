-- ==============================================================================
-- 13. Mapster - Anillos y Cuadrantes (Precalculado para Sheets)
-- Ubicación: PeYa Market/3. Querys SQL/1. Tablas en Sheets/1. Performance/
--
-- FUNCIÓN ÚNICA:
--   Segmentar el territorio concéntrico alrededor de cada Darkstore en:
--   1) Radios concéntricos (< 1 KM, 1-2 KM, 2-3 KM, 3-4 KM, 4-5 KM, 5-6.5 KM, 6.5-8 KM).
--   2) 4 Cuadrantes Cardinales (Norte, Este, Sur, Oeste) mediante ST_AZIMUTH.
--
-- MÉTRICAS ENTREGADAS POR FILA (CUADRANTE Y ANILLO TOTAL):
--   - Covered MAUs: Usuarios únicos de PedidosYa que residen en esa porción.
--   - Dmart MAUs: Clientes compradores de D-Mart en esa porción.
--   - Penetración %: (Dmart MAUs / Covered MAUs) * 100.
--   - Órdenes D-Mart: Cantidad de pedidos entregados a residentes de esa porción.
--   - Frecuencia mensual: Pedidos por comprador activo.
--   - Ventas netas (GMV / Net Sales) y Ticket promedio (AOV).
--   - Rendimiento Logístico: Tiempo promedio de entrega (DT) y atrasos (>10 min).
--   - Mix de demanda: % que aporta el cuadrante a su anillo y a la tienda total.
--
-- TABLAS FUENTE CORPORATIVAS OFICIALES:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (coordenadas GPS oficiales de tiendas)
--   2. `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` (polígono de cobertura)
--   3. `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` (domicilio del usuario)
--   4. `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` (pedidos y facturación)
--   5. `peya-delivery-and-support.automated_tables_reports.dmarts_timings` (tiempos DT y picking)
--
-- GRANO DE SALIDA PARA GOOGLE SHEETS:
--   1 fila por (month_date, warehouse_id, anillo_order, cuadrante)
-- ==============================================================================

DECLARE target_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);

WITH

-- 1. Coordenadas oficiales y polígonos mensuales de cada tienda (Sin DISTINCT sobre tipos GEOGRAPHY)
store_shapes_historical AS (
  SELECT
    CAST(dp.warehouse_id AS STRING)                                                             AS warehouse_id,
    dp.warehouse_name,
    dp.country.country_name                                                                     AS country,
    ST_GEOGPOINT(CAST(dp.address.longitude AS FLOAT64), CAST(dp.address.latitude AS FLOAT64))   AS store_geopoint,
    ps.month_date,
    ps.partner_shape                                                                            AS full_shape
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  JOIN `peya-food-and-groceries.automated_tables_reports.qc_coverage_partner_shapes` ps
    ON  CAST(dp.partner_id AS STRING) = CAST(ps.partner_id AS STRING)
    AND ps.month_date = target_month
  WHERE dp.is_darkstore = TRUE
    AND dp.address.longitude IS NOT NULL
    AND dp.address.latitude IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY dp.warehouse_id, ps.month_date ORDER BY dp.partner_id DESC) = 1
),

-- 2. Ubicación GPS de usuarios: Asignación directa a Anillo y Cuadrante Cardinal (N, E, S, O)
users_locations AS (
  SELECT
    CAST(cl.customer_id AS STRING)                         AS customer_id,
    cl.month_date,
    ss.warehouse_id,
    ss.warehouse_name,
    ss.country,
    -- Anillo concéntrico por distancia en metros (Ampliados hasta 8 km para cubrir tiendas extensas como Martínez)
    CASE
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 1000 THEN 1
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 2000 THEN 2
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 3000 THEN 3
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 4000 THEN 4
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 5000 THEN 5
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 6500 THEN 6
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 8000 THEN 7
      ELSE 8
    END AS anillo_order,
    CASE
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 1000 THEN '< 1 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 2000 THEN '1-2 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 3000 THEN '2-3 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 4000 THEN '3-4 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 5000 THEN '4-5 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 6500 THEN '5-6.5 KM'
      WHEN ST_DISTANCE(cl.customer_geogpoint, ss.store_geopoint) <= 8000 THEN '6.5-8 KM'
      ELSE '> 8 KM'
    END AS anillo,
    -- Cuadrante cardinal por ángulo de rumbo (Azimuth: 0° Norte, 90° Este, 180° Sur, 270° Oeste)
    CASE
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 315
        OR MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 45   THEN 'Norte'
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 45
       AND MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 135  THEN 'Este'
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 135
       AND MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 225  THEN 'Sur'
      ELSE 'Oeste'
    END AS cuadrante,
    CASE
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 315
        OR MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 45   THEN 'N'
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 45
       AND MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 135  THEN 'E'
      WHEN MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) >= 135
       AND MOD(CAST(ROUND(ST_AZIMUTH(ss.store_geopoint, cl.customer_geogpoint) / ACOS(-1) * 180 + 360) AS INT64), 360) < 225  THEN 'S'
      ELSE 'O'
    END AS cuadrante_key
  FROM `peya-food-and-groceries.automated_tables_reports.qc_coverage_customer_location` cl
  JOIN store_shapes_historical ss
    ON  ST_WITHIN(cl.customer_geogpoint, ss.full_shape)
    AND cl.month_date = ss.month_date
  WHERE cl.month_date = target_month
    AND cl.customer_geogpoint IS NOT NULL
),

-- 3. Pedidos a nivel ORDEN (Agrupados para evitar el efecto multiplicador de SKUs)
orders_base AS (
  SELECT
    CAST(customer_id AS STRING)        AS customer_id,
    CAST(warehouse_id AS STRING)       AS warehouse_id,
    DATE_TRUNC(order_date, MONTH)      AS month_date,
    order_id,
    SUM(total_amount_sold_net_eur)     AS net_sales_amount
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
  WHERE order_date >= target_month
    AND order_date < DATE_ADD(target_month, INTERVAL 1 MONTH)
    AND state = 'CONFIRMED'
    AND warehouse_id IS NOT NULL
  GROUP BY 1, 2, 3, 4
),

-- 4. Tiempos operacionales a nivel ORDEN (1 fila por pedido)
timings_base AS (
  SELECT
    order_id,
    AVG(actual_dt_min)    AS actual_dt_min,
    MAX(is_order_late_10) AS is_order_late_10
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_timings`
  WHERE created_date >= target_month
    AND created_date < DATE_ADD(target_month, INTERVAL 1 MONTH)
  GROUP BY 1
),

-- 5. Cruce de pedidos con la ubicación geográfica del cliente
orders_enriched AS (
  SELECT
    ob.customer_id,
    ob.warehouse_id,
    ob.month_date,
    ob.order_id,
    ul.anillo_order,
    ul.anillo,
    ul.cuadrante,
    ul.cuadrante_key,
    ob.net_sales_amount,
    tb.actual_dt_min,
    tb.is_order_late_10
  FROM orders_base ob
  JOIN users_locations ul
    ON  ob.customer_id  = ul.customer_id
    AND ob.warehouse_id = ul.warehouse_id
    AND ob.month_date   = ul.month_date
  LEFT JOIN timings_base tb
    ON ob.order_id = tb.order_id
),

-- 6. Agregado de universo de usuarios por anillo y cuadrante
covered_by_quadrant AS (
  SELECT
    warehouse_id,
    warehouse_name,
    country,
    month_date,
    anillo_order,
    anillo,
    cuadrante,
    cuadrante_key,
    COUNT(DISTINCT customer_id) AS covered_maus
  FROM users_locations
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

-- 7. Agregado de compras por anillo y cuadrante
dmart_by_quadrant AS (
  SELECT
    warehouse_id,
    month_date,
    anillo_order,
    anillo,
    cuadrante,
    cuadrante_key,
    COUNT(DISTINCT customer_id)                                           AS dmart_maus,
    COUNT(DISTINCT order_id)                                              AS dmart_orders,
    SUM(net_sales_amount)                                                 AS net_sales,
    COUNT(DISTINCT CASE WHEN actual_dt_min IS NOT NULL THEN order_id END) AS total_orders_timings,
    SUM(actual_dt_min)                                                    AS sum_delivery_time_min,
    SUM(is_order_late_10)                                                 AS is_order_late_10
  FROM orders_enriched
  GROUP BY 1, 2, 3, 4, 5, 6
),

-- 8. Totales por anillo (para calcular el mix del cuadrante sobre su radio)
totals_per_ring AS (
  SELECT
    warehouse_id, month_date, anillo_order,
    COUNT(DISTINCT order_id) AS total_orders_in_ring
  FROM orders_enriched
  GROUP BY 1, 2, 3
),

-- 9. Totales por tienda física (para calcular el mix sobre el local en Sheets)
totals_per_store AS (
  SELECT
    warehouse_id, month_date,
    COUNT(DISTINCT order_id) AS total_store_orders
  FROM orders_base
  GROUP BY 1, 2
)

-- ==============================================================================
-- CONSULTA FINAL: TABLA LISTA PARA EXPORTAR DIRECTO A GOOGLE SHEETS
-- Pestaña sugerida en Sheets: "3. Rings Data"
-- ==============================================================================
SELECT
  cbq.month_date,
  cbq.warehouse_id,
  cbq.warehouse_name,
  cbq.country,
  cbq.anillo_order,
  cbq.anillo,
  cbq.cuadrante,
  cbq.cuadrante_key,

  -- Universo y Adopción en este Cuadrante
  COALESCE(cbq.covered_maus, 0)                                                  AS covered_maus,
  COALESCE(dbq.dmart_maus, 0)                                                    AS dmart_maus,
  ROUND(SAFE_DIVIDE(dbq.dmart_maus, cbq.covered_maus) * 100, 1)                  AS penetration_pct,

  -- Volumen Comercial
  COALESCE(dbq.dmart_orders, 0)                                                  AS orders,
  ROUND(SAFE_DIVIDE(dbq.dmart_orders, dbq.dmart_maus), 2)                        AS frequency,
  ROUND(COALESCE(dbq.net_sales, 0), 2)                                           AS net_sales,
  ROUND(SAFE_DIVIDE(dbq.net_sales, dbq.dmart_orders), 2)                         AS aov,

  -- Eficiencia Logística
  ROUND(SAFE_DIVIDE(dbq.sum_delivery_time_min, dbq.total_orders_timings), 1)    AS avg_dt_min,
  ROUND(SAFE_DIVIDE(dbq.is_order_late_10, dbq.total_orders_timings) * 100, 1)    AS pct_late_10,

  -- Mix Territorial
  ROUND(SAFE_DIVIDE(dbq.dmart_orders, tpr.total_orders_in_ring) * 100, 1)        AS mix_ring_orders_pct,
  ROUND(SAFE_DIVIDE(dbq.dmart_orders, tps.total_store_orders) * 100, 1)          AS mix_store_orders_pct,
  tps.total_store_orders                                                         AS total_store_orders_sheets

FROM covered_by_quadrant cbq
LEFT JOIN dmart_by_quadrant dbq
  ON  cbq.warehouse_id  = dbq.warehouse_id
  AND cbq.month_date    = dbq.month_date
  AND cbq.anillo_order  = dbq.anillo_order
  AND cbq.cuadrante_key = dbq.cuadrante_key
LEFT JOIN totals_per_ring tpr
  ON  cbq.warehouse_id  = tpr.warehouse_id
  AND cbq.month_date    = tpr.month_date
  AND cbq.anillo_order  = tpr.anillo_order
LEFT JOIN totals_per_store tps
  ON  cbq.warehouse_id  = tps.warehouse_id
  AND cbq.month_date    = tps.month_date
ORDER BY
  cbq.month_date DESC,
  cbq.warehouse_id,
  cbq.anillo_order ASC,
  CASE cbq.cuadrante_key
    WHEN 'N' THEN 1
    WHEN 'E' THEN 2
    WHEN 'S' THEN 3
    WHEN 'O' THEN 4
    ELSE 5
  END;
