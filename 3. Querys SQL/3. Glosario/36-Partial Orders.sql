DECLARE query_name STRING DEFAULT '36-Partial Orders';

-- Query de prueba para calcular la métrica Partial Orders (Dos métodos habituales en la plataforma)
-- Método A: Consulta directa de datos agregados operativos (Tabla dmarts_ops_daily_new).
-- Método B: Cálculo transaccional a nivel de SKU (cantidad pedida vs cantidad entregada).
-- Métrica: Partial Orders = Órdenes confirmadas donde al menos un ítem fue entregado parcialmente o cancelado por falta de stock (entregado < pedido).
-- Frecuencia de actualización: la tabla dmarts_ops_daily_new y customer_orders_sku_level se actualizan de forma diaria.

-- ====================================================================================
-- MÉTODO A: Consulta Operativa de Datos Agregados (Recomendado para reportes rápidos)
-- ====================================================================================
WITH ops_daily AS (
  SELECT
    IF(dc.country_name_en = 'Dominican Republic', 'Republica Dominicana', dc.country_name_en) AS country,
    DATE_TRUNC(DATE(ops.date), MONTH) AS month,
    
    -- Total de órdenes de operaciones
    SUM(ops.orders) AS total_orders_ops,
    
    -- Cantidad de órdenes parciales
    SUM(ops.partial_orders) AS partial_orders

  FROM
    `peya-delivery-and-support.automated_tables_reports.dmarts_ops_daily_new` ops
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON LOWER(ops.country_name) = LOWER(dc.country_name)
  WHERE
    DATE(ops.date) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) AND CURRENT_DATE()
  GROUP BY 1, 2
),

-- ====================================================================================
-- MÉTODO B: Análisis Transaccional a nivel de SKU (Para auditorías o cruces de categorías)
-- ====================================================================================
sku_level_partial AS (
  SELECT
    dc.country_name AS country,
    DATE_TRUNC(o.order_date, MONTH) AS month,
    
    -- Cantidad de órdenes totales confirmadas
    COUNT(DISTINCT o.order_id) AS total_orders_fact,
    
    -- Cantidad de órdenes donde al menos un SKU tuvo cantidad entregada (fulfilled) menor a la pedida (quantity)
    COUNT(DISTINCT CASE WHEN o.quantity > o.fulfilled_quantity THEN o.order_id END) AS partial_orders_calculated

  FROM
    `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` o
  LEFT JOIN `peya-bi-tools-pro.il_core.dim_country` dc
    ON o.country_id = dc.country_id
  WHERE
    UPPER(o.state) = 'CONFIRMED'
    AND o.order_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH) AND CURRENT_DATE()
  GROUP BY 1, 2
)

SELECT
  COALESCE(od.country, sl.country) AS country,
  COALESCE(od.month, sl.month) AS month,
  
  -- Datos operativos de Método A
  COALESCE(od.total_orders_ops, 0) AS total_orders_ops,
  COALESCE(od.partial_orders, 0) AS partial_orders_ops,
  ROUND(SAFE_DIVIDE(COALESCE(od.partial_orders, 0), COALESCE(od.total_orders_ops, 0)) * 100, 2) AS partial_orders_ops_pct,
  
  -- Datos transaccionales de Método B
  COALESCE(sl.total_orders_fact, 0) AS total_orders_fact,
  COALESCE(sl.partial_orders_calculated, 0) AS partial_orders_transaccional,
  ROUND(SAFE_DIVIDE(COALESCE(sl.partial_orders_calculated, 0), COALESCE(sl.total_orders_fact, 0)) * 100, 2) AS partial_orders_transaccional_pct

FROM
  ops_daily od
FULL OUTER JOIN
  sku_level_partial sl ON od.country = sl.country AND od.month = sl.month
ORDER BY
  1 ASC, 2 DESC;
