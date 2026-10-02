-- ==============================================================================
-- PARTE 2: DATOS DE ÓRDENES Y CONSUMO (Volumen, Facturación, Ticket y Canasta)
-- Nombre: warehouse_orders_performance
--
-- Objetivo: Medir exclusivamente la dinámica transaccional y comercial de cada WHS:
--   - Volumen total de órdenes confirmadas (fact_orders).
--   - Facturación Neta (Net Sales) y Ticket Promedio (AFV / AOV).
--   - Tamaño de Canasta en unidades físicas (Basket Size).
--   - Frecuencia mensual de compra por cliente (Orders / Users).
--   - Volumen y penetración de categorías frescas (Ultra Fresh Orders & Share %).
--
-- Grano: 1 fila por (month_date, warehouse_id)
-- ==============================================================================

DECLARE start_month DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH);
DECLARE end_month   DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), MONTH);

WITH

-- 1. Darkstores desde dim_partner
dmart_partners AS (
  SELECT DISTINCT
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(dp.partner_id AS STRING) AS partner_id
  FROM `peya-bi-tools-pro.il_core.dim_partner` dp
  WHERE dp.is_darkstore = TRUE
    AND dp.warehouse_id IS NOT NULL
),

-- 2. Universo de Órdenes Confirmadas desde fact_orders
orders_fact AS (
  SELECT
    fo.order_id,
    dp.warehouse_id,
    dp.warehouse_name,
    CAST(fo.customer_id AS STRING)              AS customer_id,
    DATE_TRUNC(DATE(fo.registered_date), MONTH) AS month_date,
    fo.total_amount                             AS gross_amount
  FROM `peya-bi-tools-pro.il_core.fact_orders` fo
  INNER JOIN dmart_partners dp
    ON fo.restaurant.id = dp.partner_id
  WHERE fo.registered_date >= start_month
    AND fo.registered_date <= end_month
    AND fo.order_status = 'CONFIRMED'
),

-- 3. Detalle de Unidades, Facturación Neta y Ultra Fresh por Orden (customer_orders_sku_level)
orders_sku AS (
  SELECT
    co.order_id,
    SUM(co.fulfilled_quantity)                  AS units_sold,
    SUM(co.total_amount_net_with_discount_eur)  AS net_sales_eur,
    MAX(CASE WHEN co.master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN 1 ELSE 0 END) AS has_ultra_fresh
  FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` co
  WHERE co.order_date >= start_month
    AND co.order_date <= end_month
    AND co.state = 'CONFIRMED'
  GROUP BY co.order_id
)

-- ==============================================================================
-- SELECT FINAL: PARTE 2 - ÓRDENES Y VENTAS
-- ==============================================================================
SELECT
  -- Claves
  o.month_date,
  o.warehouse_id,
  o.warehouse_name,

  -- Volumen Transaccional
  COUNT(DISTINCT o.order_id)                                        AS total_orders,
  COUNT(DISTINCT o.customer_id)                                     AS total_buyers,
  SUM(COALESCE(sku.units_sold, 0))                                  AS total_units_sold,

  -- Facturación y Rentabilidad
  ROUND(SUM(COALESCE(sku.net_sales_eur, o.gross_amount)), 2)        AS total_net_sales,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(sku.net_sales_eur, o.gross_amount)), COUNT(DISTINCT o.order_id)), 2) AS afv_aov_amount,

  -- Hábitos de Compra y Canasta
  ROUND(SAFE_DIVIDE(SUM(COALESCE(sku.units_sold, 0)), COUNT(DISTINCT o.order_id)), 1) AS basket_size_units,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT o.order_id), COUNT(DISTINCT o.customer_id)), 2)     AS monthly_frequency,

  -- Mix de Categorías: Ultra Fresh
  COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN o.order_id END) AS uf_orders,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN sku.has_ultra_fresh = 1 THEN o.order_id END), COUNT(DISTINCT o.order_id)) * 100, 1) AS uf_orders_share_pct

FROM orders_fact o

LEFT JOIN orders_sku sku
  ON o.order_id = sku.order_id

GROUP BY
  o.month_date,
  o.warehouse_id,
  o.warehouse_name
ORDER BY
  o.month_date DESC,
  total_orders DESC;
