DECLARE query_name STRING DEFAULT 'Glosario-1-Active warehouses';

-- GLOSARIO DE MÉTRICAS OKRs — PEYA MARKET
-- ====================================================================================
-- Métrica Nº: 1
-- Nombre:     Active warehouses
-- Chapter:   Demand Stimulation
-- Query bajada en: 0 - Orders
-- Sheets Name: 1. TD - OKRs Mensual (0 - Orders)
-- Sheets Link: https://docs.google.com/spreadsheets/d/13yTO_kFzIvISmbSz6p93BFUub1HODpuiGhB3yElZ2fw
-- Tablas de origen: `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level`
-- Tipo:       Dato Directo (Col 2)
-- Fórmula:    COUNT(DISTINCT warehouse_id) activas
-- Definición: Cantidad de tiendas/warehouses activas de PeYa Market que registraron operación en el mes.
-- ====================================================================================

SELECT
  d.country_name AS country,
  DATE_TRUNC(d.order_date, MONTH) AS month,
  COUNT(DISTINCT d.warehouse_id) AS active_warehouses
FROM `peya-datamarts-pro.dm_dmarts.customer_orders_sku_level` d
WHERE UPPER(d.state) = 'CONFIRMED'
  AND d.order_date BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY 1, 2
ORDER BY 1 ASC;

-- ====================================================================================
-- RESULTADO REAL VERIFICADO EN BIGQUERY (Septiembre 2026):
-- ====================================================================================
-- +-------------------+----------------------+-------+
-- | active_warehouses | country              | month |
-- +-------------------+----------------------+-------+
-- |                71 | Argentina            | 2.026 |
-- |                 5 | Bolivia              | 2.026 |
-- |                28 | Chile                | 2.026 |
-- |                 7 | Ecuador              | 2.026 |
-- |                 3 | El Salvador          | 2.026 |
-- |                 5 | Guatemala            | 2.026 |
-- |                 2 | Honduras             | 2.026 |
-- |                 1 | Nicaragua            | 2.026 |
-- |                 6 | Panam�               | 2.026 |
-- |                 4 | Paraguay             | 2.026 |
-- |                11 | Per�                 | 2.026 |
-- |                 6 | Rep�blica Dominicana | 2.026 |
-- |                 8 | Uruguay              | 2.026 |
-- +-------------------+----------------------+-------+
