DECLARE query_name STRING DEFAULT 'Glosario-46-Basket Size';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 46
-- Nombre:     Basket Size
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Ratio Calculado
-- Fórmula:    Units Sold / Confirmed Orders
-- Definición: Unidades promedio por pedido confirmado.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  SUM(d.fulfilled_quantity) AS units_sold,
  COUNT(DISTINCT d.order_id) AS confirmed_orders,
  SAFE_DIVIDE(SUM(d.fulfilled_quantity), NULLIF(COUNT(DISTINCT d.order_id), 0)) AS basket_size
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-------------+------------------+----------------------+-------+---------------+
-- | basket_size | confirmed_orders | country              | month | units_sold    |
-- +-------------+------------------+----------------------+-------+---------------+
-- |        8,50 |        2.652.678 | Argentina            | 2.026 | 22.537.552,57 |
-- |        7,23 |          142.934 | Bolivia              | 2.026 |  1.032.909,38 |
-- |        8,25 |          342.270 | Chile                | 2.026 |  2.824.960,59 |
-- |        6,14 |           97.415 | Ecuador              | 2.026 |    598.603,74 |
-- |        6,30 |           86.285 | El Salvador          | 2.026 |       543.397 |
-- |        6,20 |           95.705 | Guatemala            | 2.026 |       593.219 |
-- |        4,63 |           50.718 | Honduras             | 2.026 |       234.762 |
-- |        6,13 |           56.437 | Nicaragua            | 2.026 |    346.016,56 |
-- |        7,34 |           92.999 | Panam�               | 2.026 |    682.329,75 |
-- |        6,11 |          135.799 | Paraguay             | 2.026 |    829.499,15 |
-- |        5,50 |          273.380 | Per�                 | 2.026 |  1.503.957,68 |
-- |        5,88 |          171.348 | Rep�blica Dominicana | 2.026 |  1.007.107,98 |
-- |        7,96 |          287.095 | Uruguay              | 2.026 |  2.285.044,38 |
-- +-------------+------------------+----------------------+-------+---------------+
