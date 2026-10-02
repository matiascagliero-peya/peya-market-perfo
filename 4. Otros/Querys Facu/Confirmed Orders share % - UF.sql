DECLARE query_name STRING DEFAULT 'Confirmed Orders share % - UF.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Confirmed Orders Share % - Ultra Fresh a nivel SEMANAL
--            por PAÍS y total consolidado LATAM.
--
-- DERIVADO DE: '3. Glosario\154-UF Share (percent orders).sql' y '1. OKRs_daily_data.sql'
-- DEFINICIÓN:
--   • Categorías Ultra Fresh: 'Produce', 'Meat / Seafood', 'Ready To Consume'.
--   • Métrica: Órdenes con al menos 1 SKU de Ultra Fresh / Total Órdenes Confirmadas.
-- CAMPOS EXPORTADOS:
--   • fecha: Fecha de inicio de la semana (Lunes).
--   • dia_fin_semana: Fecha de cierre de la semana (Domingo).
--   • pais: Nombre del país (o 'LATAM' para el consolidado regional).
--   • confirmed_orders: Total de órdenes confirmadas en la semana.
--   • uf_confirmed_orders: Órdenes confirmadas que contienen al menos un ítem Ultra Fresh.
--   • uf_orders_share_pct: Participación (%) de órdenes con Ultra Fresh sobre el total.
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Base semanal a nivel orden con flag si contiene algún SKU de Ultra Fresh
orders_base AS (
  SELECT
    DATE_TRUNC(o.order_date, WEEK(MONDAY))                         AS fecha,
    DATE_ADD(DATE_TRUNC(o.order_date, WEEK(MONDAY)), INTERVAL 6 DAY) AS dia_fin_semana,
    CASE 
      WHEN dc.country_name IN ('República Dominicana', 'Republic Dominican', 'Dominican Republic') THEN 'Republica Dominicana'
      ELSE dc.country_name 
    END AS pais,
    o.order_id,
    -- Flag si al menos un ítem de la orden pertenece a Ultra Fresh
    MAX(IF(o.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume'), 1, 0)) AS has_uf_item
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
  GROUP BY 1, 2, 3, 4
),

-- 2. Agregación semanal por País
uf_by_country AS (
  SELECT
    fecha,
    dia_fin_semana,
    pais,
    COUNT(DISTINCT order_id)                                        AS confirmed_orders,
    COUNT(DISTINCT CASE WHEN has_uf_item = 1 THEN order_id END)     AS uf_confirmed_orders
  FROM orders_base
  GROUP BY 1, 2, 3
),

-- 3. Consolidado regional para toda la entidad 'LATAM'
uf_latam AS (
  SELECT
    fecha,
    dia_fin_semana,
    'LATAM' AS pais,
    SUM(confirmed_orders)    AS confirmed_orders,
    SUM(uf_confirmed_orders) AS uf_confirmed_orders
  FROM uf_by_country
  GROUP BY 1, 2
),

-- 4. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM uf_by_country
  UNION ALL
  SELECT * FROM uf_latam
)

-- Consulta final con métricas de órdenes y penetración de Ultra Fresh
SELECT
  fecha,
  dia_fin_semana,
  pais,

  confirmed_orders,
  uf_confirmed_orders,

  -- Share % de órdenes con Ultra Fresh
  ROUND(
    SAFE_DIVIDE(uf_confirmed_orders, confirmed_orders) * 100, 
    2
  ) AS uf_orders_share_pct

FROM combined
ORDER BY 
  fecha DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
