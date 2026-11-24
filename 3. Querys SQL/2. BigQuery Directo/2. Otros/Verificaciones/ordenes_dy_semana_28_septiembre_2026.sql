-- ====================================================================================
-- PROPÓSITO: Consultar órdenes Double Ya (DY) y pedidos totales por país para la
--            semana del 28 de Septiembre al 4 de Octubre de 2026 (2026-09-28 al 2026-10-04).
--            Basado en la lógica de negocio y filtros oficiales de:
--            `PeYa Market/3. Querys SQL/2. Querys/2. Diario/1. OKRs_daily_data.sql`
--
-- CONTENIDO:
--   1) Consulta Principal (Raw Data): Desde `fact_orders` + `fact_orders_double_ya` + `dim_partner_darkstore`.
--      - Resumen Semanal Consolidado por País (Totales de la semana + % penetración DY).
--      - Desglose Diario por País (Evolución lunes a domingo).
--   2) Consulta Alternativa (Datamart rápido): Desde `dmart_okrs_daily` (bajo costo/escaneo).
--
-- UBICACIÓN: PeYa Market\3. Querys SQL\2. Querys\Z. Otras Querys\ordenes_dy_semana_28_septiembre_2026.sql
-- ====================================================================================

-- ------------------------------------------------------------------------------------
-- PARÁMETROS: Semana del 28/09/2026 al 04/10/2026 (Lunes a Domingo)
-- ------------------------------------------------------------------------------------
DECLARE from_date DATE DEFAULT '2026-09-28'; -- Lunes de la semana
DECLARE to_date   DATE DEFAULT '2026-10-04'; -- Domingo de la semana

WITH

-- 1. Darkstores operativos (Filtro estándar OKRs Daily para excluir tiendas no operativas/eventos)
partners AS (
  SELECT
    p.country_id,
    p.partner_id,
    pd.warehouse_id,
    TRUE AS darkstore
  FROM `peya-bi-tools-pro.il_core.dim_partner` p
  INNER JOIN `peya-datamarts-pro.dm_dmarts.dim_partner_darkstore` AS pd
    ON p.partner_id = pd.partner_id
  WHERE p.partner_name NOT IN (
    "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
    "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
    "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
  )
),

-- 2. Universo de órdenes Double Ya (Órden secundaria generada en D-Marts / Groceries)
dy_orders AS (
  SELECT DISTINCT
    SAFE_CAST(dy.order_details.id.secondary AS INT64) AS order_id
  FROM `peya-bi-tools-pro.il_qcommerce.fact_orders_double_ya` dy
  WHERE dy.order_type = 'DOUBLE_YA'
),

-- 3. Base de pedidos de la semana con cruce de países activos y flag Double Ya
orders AS (
  SELECT
    o.order_id,
    DATE(o.registered_date)                  AS order_date,
    o.country_id,
    o.restaurant.id                          AS restaurant_id,
    o.order_status,
    IF(dy.order_id IS NOT NULL, TRUE, FALSE) AS is_double_ya
  FROM `peya-bi-tools-pro.il_core.fact_orders` AS o
  INNER JOIN `peya-data-origins-pro.cl_core.country_details` co
    ON o.country_id = co.country_id AND co.active
  LEFT JOIN dy_orders dy
    ON o.order_id = dy.order_id
  WHERE DATE(o.registered_date) BETWEEN from_date AND to_date
),

-- 4. Métricas agregadas por Día y País
daily_country_metrics AS (
  SELECT
    o.order_date                                                                      AS day,
    c.country_name,
    c.country_code,

    -- D-Marts (Darkstores)
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND p.darkstore = TRUE 
                        THEN o.order_id END)                                          AS dmart_confirmed_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND p.darkstore = TRUE AND o.is_double_ya 
                        THEN o.order_id END)                                          AS dmart_double_ya_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND p.darkstore = TRUE AND NOT o.is_double_ya 
                        THEN o.order_id END)                                          AS dmart_direct_orders,
    
    -- Plataforma Total (para dimensionar share relativo)
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' 
                        THEN o.order_id END)                                          AS platform_confirmed_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CONFIRMED' AND o.is_double_ya 
                        THEN o.order_id END)                                          AS platform_double_ya_orders

  FROM orders o
  INNER JOIN `peya-bi-tools-pro.il_core.dim_country` AS c
    ON c.country_id = o.country_id AND c.active = TRUE
  LEFT JOIN partners p
    ON p.partner_id = o.restaurant_id
  GROUP BY 1, 2, 3
)

