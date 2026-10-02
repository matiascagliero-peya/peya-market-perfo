DECLARE query_name STRING DEFAULT 'Partial Orders Semanal.sql';

-- ====================================================================================
-- PROPÓSITO: Cálculo de Partial Orders (Órdenes Parciales) a nivel SEMANAL
--            por PAÍS y total consolidado LATAM.
--
-- ALINEADO CON: '2. Ops_daily_data.sql' y '1. OPS Data - Base - OPS (Diario by WHS).sql'
-- FUENTE OFICIAL DE OPERACIONES: `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new`
-- DEFINICIÓN:
--   • Partial Order: Pedido confirmado donde al menos un ítem fue entregado parcialmente o cancelado por stock.
--   • Total Orders Ops: Total de órdenes operativas registradas en D-Marts.
--   • Partial Orders %: Ratio de defectos por órdenes parciales (Partial Orders / Total Orders * 100).
-- ====================================================================================

-- Rango de fechas: por defecto últimas 8 semanas completas hasta ayer (Lunes a Domingo)
DECLARE inicio DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK), WEEK(MONDAY));
DECLARE fin    DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
-- 1. Agregación semanal de órdenes parciales desde la fuente oficial de Operaciones
ops_weekly_by_country AS (
  SELECT
    DATE_TRUNC(DATE(ops.date), WEEK(MONDAY))                         AS fecha,
    DATE_ADD(DATE_TRUNC(DATE(ops.date), WEEK(MONDAY)), INTERVAL 6 DAY) AS dia_fin_semana,
    IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS pais,
    SUM(ops.orders)                                                 AS total_orders_ops,
    SUM(ops.partial_orders)                                         AS partial_orders
  FROM `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new` ops
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON LOWER(ops.country_name) = LOWER(dc.country_code)
  WHERE DATE(ops.date) BETWEEN inicio AND fin
  GROUP BY 1, 2, 3
),

-- 2. Consolidado regional para toda la entidad 'LATAM'
ops_weekly_latam AS (
  SELECT
    fecha,
    dia_fin_semana,
    'LATAM' AS pais,
    SUM(total_orders_ops) AS total_orders_ops,
    SUM(partial_orders)   AS partial_orders
  FROM ops_weekly_by_country
  GROUP BY 1, 2
),

-- 3. Unión de países individuales + consolidado LATAM
combined AS (
  SELECT * FROM ops_weekly_by_country
  UNION ALL
  SELECT * FROM ops_weekly_latam
)

-- Consulta final con métricas y share porcentual de defectos (idéntico a Daily Report)
SELECT
  fecha,
  dia_fin_semana,
  pais,

  total_orders_ops,
  partial_orders,

  -- Porcentaje oficial de órdenes parciales
  ROUND(
    SAFE_DIVIDE(partial_orders, total_orders_ops) * 100, 
    2
  ) AS partial_orders_pct

FROM combined
ORDER BY 
  fecha DESC, 
  (CASE WHEN pais = 'LATAM' THEN 0 ELSE 1 END), 
  pais ASC;
