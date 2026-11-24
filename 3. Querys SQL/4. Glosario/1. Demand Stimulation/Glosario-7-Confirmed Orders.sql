DECLARE query_name STRING DEFAULT 'Glosario-7-Confirmed Orders';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 7
-- Nombre:     Confirmed Orders
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo (Col 7)
-- Fórmula:    COUNT(DISTINCT order_id) WHERE order_status = 'CONFIRMED'
-- Definición: Total absoluto de órdenes confirmadas y entregadas exitosamente.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.order_id) AS confirmed_orders
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +------------------+----------------------+-------+
-- | confirmed_orders | country              | month |
-- +------------------+----------------------+-------+
-- |        2.652.678 | Argentina            | 2.026 |
-- |          142.934 | Bolivia              | 2.026 |
-- |          342.270 | Chile                | 2.026 |
-- |           97.415 | Ecuador              | 2.026 |
-- |           86.285 | El Salvador          | 2.026 |
-- |           95.705 | Guatemala            | 2.026 |
-- |           50.718 | Honduras             | 2.026 |
-- |           56.437 | Nicaragua            | 2.026 |
-- |           92.999 | Panam�               | 2.026 |
-- |          135.799 | Paraguay             | 2.026 |
-- |          273.380 | Per�                 | 2.026 |
-- |          171.348 | Rep�blica Dominicana | 2.026 |
-- |          287.095 | Uruguay              | 2.026 |
-- +------------------+----------------------+-------+