-- ====================================================================================
-- SALIDA 1: CONSOLIDADO TOTAL DE LA SEMANA POR PAÍS (Semana 28/09/2026 al 04/10/2026)
-- ====================================================================================
SELECT
  country_name,
  country_code,
  from_date                                                                     AS week_start_date,
  to_date                                                                       AS week_end_date,

  -- Órdenes D-Marts
  SUM(dmart_confirmed_orders)                                                   AS dmart_confirmed_orders,
  SUM(dmart_double_ya_orders)                                                   AS dmart_double_ya_orders,
  SUM(dmart_direct_orders)                                                      AS dmart_direct_orders,

  -- Penetración / Share de Double Ya en D-Marts (%)
  ROUND(SAFE_DIVIDE(SUM(dmart_double_ya_orders), SUM(dmart_confirmed_orders)) * 100, 2) AS dmart_dy_share_pct,

  -- Órdenes Plataforma
  SUM(platform_confirmed_orders)                                                AS platform_confirmed_orders,
  SUM(platform_double_ya_orders)                                                AS platform_double_ya_orders,

  -- Participación de D-Marts en el total de DY de la plataforma (%)
  ROUND(SAFE_DIVIDE(SUM(dmart_double_ya_orders), SUM(platform_double_ya_orders)) * 100, 2) AS dmart_pct_of_all_dy

FROM daily_country_metrics
GROUP BY country_name, country_code
ORDER BY dmart_double_ya_orders DESC;


-- ====================================================================================
-- SALIDA 2 (OPCIONAL): DESGLOSE DÍA POR DÍA POR PAÍS
-- Para ver la evolución diaria dentro de la semana, descomentar esta consulta:
-- ====================================================================================
/*
SELECT
  day,
  country_name,
  dmart_confirmed_orders,
  dmart_double_ya_orders,
  dmart_direct_orders,
  ROUND(SAFE_DIVIDE(dmart_double_ya_orders, dmart_confirmed_orders) * 100, 2) AS dmart_dy_share_pct,
  platform_confirmed_orders,
  platform_double_ya_orders
FROM daily_country_metrics
ORDER BY day ASC, dmart_double_ya_orders DESC;
*/


-- ====================================================================================
-- SALIDA 3 (OPCIONAL ULTRA-RÁPIDA): CONSULTA DIRECTA SOBRE DATAMART OKRS DAILY
-- Si la tabla ya fue procesada/cargada, esta consulta ejecuta en segundos con costo mínimo:
-- ====================================================================================
/*
SELECT
  country_name,
  '2026-09-28' AS week_start_date,
  '2026-10-04' AS week_end_date,
  SUM(confirmed_orders_count)        AS dmart_confirmed_orders,
  SUM(double_ya_orders_count)        AS dmart_double_ya_orders,
  SUM(confirmed_orders_count - double_ya_orders_count) AS dmart_direct_orders,
  ROUND(SAFE_DIVIDE(SUM(double_ya_orders_count), SUM(confirmed_orders_count)) * 100, 2) AS dmart_dy_share_pct,
  SUM(total_platform_confirmed_orders_count) AS platform_confirmed_orders
FROM `peya-food-and-groceries.automated_tables_reports.dmart_okrs_daily`
WHERE day BETWEEN '2026-09-28' AND '2026-10-04'
GROUP BY country_name
ORDER BY dmart_double_ya_orders DESC;
*/
