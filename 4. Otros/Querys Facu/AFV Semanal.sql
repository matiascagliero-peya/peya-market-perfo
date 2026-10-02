DECLARE query_name STRING DEFAULT 'AFV Semanal.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de AFV (Average Fulfillment Value / Ticket Promedio Neto) a nivel SEMANAL
--            por PAÍS y total consolidado LATAM.
--
-- DERIVADO DE: '3. Glosario\35-AFV.sql' y '1. OKRs_daily_data.sql'
-- FÓRMULA: AFV = Net Sales (EUR) / Confirmed Orders
-- CAMPOS EXPORTADOS:
--   • fecha: Fecha de inicio de la semana (Lunes).
--   • dia_fin_semana: Fecha de cierre de la semana (Domingo).
--   • pais: Nombre del país (o 'LATAM' para el consolidado regional).
--   • net_sales_eur: Ventas netas totales sin IVA (descontando descuentos) en EUR.
--   • confirmed_orders: Cantidad total de órdenes únicas confirmadas.
--   • afv_eur: Ticket promedio neto en Euros por orden.
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Base semanal de órdenes confirmadas de D-Mart a nivel SKU
orders_base AS (
  SELECT
    DATE_TRUNC(o.order_date, WEEK(MONDAY))                         AS fecha,
    DATE_ADD(DATE_TRUNC(o.order_date, WEEK(MONDAY)), INTERVAL 6 DAY) AS dia_fin_semana,
    CASE 
      WHEN dc.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE dc.country_name 
    END AS pais,
    o.order_id,
    o.total_amount_net_with_discount_eur
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc 
    ON o.country_id = dc.country_id
  WHERE UPPER(o.state) = 'CONFIRMED'
    AND o.order_date BETWEEN inicio AND fin
    AND o.store_name NOT IN (
      "RD_12_Torre OV", "PA_9_Midtown", "SV_6_Torre Futura",
      "EC_17_TiendaPick-Up Oficina", "PE_3_PuntaHermosa", "BO_19_Truck",
      "UY_15_Eventos", "PE_24_FILO", "EC_6_Oficina"
    )
),

-- 2. Agregación semanal por País
afv_by_country AS (
  SELECT
    fecha,
    dia_fin_semana,
    pais,
    ROUND(SUM(total_amount_net_with_discount_eur), 2) AS net_sales_eur,
    COUNT(DISTINCT order_id)                          AS confirmed_orders
  FROM orders_base
  GROUP BY 1, 2, 3
),

-- 3. Consolidado regional para toda la entidad 'LATAM'
afv_latam AS (
  SELECT
    fecha,
    dia_fin_semana,
    'LATAM' AS pais,
    ROUND(SUM(net_sales_eur), 2) AS net_sales_eur,
    SUM(confirmed_orders)        AS confirmed_orders
  FROM afv_by_country
  GROUP BY 1, 2
),

-- 4. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM afv_by_country
  UNION ALL
  SELECT * FROM afv_latam
)

-- Consulta final con cálculo de AFV
SELECT
  fecha,
  dia_fin_semana,
  pais,

  net_sales_eur,
  confirmed_orders,

  -- AFV: Ticket promedio neto en Euros
  ROUND(
    SAFE_DIVIDE(net_sales_eur, confirmed_orders), 
    2
  ) AS afv_eur

FROM combined
ORDER BY 
  fecha DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
