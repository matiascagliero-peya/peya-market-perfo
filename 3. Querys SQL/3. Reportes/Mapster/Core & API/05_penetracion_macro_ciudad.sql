-- ==============================================================================
-- PILAR 5: PENETRACIÓN MACRO A NIVEL CIUDAD Y PAÍS
-- Archivo: 05_penetracion_macro_ciudad.sql
--
-- FUNCIÓN ÚNICA:
--   Calcular los KPIs ejecutivos a escala macro (Ciudad / País):
--   - Universo de usuarios totales de la app (Platform MAUs).
--   - Clientes únicos de darkstores (Dmart MAUs).
--   - Tasa de penetración macro de la vertical de supermercados en cada ciudad.
--   - Facturación neta y pedidos agregados.
--
-- TABLAS FUENTE OFICIALES:
--   1. `peya-bi-tools-pro.il_core.dim_partner` (identificación de darkstores y ciudades)
--   2. `peya-bi-tools-pro.il_core.fact_orders` (órdenes de toda la app y darkstores)
--   3. `peya-bi-tools-pro.il_core.dim_user` (maestro demográfico de usuarios)
--
-- GRANO: 1 fila por (month_date, country, city)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Darkstores identificadas por ciudad
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.partner_id,
    dp.country.country_name AS country,
    dp.city.name            AS city
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Clientes y órdenes específicas de Darkstores en cada ciudad
dmart_city_activity AS (
  SELECT
    dp.country,
    dp.city,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    COUNT(DISTINCT fo.customer_id)              AS dmart_maus,
    COUNT(DISTINCT fo.order_id)                 AS dmart_orders,
    ROUND(SUM(COALESCE(fo.total_amount, 0)), 2) AS total_gross_sales
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
  GROUP BY 1, 2, 3
),

-- 3. Universo total de usuarios activos de la plataforma PedidosYa en la misma ciudad
platform_city_users AS (
  SELECT
    dp.country,
    dp.city,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    COUNT(DISTINCT fo.customer_id)              AS platform_maus
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN (
    -- Tomamos todos los restaurantes/partners para mapear compras en esa ciudad
    SELECT DISTINCT
      p.partner_id,
      p.country.country_name AS country,
      p.city.name            AS city
    FROM `peya-bi-tools-pro.il_core.dim_partner` p
    WHERE p.city.name IS NOT NULL
  ) dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
  GROUP BY 1, 2, 3
)

-- ==============================================================================
-- RESULTADO FINAL: PENETRACIÓN MACRO POR CIUDAD / MES
-- ==============================================================================
SELECT
  p.month_date,
  p.country,
  p.city,

  -- Universo de usuarios y adopción
  p.platform_maus,
  COALESCE(d.dmart_maus, 0)                                           AS dmart_maus,
  ROUND(SAFE_DIVIDE(COALESCE(d.dmart_maus, 0), p.platform_maus) * 100, 1) AS city_penetration_pct,

  -- Transaccional y Volumen
  COALESCE(d.dmart_orders, 0)                                         AS dmart_orders,
  ROUND(SAFE_DIVIDE(COALESCE(d.dmart_orders, 0), NULLIF(d.dmart_maus, 0)), 2) AS monthly_frequency,
  COALESCE(d.total_gross_sales, 0)                                    AS total_gross_sales,
  ROUND(SAFE_DIVIDE(COALESCE(d.total_gross_sales, 0), NULLIF(d.dmart_orders, 0)), 2) AS aov_amount

FROM platform_city_users p
LEFT JOIN dmart_city_activity d
  ON  p.country    = d.country
  AND p.city       = d.city
  AND p.month_date = d.month_date
WHERE p.city IN (SELECT DISTINCT city FROM dmart_partners)
ORDER BY
  p.month_date DESC,
  p.country,
  dmart_orders DESC;
